#!/usr/bin/env bash
set -euo pipefail

IMAGE="$(printenv PG_RUNNER_PRIVILEGE_TEST_IMAGE || true)"
case "$IMAGE" in
  postgres:16|postgres:17.6) ;;
  *)
    echo "ERROR: refusing unpinned PostgreSQL image '$IMAGE'." >&2
    exit 2
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required for QA373 runner-privilege characterization." >&2
  exit 127
fi
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is unavailable; no QA373 container was created." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
RUN_ID="$(printenv GITHUB_RUN_ID || true)"
if [[ -z "$RUN_ID" ]]; then RUN_ID=local; fi
CONTAINER_NAME="qima-qa373-runner-$RUN_ID-$RANDOM-$$"
CONTAINER_STARTED=false

cleanup() {
  local original_status=$?
  local cleanup_status=0
  set +e
  if [[ "$CONTAINER_STARTED" == true ]]; then
    if [[ "$original_status" -ne 0 ]]; then
      docker inspect --format 'status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' "$CONTAINER_NAME" >&2 2>/dev/null || true
      docker logs --tail 120 "$CONTAINER_NAME" >&2 2>/dev/null || true
    fi
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || cleanup_status=1
  fi
  rm -rf "$TEMP_DIR" || cleanup_status=1
  if [[ "$original_status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    echo "ERROR: QA373 could not remove its disposable PostgreSQL container or temporary files." >&2
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup EXIT

docker run --detach \
  --name "$CONTAINER_NAME" \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=qa373-admin-only \
  --env POSTGRES_DB=postgres \
  --volume "$ROOT:/workspace:ro" \
  "$IMAGE" >/dev/null
CONTAINER_STARTED=true

ready=false
for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    ready=true
    break
  fi
  if [[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" != true ]]; then
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo "ERROR: QA373 disposable PostgreSQL container did not become ready." >&2
  exit 1
fi

SERVER_VERSION_NUM="$(docker exec "$CONTAINER_NAME" psql -U postgres -d postgres -X -v ON_ERROR_STOP=1 -q -A -t -c 'SHOW server_version_num')"
case "$IMAGE" in
  postgres:16)
    if [[ "$SERVER_VERSION_NUM" -lt 160000 || "$SERVER_VERSION_NUM" -ge 170000 ]]; then
      echo "ERROR: QA373 postgres:16 reported unexpected server_version_num '$SERVER_VERSION_NUM'." >&2
      exit 1
    fi
    ;;
  postgres:17.6)
    if [[ "$SERVER_VERSION_NUM" -ne 170006 ]]; then
      echo "ERROR: QA373 postgres:17.6 reported server_version_num '$SERVER_VERSION_NUM'; expected 170006." >&2
      exit 1
    fi
    ;;
esac

admin_psql() {
  docker exec -i "$CONTAINER_NAME" psql -U postgres -d postgres -X -v ON_ERROR_STOP=1 -q -A -t "$@"
}
db_psql() {
  docker exec "$CONTAINER_NAME" psql -U postgres -d qima_test -X -v ON_ERROR_STOP=1 -q -A -t "$@"
}

admin_psql <<'SQL'
CREATE ROLE qa373_runner LOGIN PASSWORD 'qa373-runner-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa373_runner;
CREATE ROLE qa373_not_owner LOGIN PASSWORD 'qa373-not-owner-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE ROLE qa373_no_role_admin LOGIN PASSWORD 'qa373-no-role-admin-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE ROLE qa373_no_createrole LOGIN PASSWORD 'qa373-no-createrole-only'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT CONNECT ON DATABASE qima_test TO qa373_not_owner, qa373_no_role_admin, qa373_no_createrole;
SQL

RUNNER_URL="postgresql://qa373_runner:qa373-runner-only@localhost:5432/qima_test"
set +e
docker exec --env "DATABASE_URL=$RUNNER_URL" --workdir /workspace "$CONTAINER_NAME" \
  bash /workspace/tests/sql/run-create-offer-integration.sh \
  >"$TEMP_DIR/non-superuser-runner.log" 2>&1
runner_status=$?
set -e
if [[ "$runner_status" -ne 0 ]]; then
  echo "ERROR: QA373 database-owner/CREATEROLE runner failed with exit $runner_status." >&2
  tail -n 120 "$TEMP_DIR/non-superuser-runner.log" >&2
  exit 1
fi
if ! grep -Fq "Observed one granted and one waiting same-tenant advisory lock" "$TEMP_DIR/non-superuser-runner.log"; then
  echo "ERROR: QA373 full runner did not complete its cross-session concurrency observation." >&2
  tail -n 120 "$TEMP_DIR/non-superuser-runner.log" >&2
  exit 1
fi

role_state="$(db_psql -c "SELECT rolsuper::text || '|' || rolcreaterole::text || '|' || rolcreatedb::text || '|' || rolreplication::text || '|' || rolbypassrls::text FROM pg_roles WHERE rolname = 'qa373_runner';")"
if [[ "$role_state" != "false|true|false|false|false" ]]; then
  echo "ERROR: QA373 runner role attributes were not least-privilege as expected: '$role_state'." >&2
  exit 1
fi

membership_state="$(db_psql -c "SELECT pg_has_role('qa373_runner', 'authenticated', 'SET')::text || '|' || pg_has_role('qa373_runner', 'anon', 'SET')::text || '|' || pg_has_role('authenticated', 'qa373_runner', 'MEMBER')::text || '|' || pg_has_role('anon', 'qa373_runner', 'MEMBER')::text;")"
if [[ "$membership_state" != "true|true|false|false" ]]; then
  echo "ERROR: QA373 client-role membership direction was unexpected: '$membership_state'." >&2
  exit 1
fi

pg_monitor_state="$(db_psql -c "SELECT pg_has_role('qa373_runner', 'pg_monitor', 'MEMBER')::text;")"
if [[ "$pg_monitor_state" != "false" ]]; then
  echo "ERROR: QA373 unexpectedly required pg_monitor for the full runner." >&2
  exit 1
fi

extension_state="$(db_psql -c "SELECT count(*)::text FROM pg_extension WHERE extname = 'pgcrypto';")"
wrapper_state="$(db_psql -c "SELECT (to_regprocedure('public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)') IS NOT NULL)::text;")"
if [[ "$extension_state" != "1" || "$wrapper_state" != "true" ]]; then
  echo "ERROR: QA373 did not install pgcrypto and apply the CREATE_OFFER wrapper migration as the non-superuser runner." >&2
  exit 1
fi

catalog_snapshot() {
  db_psql -c "SELECT
    (SELECT count(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace)::text || '|' ||
    (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace)::text || '|' ||
    (SELECT count(*) FROM pg_extension)::text || '|' ||
    (SELECT count(*) FROM public.offers)::text || '|' ||
    (SELECT count(*) FROM public.action_executions)::text || '|' ||
    (SELECT count(*) FROM pg_auth_members WHERE member IN (SELECT oid FROM pg_roles WHERE rolname LIKE 'qa373_%'))::text;"
}

run_expected_rejection() {
  local role_name="$1"
  local password="$2"
  local log_file="$TEMP_DIR/$role_name-rejected.log"
  local url="postgresql://$role_name:$password@localhost:5432/qima_test"
  local status
  set +e
  docker exec --env "DATABASE_URL=$url" --workdir /workspace "$CONTAINER_NAME" \
    bash /workspace/tests/sql/run-create-offer-integration.sh >"$log_file" 2>&1
  status=$?
  set -e
  if [[ "$status" -ne 4 ]]; then
    echo "ERROR: QA373 expected $role_name to be rejected with exit 4, received $status." >&2
    cat "$log_file" >&2
    exit 1
  fi
  if ! grep -Fq "must be a superuser or own qima_test with CREATEROLE" "$log_file"; then
    echo "ERROR: QA373 $role_name was rejected for an unexpected reason." >&2
    cat "$log_file" >&2
    exit 1
  fi
}

before_snapshot="$(catalog_snapshot)"
run_expected_rejection "qa373_not_owner" "qa373-not-owner-only"
after_not_owner_snapshot="$(catalog_snapshot)"
if [[ "$after_not_owner_snapshot" != "$before_snapshot" ]]; then
  echo "ERROR: QA373 non-owner rejection changed the initialized fixture catalog or data." >&2
  exit 1
fi

admin_psql -c "ALTER DATABASE qima_test OWNER TO qa373_no_role_admin;"
before_no_role_admin_snapshot="$(catalog_snapshot)"
run_expected_rejection "qa373_no_role_admin" "qa373-no-role-admin-only"
after_no_role_admin_snapshot="$(catalog_snapshot)"
if [[ "$after_no_role_admin_snapshot" != "$before_no_role_admin_snapshot" ]]; then
  echo "ERROR: QA373 role without SET/ADMIN OPTION was rejected after changing fixture catalog or data." >&2
  exit 1
fi

admin_psql -c "ALTER DATABASE qima_test OWNER TO qa373_no_createrole;"
before_no_createrole_snapshot="$(catalog_snapshot)"
run_expected_rejection "qa373_no_createrole" "qa373-no-createrole-only"
after_no_createrole_snapshot="$(catalog_snapshot)"
if [[ "$after_no_createrole_snapshot" != "$before_no_createrole_snapshot" ]]; then
  echo "ERROR: QA373 missing-CREATEROLE rejection changed the initialized fixture catalog or data." >&2
  exit 1
fi



# QA374: exercise the alternate ADMIN OPTION path independently of SET ROLE.
# Existing client roles are created before the runner and the runner receives
# ADMIN OPTION while SET is explicitly false. The read-only guard must accept
# that capability; the fixture must then grant SET access before runtime use.
admin_psql -c "DROP DATABASE qima_test WITH (FORCE);"
admin_psql -c "DROP ROLE qa373_runner, qa373_not_owner, qa373_no_role_admin, qa373_no_createrole;"
admin_psql -c "DROP ROLE authenticated, anon;"

admin_psql <<'SQL'
CREATE ROLE qa374_admin_option_runner LOGIN PASSWORD 'qa374-admin-option-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa374_admin_option_runner;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
GRANT authenticated TO qa374_admin_option_runner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
GRANT anon TO qa374_admin_option_runner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
SQL

admin_only_state="$(admin_psql -c "
  SELECT string_agg(
    target.rolname || ':' ||
    pg_has_role('qa374_admin_option_runner', target.oid, 'SET')::text || ':' ||
    membership.admin_option::text || ':' ||
    membership.set_option::text,
    '|' ORDER BY target.rolname
  )
  FROM pg_roles target
  JOIN pg_auth_members membership ON membership.roleid = target.oid
  WHERE target.rolname IN ('anon', 'authenticated')
    AND membership.member = 'qa374_admin_option_runner'::regrole;
")"
if [[ "$admin_only_state" != "anon:false:true:false|authenticated:false:true:false" ]]; then
  echo "ERROR: QA374 did not establish ADMIN OPTION without SET access: '$admin_only_state'." >&2
  exit 1
fi

ADMIN_OPTION_RUNNER_URL="postgresql://qa374_admin_option_runner:qa374-admin-option-only@localhost:5432/qima_test"
set +e
docker exec --env "DATABASE_URL=$ADMIN_OPTION_RUNNER_URL" --workdir /workspace "$CONTAINER_NAME" \
  bash /workspace/tests/sql/run-create-offer-integration.sh \
  >"$TEMP_DIR/admin-option-runner.log" 2>&1
admin_option_status=$?
set -e
if [[ "$admin_option_status" -ne 0 ]]; then
  echo "ERROR: QA374 ADMIN OPTION-only runner failed with exit $admin_option_status." >&2
  tail -n 120 "$TEMP_DIR/admin-option-runner.log" >&2
  exit 1
fi
if ! grep -Fq "Observed one granted and one waiting same-tenant advisory lock" "$TEMP_DIR/admin-option-runner.log"; then
  echo "ERROR: QA374 ADMIN OPTION-only runner did not complete the concurrency observation." >&2
  tail -n 120 "$TEMP_DIR/admin-option-runner.log" >&2
  exit 1
fi

admin_option_after_state="$(db_psql -c "
  SELECT
    pg_has_role('qa374_admin_option_runner', 'authenticated', 'SET')::text || '|' ||
    pg_has_role('qa374_admin_option_runner', 'anon', 'SET')::text || '|' ||
    pg_has_role('authenticated', 'qa374_admin_option_runner', 'MEMBER')::text || '|' ||
    pg_has_role('anon', 'qa374_admin_option_runner', 'MEMBER')::text;
")"
if [[ "$admin_option_after_state" != "true|true|false|false" ]]; then
  echo "ERROR: QA374 fixture did not establish the intended one-way SET ROLE membership: '$admin_option_after_state'." >&2
  exit 1
fi

admin_option_set_state="$(db_psql -c "
  SELECT string_agg(target.rolname || ':' || membership.set_option::text,
                   '|' ORDER BY target.rolname)
  FROM pg_roles target
  JOIN pg_auth_members membership ON membership.roleid = target.oid
  WHERE target.rolname IN ('anon', 'authenticated')
    AND membership.member = 'qa374_admin_option_runner'::regrole;
")"
if [[ "$admin_option_set_state" != "anon:true|authenticated:true" ]]; then
  echo "ERROR: QA374 fixture did not enable SET on both client-role memberships: '$admin_option_set_state'." >&2
  exit 1
fi

echo "QA374 passed: pre-existing authenticated/anon memberships with ADMIN OPTION but SET FALSE were accepted; the fixture established one-way SET ROLE access and the complete non-superuser runner plus concurrency tests succeeded."

echo "QA373 passed: a non-superuser database owner with CREATEROLE completed the full fixture, pgcrypto installation, migration, SECURITY DEFINER, SET ROLE, and concurrency runner without CREATEDB or pg_monitor; non-owner and no-CREATEROLE roles were rejected before any fixture change."
