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
    (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = 'qima_test')::text || '|' ||
    (SELECT count(*) FROM pg_roles WHERE rolname LIKE 'qa373_%' OR rolname LIKE 'qa374_%' OR rolname LIKE 'qa376_%')::text || '|' ||
    (SELECT count(*) FROM pg_auth_members WHERE member IN (SELECT oid FROM pg_roles WHERE rolname LIKE 'qa373_%' OR rolname LIKE 'qa374_%' OR rolname LIKE 'qa376_%'))::text;"
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
  SELECT string_agg(
    membership_state.role_name || ':' ||
    membership_state.has_set::text || ':' ||
    membership_state.grantor_count::text,
    '|' ORDER BY membership_state.role_name
  )
  FROM (
    SELECT
      target.rolname AS role_name,
      bool_or(membership.set_option) AS has_set,
      count(DISTINCT membership.grantor) AS grantor_count
    FROM pg_roles target
    JOIN pg_auth_members membership ON membership.roleid = target.oid
    WHERE target.rolname IN ('anon', 'authenticated')
      AND membership.member = 'qa374_admin_option_runner'::regrole
    GROUP BY target.oid, target.rolname
  ) AS membership_state;
")"
if [[ "$admin_option_set_state" != "anon:true:2|authenticated:true:2" ]]; then
  echo "ERROR: QA374 expected SET access for both client roles across two grantors, got '$admin_option_set_state'." >&2
  exit 1
fi

echo "QA374 passed: pre-existing authenticated/anon memberships with ADMIN OPTION but SET FALSE were accepted; the fixture established one-way SET ROLE access and the complete non-superuser runner plus concurrency tests succeeded."

# QA375: ADMIN OPTION does not bypass database ownership. This role can
# administer both existing client-role memberships but does not own qima_test.
admin_psql <<'SQL'
CREATE ROLE qa374_admin_option_non_owner LOGIN PASSWORD 'qa374-non-owner-admin-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
GRANT CONNECT ON DATABASE qima_test TO qa374_admin_option_non_owner;
GRANT authenticated TO qa374_admin_option_non_owner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
GRANT anon TO qa374_admin_option_non_owner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
SQL

non_owner_admin_state="$(db_psql -c "
  SELECT
    (db.datdba <> 'qa374_admin_option_non_owner'::regrole)::text || '|' ||
    string_agg(
      target.rolname || ':' ||
      pg_has_role('qa374_admin_option_non_owner', target.oid, 'SET')::text || ':' ||
      membership.admin_option::text || ':' ||
      membership.set_option::text,
      '|' ORDER BY target.rolname
    )
  FROM pg_database db
  CROSS JOIN pg_roles target
  JOIN pg_auth_members membership ON membership.roleid = target.oid
  WHERE db.datname = 'qima_test'
    AND target.rolname IN ('anon', 'authenticated')
    AND membership.member = 'qa374_admin_option_non_owner'::regrole
  GROUP BY db.datdba;
")"
if [[ "$non_owner_admin_state" != "true|anon:false:true:false|authenticated:false:true:false" ]]; then
  echo "ERROR: QA375 did not establish a non-owner with ADMIN OPTION but no SET ROLE: '$non_owner_admin_state'." >&2
  exit 1
fi

before_non_owner_snapshot="$(catalog_snapshot)"
run_expected_rejection "qa374_admin_option_non_owner" "qa374-non-owner-admin-only"
after_non_owner_snapshot="$(catalog_snapshot)"
if [[ "$after_non_owner_snapshot" != "$before_non_owner_snapshot" ]]; then
  echo "ERROR: QA375 non-owner with ADMIN OPTION changed the initialized fixture catalog or data before rejection." >&2
  exit 1
fi

echo "QA375 passed: a non-owner with CREATEROLE and ADMIN OPTION but no SET ROLE was rejected before fixture changes; catalog and data snapshots remained unchanged."

# QA376: ADMIN OPTION must cover every existing client role. Owning the
# database and having CREATEROLE plus ADMIN OPTION for only anon is not enough
# when authenticated also exists and the runner cannot SET ROLE into it.
admin_psql <<'SQL'
CREATE ROLE qa376_partial_admin_runner LOGIN PASSWORD 'qa376-partial-admin-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
ALTER DATABASE qima_test OWNER TO qa376_partial_admin_runner;
GRANT CONNECT ON DATABASE qima_test TO qa376_partial_admin_runner;
GRANT anon TO qa376_partial_admin_runner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
SQL

partial_admin_state="$(db_psql -c "
  SELECT
    (db.datdba = runner.oid)::text || '|' ||
    runner.rolcreaterole::text || '|' ||
    runner.rolsuper::text || '|' ||
    pg_has_role(runner.oid, 'anon'::regrole, 'SET')::text || '|' ||
    COALESCE(anon_members.admin_option, false)::text || '|' ||
    pg_has_role(runner.oid, 'authenticated'::regrole, 'SET')::text || '|' ||
    COALESCE(authenticated_members.admin_option, false)::text || '|' ||
    (authenticated_members.member IS NULL)::text
  FROM pg_database db
  JOIN pg_roles runner ON runner.rolname = 'qa376_partial_admin_runner'
  LEFT JOIN pg_auth_members anon_members
    ON anon_members.roleid = 'anon'::regrole
   AND anon_members.member = runner.oid
  LEFT JOIN pg_auth_members authenticated_members
    ON authenticated_members.roleid = 'authenticated'::regrole
   AND authenticated_members.member = runner.oid
  WHERE db.datname = 'qima_test';
")"
if [[ "$partial_admin_state" != "true|true|false|false|true|false|false|true" ]]; then
  echo "ERROR: QA376 did not establish a database owner with ADMIN OPTION for anon only: '$partial_admin_state'." >&2
  exit 1
fi

before_partial_admin_snapshot="$(catalog_snapshot)"
run_expected_rejection "qa376_partial_admin_runner" "qa376-partial-admin-only"
after_partial_admin_snapshot="$(catalog_snapshot)"
if [[ "$after_partial_admin_snapshot" != "$before_partial_admin_snapshot" ]]; then
  echo "ERROR: QA376 partial ADMIN OPTION rejection changed the initialized fixture catalog or data." >&2
  exit 1
fi

echo "QA376 passed: a database owner with CREATEROLE and ADMIN OPTION for anon only, but no SET/ADMIN OPTION for authenticated, was rejected before fixture changes; catalog and data snapshots remained unchanged."

echo "QA373 passed: a non-superuser database owner with CREATEROLE completed the full fixture, pgcrypto installation, migration, SECURITY DEFINER, SET ROLE, and concurrency runner without CREATEDB or pg_monitor; non-owner and no-CREATEROLE roles were rejected before any fixture change."


# QA377: mixed membership capabilities must satisfy the runner independently.
# anon starts SET-capable without ADMIN OPTION; authenticated starts with
# ADMIN OPTION but without SET. The full runner must accept the combination,
# grant only the missing SET path, and complete the same concurrency checks.
admin_psql <<'SQL'
DROP DATABASE qima_test WITH (FORCE);
CREATE ROLE qa377_mixed_membership_runner LOGIN PASSWORD 'qa377-mixed-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa377_mixed_membership_runner;
GRANT anon TO qa377_mixed_membership_runner
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
GRANT authenticated TO qa377_mixed_membership_runner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
SQL

mixed_initial_state="$(db_psql -c "
  SELECT
    (db.datdba = runner.oid)::text || '|' ||
    runner.rolsuper::text || '|' ||
    runner.rolcreaterole::text || '|' ||
    pg_has_role(runner.oid, 'anon'::regrole, 'SET')::text || '|' ||
    COALESCE(anon_members.admin_option, false)::text || '|' ||
    COALESCE(anon_members.set_option, false)::text || '|' ||
    pg_has_role(runner.oid, 'authenticated'::regrole, 'SET')::text || '|' ||
    COALESCE(authenticated_members.admin_option, false)::text || '|' ||
    COALESCE(authenticated_members.set_option, false)::text
  FROM pg_database db
  JOIN pg_roles runner ON runner.rolname = 'qa377_mixed_membership_runner'
  LEFT JOIN pg_auth_members anon_members
    ON anon_members.roleid = 'anon'::regrole
   AND anon_members.member = runner.oid
  LEFT JOIN pg_auth_members authenticated_members
    ON authenticated_members.roleid = 'authenticated'::regrole
   AND authenticated_members.member = runner.oid
  WHERE db.datname = 'qima_test';
")"
if [[ "$mixed_initial_state" != "true|false|true|true|false|true|false|true|false" ]]; then
  echo "ERROR: QA377 did not establish the mixed SET/ADMIN OPTION starting state: '$mixed_initial_state'." >&2
  exit 1
fi

MIXED_RUNNER_URL="postgresql://qa377_mixed_membership_runner:qa377-mixed-only@localhost:5432/qima_test"
set +e
docker exec --env "DATABASE_URL=$MIXED_RUNNER_URL" --workdir /workspace "$CONTAINER_NAME" \
  bash /workspace/tests/sql/run-create-offer-integration.sh \
  >"$TEMP_DIR/mixed-membership-runner.log" 2>&1
mixed_runner_status=$?
set -e
if [[ "$mixed_runner_status" -ne 0 ]]; then
  echo "ERROR: QA377 mixed SET/ADMIN OPTION runner failed with exit $mixed_runner_status." >&2
  tail -n 120 "$TEMP_DIR/mixed-membership-runner.log" >&2
  exit 1
fi
if ! grep -Fq "Observed one granted and one waiting same-tenant advisory lock" "$TEMP_DIR/mixed-membership-runner.log"; then
  echo "ERROR: QA377 mixed-membership runner did not complete the concurrency observation." >&2
  tail -n 120 "$TEMP_DIR/mixed-membership-runner.log" >&2
  exit 1
fi

mixed_after_state="$(db_psql -c "
  SELECT
    pg_has_role('qa377_mixed_membership_runner', 'anon', 'SET')::text || '|' ||
    pg_has_role('qa377_mixed_membership_runner', 'authenticated', 'SET')::text || '|' ||
    pg_has_role('anon', 'qa377_mixed_membership_runner', 'MEMBER')::text || '|' ||
    pg_has_role('authenticated', 'qa377_mixed_membership_runner', 'MEMBER')::text;
")"
if [[ "$mixed_after_state" != "true|true|false|false" ]]; then
  echo "ERROR: QA377 fixture did not preserve one-way SET ROLE access for both client roles: '$mixed_after_state'." >&2
  exit 1
fi

mixed_grantor_state="$(db_psql -c "
  SELECT string_agg(
    membership_state.role_name || ':' ||
    membership_state.has_set::text || ':' ||
    membership_state.grantor_count::text,
    '|' ORDER BY membership_state.role_name
  )
  FROM (
    SELECT
      target.rolname AS role_name,
      bool_or(membership.set_option) AS has_set,
      count(DISTINCT membership.grantor) AS grantor_count
    FROM pg_roles target
    JOIN pg_auth_members membership ON membership.roleid = target.oid
    WHERE target.rolname IN ('anon', 'authenticated')
      AND membership.member = 'qa377_mixed_membership_runner'::regrole
    GROUP BY target.oid, target.rolname
  ) AS membership_state;
")"
if [[ "$mixed_grantor_state" != "anon:true:1|authenticated:true:2" ]]; then
  echo "ERROR: QA377 expected the pre-existing anon SET grant and the authenticated ADMIN-to-SET grant to remain distinguishable, got '$mixed_grantor_state'." >&2
  exit 1
fi

echo "QA377 passed: a database owner with SET-only membership for anon and ADMIN OPTION-only membership for authenticated was accepted; the fixture established the missing SET path, preserved one-way memberships, and completed the full runner/concurrency checks."


# QA378: reverse the mixed membership path. anon has ADMIN OPTION only;
# authenticated already has SET without ADMIN OPTION. The guard must accept
# the per-role combination and the fixture must establish only anon SET.
admin_psql <<'SQL'
DROP DATABASE qima_test WITH (FORCE);
CREATE ROLE qa378_reverse_mixed_runner LOGIN PASSWORD 'qa378-reverse-only'
  CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa378_reverse_mixed_runner;
GRANT anon TO qa378_reverse_mixed_runner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
GRANT authenticated TO qa378_reverse_mixed_runner
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
SQL

reverse_mixed_initial_state="$(db_psql -c "
  SELECT
    (db.datdba = runner.oid)::text || '|' ||
    runner.rolsuper::text || '|' ||
    runner.rolcreaterole::text || '|' ||
    pg_has_role(runner.oid, 'anon'::regrole, 'SET')::text || '|' ||
    COALESCE(anon_members.admin_option, false)::text || '|' ||
    COALESCE(anon_members.set_option, false)::text || '|' ||
    pg_has_role(runner.oid, 'authenticated'::regrole, 'SET')::text || '|' ||
    COALESCE(authenticated_members.admin_option, false)::text || '|' ||
    COALESCE(authenticated_members.set_option, false)::text
  FROM pg_database db
  JOIN pg_roles runner ON runner.rolname = 'qa378_reverse_mixed_runner'
  LEFT JOIN pg_auth_members anon_members
    ON anon_members.roleid = 'anon'::regrole
   AND anon_members.member = runner.oid
  LEFT JOIN pg_auth_members authenticated_members
    ON authenticated_members.roleid = 'authenticated'::regrole
   AND authenticated_members.member = runner.oid
  WHERE db.datname = 'qima_test';
")"
if [[ "$reverse_mixed_initial_state" != "true|false|true|false|true|false|true|false|true" ]]; then
  echo "ERROR: QA378 did not establish the reverse mixed SET/ADMIN OPTION starting state: '$reverse_mixed_initial_state'." >&2
  exit 1
fi

REVERSE_MIXED_RUNNER_URL="postgresql://qa378_reverse_mixed_runner:qa378-reverse-only@localhost:5432/qima_test"
set +e
docker exec --env "DATABASE_URL=$REVERSE_MIXED_RUNNER_URL" --workdir /workspace "$CONTAINER_NAME" \
  bash /workspace/tests/sql/run-create-offer-integration.sh \
  >"$TEMP_DIR/reverse-mixed-membership-runner.log" 2>&1
reverse_mixed_runner_status=$?
set -e
if [[ "$reverse_mixed_runner_status" -ne 0 ]]; then
  echo "ERROR: QA378 reverse mixed SET/ADMIN OPTION runner failed with exit $reverse_mixed_runner_status." >&2
  tail -n 120 "$TEMP_DIR/reverse-mixed-membership-runner.log" >&2
  exit 1
fi
if ! grep -Fq "Observed one granted and one waiting same-tenant advisory lock" "$TEMP_DIR/reverse-mixed-membership-runner.log"; then
  echo "ERROR: QA378 reverse mixed-membership runner did not complete the concurrency observation." >&2
  tail -n 120 "$TEMP_DIR/reverse-mixed-membership-runner.log" >&2
  exit 1
fi

reverse_mixed_after_state="$(db_psql -c "
  SELECT
    pg_has_role('qa378_reverse_mixed_runner', 'anon', 'SET')::text || '|' ||
    pg_has_role('qa378_reverse_mixed_runner', 'authenticated', 'SET')::text || '|' ||
    pg_has_role('anon', 'qa378_reverse_mixed_runner', 'MEMBER')::text || '|' ||
    pg_has_role('authenticated', 'qa378_reverse_mixed_runner', 'MEMBER')::text;
")"
if [[ "$reverse_mixed_after_state" != "true|true|false|false" ]]; then
  echo "ERROR: QA378 fixture did not preserve one-way SET ROLE access for both client roles: '$reverse_mixed_after_state'." >&2
  exit 1
fi

reverse_mixed_grantor_state="$(db_psql -c "
  SELECT string_agg(
    membership_state.role_name || ':' ||
    membership_state.has_set::text || ':' ||
    membership_state.grantor_count::text,
    '|' ORDER BY membership_state.role_name
  )
  FROM (
    SELECT
      target.rolname AS role_name,
      bool_or(membership.set_option) AS has_set,
      count(DISTINCT membership.grantor) AS grantor_count
    FROM pg_roles target
    JOIN pg_auth_members membership ON membership.roleid = target.oid
    WHERE target.rolname IN ('anon', 'authenticated')
      AND membership.member = 'qa378_reverse_mixed_runner'::regrole
    GROUP BY target.oid, target.rolname
  ) AS membership_state;
")"
if [[ "$reverse_mixed_grantor_state" != "anon:true:2|authenticated:true:1" ]]; then
  echo "ERROR: QA378 expected the authenticated SET-only grant and anon ADMIN-to-SET grant to remain distinguishable, got '$reverse_mixed_grantor_state'." >&2
  exit 1
fi

echo "QA378 passed: a database owner with ADMIN OPTION-only membership for anon and SET-only membership for authenticated was accepted; the fixture established the missing anon SET path, preserved one-way memberships, and completed the full runner/concurrency checks."


# QA379: SET ROLE may follow an indirect membership chain only when every
# membership edge in the path has SET TRUE. The positive case exercises the
# real runner through a NOLOGIN bridge role; the negative case changes only the
# runner-to-bridge SET option and must be rejected before fixture changes.
admin_psql -c "DROP DATABASE qima_test WITH (FORCE);"
admin_psql <<'SQL'
CREATE ROLE qa379_indirect_bridge NOLOGIN NOINHERIT;
CREATE ROLE qa379_indirect_runner LOGIN PASSWORD 'qa379-indirect-only'
  CREATEROLE NOINHERIT NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa379_indirect_runner;
GRANT anon TO qa379_indirect_bridge
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
GRANT authenticated TO qa379_indirect_bridge
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
GRANT qa379_indirect_bridge TO qa379_indirect_runner
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
SQL

indirect_positive_initial_state="$(db_psql -c "
  SELECT
    (db.datdba = runner.oid)::text || '|' ||
    runner.rolsuper::text || '|' ||
    runner.rolcreaterole::text || '|' ||
    pg_has_role(runner.oid, 'qa379_indirect_bridge'::regrole, 'SET')::text || '|' ||
    pg_has_role(runner.oid, 'anon'::regrole, 'SET')::text || '|' ||
    pg_has_role(runner.oid, 'authenticated'::regrole, 'SET')::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'anon'::regrole AND member = runner.oid
    )::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'authenticated'::regrole AND member = runner.oid
    )::text || '|' ||
    COALESCE((
      SELECT set_option::text || ':' || inherit_option::text
      FROM pg_auth_members
      WHERE roleid = 'qa379_indirect_bridge'::regrole
        AND member = runner.oid
    ), 'missing') || '|' ||
    COALESCE((
      SELECT set_option::text || ':' || inherit_option::text
      FROM pg_auth_members
      WHERE roleid = 'anon'::regrole
        AND member = 'qa379_indirect_bridge'::regrole
    ), 'missing') || '|' ||
    COALESCE((
      SELECT set_option::text || ':' || inherit_option::text
      FROM pg_auth_members
      WHERE roleid = 'authenticated'::regrole
        AND member = 'qa379_indirect_bridge'::regrole
    ), 'missing')
  FROM pg_database db
  JOIN pg_roles runner ON runner.rolname = 'qa379_indirect_runner'
  WHERE db.datname = 'qima_test';
")"
if [[ "$indirect_positive_initial_state" != "true|false|true|true|true|true|false|false|true:false|true:false|true:false" ]]; then
  echo "ERROR: QA379 did not establish a fully SET-enabled indirect membership chain: '$indirect_positive_initial_state'." >&2
  exit 1
fi

INDIRECT_RUNNER_URL="postgresql://qa379_indirect_runner:qa379-indirect-only@localhost:5432/qima_test"
set +e
docker exec --env "DATABASE_URL=$INDIRECT_RUNNER_URL" --workdir /workspace "$CONTAINER_NAME" \
  bash /workspace/tests/sql/run-create-offer-integration.sh \
  >"$TEMP_DIR/indirect-membership-runner.log" 2>&1
indirect_runner_status=$?
set -e
if [[ "$indirect_runner_status" -ne 0 ]]; then
  echo "ERROR: QA379 indirect SET-chain runner failed with exit $indirect_runner_status." >&2
  tail -n 120 "$TEMP_DIR/indirect-membership-runner.log" >&2
  exit 1
fi
if ! grep -Fq "Observed one granted and one waiting same-tenant advisory lock" "$TEMP_DIR/indirect-membership-runner.log"; then
  echo "ERROR: QA379 indirect SET-chain runner did not complete the concurrency observation." >&2
  tail -n 120 "$TEMP_DIR/indirect-membership-runner.log" >&2
  exit 1
fi

# Prove both SET ROLE commands work in an actual runner-authenticated session,
# not only through pg_has_role catalog inspection.
docker exec --env "DATABASE_URL=$INDIRECT_RUNNER_URL" "$CONTAINER_NAME" \
  psql "$INDIRECT_RUNNER_URL" -X -v ON_ERROR_STOP=1 -q \
  -c 'SET ROLE anon; RESET ROLE; SET ROLE authenticated; RESET ROLE;' >/dev/null

indirect_positive_after_state="$(db_psql -c "
  SELECT
    pg_has_role('qa379_indirect_runner', 'anon', 'SET')::text || '|' ||
    pg_has_role('qa379_indirect_runner', 'authenticated', 'SET')::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'anon'::regrole
        AND member = 'qa379_indirect_runner'::regrole
    )::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'authenticated'::regrole
        AND member = 'qa379_indirect_runner'::regrole
    )::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'qa379_indirect_bridge'::regrole
        AND member = 'qa379_indirect_runner'::regrole
        AND set_option AND NOT inherit_option
    )::text || '|' ||
    pg_has_role('anon', 'qa379_indirect_runner', 'MEMBER')::text || '|' ||
    pg_has_role('authenticated', 'qa379_indirect_runner', 'MEMBER')::text;
")"
if [[ "$indirect_positive_after_state" != "true|true|false|false|true|false|false" ]]; then
  echo "ERROR: QA379 indirect SET chain did not preserve transitive access without reverse or direct memberships: '$indirect_positive_after_state'." >&2
  exit 1
fi

echo "QA379 indirect SET chain passed: the full runner used a two-edge SET-enabled membership path for anon and authenticated, both explicit SET ROLE commands succeeded, no direct target membership or reverse membership was created, and concurrency checks completed."


# QA379 negative: the bridge can SET ROLE to both client roles, but the
# runner-to-bridge edge has SET FALSE. The transitive path must therefore not
# satisfy the runner guard. The fresh qima_test database must remain unchanged.
admin_psql -c "DROP DATABASE qima_test WITH (FORCE);"
admin_psql <<'SQL'
CREATE ROLE qa379_blocked_bridge NOLOGIN NOINHERIT;
CREATE ROLE qa379_blocked_runner LOGIN PASSWORD 'qa379-blocked-only'
  CREATEROLE NOINHERIT NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa379_blocked_runner;
GRANT anon TO qa379_blocked_bridge
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
GRANT authenticated TO qa379_blocked_bridge
  WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;
GRANT qa379_blocked_bridge TO qa379_blocked_runner
  WITH ADMIN FALSE, INHERIT FALSE, SET FALSE;
SQL

indirect_negative_initial_state="$(db_psql -c "
  SELECT
    (db.datdba = runner.oid)::text || '|' ||
    runner.rolsuper::text || '|' ||
    runner.rolcreaterole::text || '|' ||
    pg_has_role(runner.oid, 'qa379_blocked_bridge'::regrole, 'MEMBER')::text || '|' ||
    pg_has_role(runner.oid, 'qa379_blocked_bridge'::regrole, 'SET')::text || '|' ||
    pg_has_role(runner.oid, 'anon'::regrole, 'SET')::text || '|' ||
    pg_has_role(runner.oid, 'authenticated'::regrole, 'SET')::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'anon'::regrole AND member = runner.oid
    )::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = 'authenticated'::regrole AND member = runner.oid
    )::text || '|' ||
    pg_has_role('qa379_blocked_bridge', 'anon', 'SET')::text || '|' ||
    pg_has_role('qa379_blocked_bridge', 'authenticated', 'SET')::text
  FROM pg_database db
  JOIN pg_roles runner ON runner.rolname = 'qa379_blocked_runner'
  WHERE db.datname = 'qima_test';
")"
if [[ "$indirect_negative_initial_state" != "true|false|true|true|false|false|false|false|false|true|true" ]]; then
  echo "ERROR: QA379 did not establish a blocked indirect SET chain with one SET FALSE edge: '$indirect_negative_initial_state'." >&2
  exit 1
fi

indirect_empty_database_snapshot() {
  db_psql -c "
    SELECT
      (SELECT count(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace)::text || '|' ||
      (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace)::text || '|' ||
      (SELECT count(*) FROM pg_extension)::text || '|' ||
      (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = 'qima_test')::text || '|' ||
      (SELECT count(*) FROM pg_roles WHERE rolname LIKE 'qa379_%')::text || '|' ||
      (SELECT count(*)
       FROM pg_auth_members
       WHERE member IN (SELECT oid FROM pg_roles WHERE rolname LIKE 'qa379_%')
          OR roleid IN (SELECT oid FROM pg_roles WHERE rolname LIKE 'qa379_%'))::text;
  "
}

before_indirect_negative_snapshot="$(indirect_empty_database_snapshot)"
run_expected_rejection "qa379_blocked_runner" "qa379-blocked-only"
after_indirect_negative_snapshot="$(indirect_empty_database_snapshot)"
if [[ "$after_indirect_negative_snapshot" != "$before_indirect_negative_snapshot" ]]; then
  echo "ERROR: QA379 rejected an indirect SET chain with a SET FALSE edge only after changing the empty database or role catalog." >&2
  exit 1
fi

echo "QA379 indirect SET chain with a SET FALSE edge was rejected before fixture changes; the empty database, ownership, roles, and membership snapshots remained unchanged."


# QA380: ADMIN OPTION on a bridge role is not ADMIN OPTION on its member roles.
# The runner can administer the bridge, and the bridge can administer anon and
# authenticated, but the runner cannot SET ROLE through any edge and has no
# direct ADMIN OPTION on either client role. The runner guard must fail closed.
admin_psql -c "DROP DATABASE qima_test WITH (FORCE);"
admin_psql <<'SQL'
CREATE ROLE qa380_admin_bridge NOLOGIN NOINHERIT;
CREATE ROLE qa380_admin_runner LOGIN PASSWORD 'qa380-admin-only'
  CREATEROLE NOINHERIT NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE DATABASE qima_test OWNER qa380_admin_runner;
GRANT anon TO qa380_admin_bridge
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
GRANT authenticated TO qa380_admin_bridge
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
GRANT qa380_admin_bridge TO qa380_admin_runner
  WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
SQL

qa380_initial_state="$(db_psql -c "
  SELECT
    (db.datdba = runner.oid)::text || '|' ||
    runner.rolsuper::text || '|' ||
    runner.rolcreaterole::text || '|' ||
    pg_has_role(runner.oid, bridge.oid, 'MEMBER')::text || '|' ||
    pg_has_role(runner.oid, bridge.oid, 'SET')::text || '|' ||
    pg_has_role(runner.oid, anon_role.oid, 'MEMBER')::text || '|' ||
    pg_has_role(runner.oid, anon_role.oid, 'SET')::text || '|' ||
    pg_has_role(runner.oid, authenticated_role.oid, 'MEMBER')::text || '|' ||
    pg_has_role(runner.oid, authenticated_role.oid, 'SET')::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = bridge.oid AND member = runner.oid AND admin_option
    )::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = anon_role.oid AND member = runner.oid AND admin_option
    )::text || '|' ||
    EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE roleid = authenticated_role.oid AND member = runner.oid AND admin_option
    )::text || '|' ||
    COALESCE((
      SELECT admin_option::text || ':' || inherit_option::text || ':' || set_option::text
      FROM pg_auth_members
      WHERE roleid = bridge.oid AND member = runner.oid
    ), 'missing') || '|' ||
    COALESCE((
      SELECT admin_option::text || ':' || inherit_option::text || ':' || set_option::text
      FROM pg_auth_members
      WHERE roleid = anon_role.oid AND member = bridge.oid
    ), 'missing') || '|' ||
    COALESCE((
      SELECT admin_option::text || ':' || inherit_option::text || ':' || set_option::text
      FROM pg_auth_members
      WHERE roleid = authenticated_role.oid AND member = bridge.oid
    ), 'missing')
  FROM pg_database db
  JOIN pg_roles runner ON runner.rolname = 'qa380_admin_runner'
  JOIN pg_roles bridge ON bridge.rolname = 'qa380_admin_bridge'
  JOIN pg_roles anon_role ON anon_role.rolname = 'anon'
  JOIN pg_roles authenticated_role ON authenticated_role.rolname = 'authenticated'
  WHERE db.datname = 'qima_test';
")"
if [[ "$qa380_initial_state" != "true|false|true|true|false|true|false|true|false|true|false|false|true:false:false|true:false:false|true:false:false" ]]; then
  echo "ERROR: QA380 did not establish ADMIN OPTION only on the bridge and its client-role memberships: '$qa380_initial_state'." >&2
  exit 1
fi

run_expected_rejection_qa380() {
  local url="postgresql://qa380_admin_runner:qa380-admin-only@localhost:5432/qima_test"
  local log_file="$TEMP_DIR/qa380-admin-option-nontransitive.log"
  local status
  set +e
  docker exec --env "DATABASE_URL=$url" --workdir /workspace "$CONTAINER_NAME" \
    bash /workspace/tests/sql/run-create-offer-integration.sh >"$log_file" 2>&1
  status=$?
  set -e
  if [[ "$status" -ne 4 ]]; then
    echo "ERROR: QA380 expected the bridge-admin runner to be rejected with exit 4, received $status." >&2
    cat "$log_file" >&2
    exit 1
  fi
  if ! grep -Fq "must be a superuser or own qima_test with CREATEROLE" "$log_file"; then
    echo "ERROR: QA380 bridge-admin runner was rejected for an unexpected reason." >&2
    cat "$log_file" >&2
    exit 1
  fi
}

qa380_snapshot() {
  db_psql -c "
    SELECT
      (SELECT count(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace)::text || '|' ||
      (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace)::text || '|' ||
      (SELECT count(*) FROM pg_extension)::text || '|' ||
      (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = 'qima_test')::text || '|' ||
      (SELECT count(*) FROM pg_roles WHERE rolname LIKE 'qa380_%')::text || '|' ||
      (SELECT count(*)
       FROM pg_auth_members
       WHERE member IN (SELECT oid FROM pg_roles WHERE rolname LIKE 'qa380_%')
          OR roleid IN (SELECT oid FROM pg_roles WHERE rolname LIKE 'qa380_%'))::text || '|' ||
      (SELECT count(*)
       FROM pg_auth_members
       WHERE member = 'qa380_admin_runner'::regrole
         AND roleid IN ('anon'::regrole, 'authenticated'::regrole))::text;
  "
}

before_qa380_admin_snapshot="$(qa380_snapshot)"
run_expected_rejection_qa380
after_qa380_admin_snapshot="$(qa380_snapshot)"
if [[ "$after_qa380_admin_snapshot" != "$before_qa380_admin_snapshot" ]]; then
  echo "ERROR: QA380 rejected a transitive ADMIN OPTION path only after changing the empty database, ownership, roles, or memberships." >&2
  exit 1
fi

echo "QA380 passed: ADMIN OPTION on the bridge was not treated as ADMIN OPTION on anon or authenticated; the runner exited 4 before fixture changes and all snapshots remained unchanged."


# QA381: CREATEROLE's implicit ADMIN grant is distinct from the optional
# createrole_self_grant INHERIT/SET grant. Characterize empty, set, inherit,
# and combined settings using a non-superuser role creator.
qa381_guc_state="$(db_psql -c "SELECT setting || '|' || context FROM pg_settings WHERE name = 'createrole_self_grant';")"
if [[ "$qa381_guc_state" != "|user" ]]; then
  echo "ERROR: QA381 expected createrole_self_grant to have an empty default and user context, got '$qa381_guc_state'." >&2
  exit 1
fi

admin_psql <<'SQL'
CREATE ROLE qa381_create_role_runner LOGIN PASSWORD 'qa381-create-role-only'
  CREATEROLE NOINHERIT NOSUPERUSER NOCREATEDB NOREPLICATION NOBYPASSRLS;
GRANT CONNECT ON DATABASE qima_test TO qa381_create_role_runner;
SQL

qa381_runner_psql() {
  docker exec --env PGPASSWORD=qa381-create-role-only "$CONTAINER_NAME" \
    psql -h 127.0.0.1 -U qa381_create_role_runner -d qima_test \
      -X -v ON_ERROR_STOP=1 -q -A -t "$@"
}

qa381_create_target() {
  local setting="$1"
  local target_role="$2"
  qa381_runner_psql -c "SET createrole_self_grant = '$setting'; CREATE ROLE $target_role NOLOGIN;"
}

qa381_create_target "" "qa381_default_target"
qa381_create_target "set" "qa381_set_target"
qa381_create_target "inherit" "qa381_inherit_target"
qa381_create_target "set,inherit" "qa381_both_target"

db_psql -c "
  CREATE SCHEMA qa381_probe_default;
  CREATE SCHEMA qa381_probe_set;
  CREATE SCHEMA qa381_probe_inherit;
  CREATE SCHEMA qa381_probe_both;
  CREATE TABLE qa381_probe_default.inherit_probe (id integer);
  CREATE TABLE qa381_probe_set.inherit_probe (id integer);
  CREATE TABLE qa381_probe_inherit.inherit_probe (id integer);
  CREATE TABLE qa381_probe_both.inherit_probe (id integer);
  REVOKE ALL ON SCHEMA qa381_probe_default FROM PUBLIC;
  REVOKE ALL ON SCHEMA qa381_probe_set FROM PUBLIC;
  REVOKE ALL ON SCHEMA qa381_probe_inherit FROM PUBLIC;
  REVOKE ALL ON SCHEMA qa381_probe_both FROM PUBLIC;
  REVOKE ALL ON TABLE qa381_probe_default.inherit_probe FROM PUBLIC;
  REVOKE ALL ON TABLE qa381_probe_set.inherit_probe FROM PUBLIC;
  REVOKE ALL ON TABLE qa381_probe_inherit.inherit_probe FROM PUBLIC;
  REVOKE ALL ON TABLE qa381_probe_both.inherit_probe FROM PUBLIC;
  GRANT USAGE ON SCHEMA qa381_probe_default TO qa381_default_target;
  GRANT USAGE ON SCHEMA qa381_probe_set TO qa381_set_target;
  GRANT USAGE ON SCHEMA qa381_probe_inherit TO qa381_inherit_target;
  GRANT USAGE ON SCHEMA qa381_probe_both TO qa381_both_target;
  GRANT SELECT ON TABLE qa381_probe_default.inherit_probe TO qa381_default_target;
  GRANT SELECT ON TABLE qa381_probe_set.inherit_probe TO qa381_set_target;
  GRANT SELECT ON TABLE qa381_probe_inherit.inherit_probe TO qa381_inherit_target;
  GRANT SELECT ON TABLE qa381_probe_both.inherit_probe TO qa381_both_target;
"

qa381_public_acl_state="$(db_psql -c "
  SELECT
    (SELECT count(*)::text
     FROM pg_namespace n
     JOIN pg_class c ON c.relnamespace = n.oid
     WHERE n.nspname LIKE 'qa381_probe_%'
       AND c.relname = 'inherit_probe') || '|' ||
    (NOT EXISTS (
      SELECT 1
      FROM pg_namespace n
      WHERE n.nspname LIKE 'qa381_probe_%'
        AND EXISTS (
          SELECT 1
          FROM aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) acl
          WHERE acl.grantee = 0
            AND acl.privilege_type IN ('USAGE', 'CREATE')
        )
    ))::text || '|' ||
    (NOT EXISTS (
      SELECT 1
      FROM pg_namespace n
      JOIN pg_class c ON c.relnamespace = n.oid
      WHERE n.nspname LIKE 'qa381_probe_%'
        AND c.relname = 'inherit_probe'
        AND EXISTS (
          SELECT 1
          FROM aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) acl
          WHERE acl.grantee = 0
        )
    ))::text;
")"
if [[ "$qa381_public_acl_state" != "4|true|true" ]]; then
  echo "ERROR: QA381 expected four isolated schema/table pairs with no PUBLIC ACLs, got '$qa381_public_acl_state'." >&2
  exit 1
fi

qa381_catalog_state() {
  local target_role="$1"
  db_psql -c "
    SELECT
      count(*)::text || '|' ||
      count(*) FILTER (
        WHERE admin_option AND NOT inherit_option AND NOT set_option
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT admin_option AND NOT inherit_option AND set_option
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT admin_option AND inherit_option AND NOT set_option
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT admin_option AND inherit_option AND set_option
      )::text || '|' ||
      count(DISTINCT grantor)::text || '|' ||
      count(*) FILTER (
        WHERE grantor = 'qa381_create_role_runner'::regrole
      )::text
    FROM pg_auth_members
    WHERE roleid = '$target_role'::regrole
      AND member = 'qa381_create_role_runner'::regrole;
  "
}

qa381_assert_catalog_state() {
  local target_role="$1"
  local expected="$2"
  local actual
  actual="$(qa381_catalog_state "$target_role")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: QA381 catalog memberships for $target_role were '$actual', expected '$expected'." >&2
    exit 1
  fi
}

# Keep membership semantics separate from object ACL checks. The first
# runtime attempt returned has_table_privilege=true while pg_has_role(...,
# 'USAGE') was false. The direct SELECT probe below is the behavioral oracle
# for inherited table access; this tuple reports only effective membership.
qa381_effective_state() {
  local target_role="$1"
  db_psql -c "
    SELECT
      pg_has_role('qa381_create_role_runner', '$target_role', 'SET')::text || '|' ||
      pg_has_role('qa381_create_role_runner', '$target_role', 'USAGE')::text;
  "
}

qa381_assert_effective_state() {
  local target_role="$1"
  local expected="$2"
  local actual
  actual="$(qa381_effective_state "$target_role")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: QA381 effective SET/INHERIT state for $target_role was '$actual', expected '$expected'." >&2
    exit 1
  fi
}

qa381_direct_select_diagnostic() {
  local target_role="$1"
  local schema_name="$2"
  local table_name="$3"
  local qualified_table="$schema_name.$table_name"
  echo "QA381 direct-SELECT diagnostic: authenticated runner identity and effective privileges:" >&2
  qa381_runner_psql -c "
    SELECT
      session_user::text || '|' ||
      current_user::text || '|' ||
      (SELECT rolsuper::text FROM pg_roles WHERE rolname = current_user) || '|' ||
      (SELECT rolinherit::text FROM pg_roles WHERE rolname = current_user) || '|' ||
      has_schema_privilege(current_user, '$schema_name', 'USAGE')::text || '|' ||
      has_table_privilege(current_user, '$qualified_table', 'SELECT')::text || '|' ||
      has_any_column_privilege(current_user, '$qualified_table', 'SELECT')::text || '|' ||
      pg_has_role(current_user, '$target_role', 'USAGE')::text || '|' ||
      pg_has_role(current_user, '$target_role', 'SET')::text;
  " >&2 || true
  echo "QA381 direct-SELECT diagnostic: database, schema, and table owner membership paths:" >&2
  db_psql -c "
    SELECT
      pg_get_userbyid(d.datdba)::text || '|' ||
      pg_has_role('qa381_create_role_runner', d.datdba, 'USAGE')::text || '|' ||
      pg_get_userbyid(n.nspowner)::text || '|' ||
      pg_has_role('qa381_create_role_runner', n.nspowner, 'USAGE')::text || '|' ||
      pg_get_userbyid(c.relowner)::text || '|' ||
      pg_has_role('qa381_create_role_runner', c.relowner, 'USAGE')::text || '|' ||
      pg_has_role('qa381_create_role_runner', 'pg_database_owner', 'USAGE')::text
    FROM pg_database d
    JOIN pg_namespace n ON n.nspname = '$schema_name'
    JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = '$table_name'
    WHERE d.datname = current_database();
  " >&2 || true
  echo "QA381 direct-SELECT diagnostic: all direct memberships and effective member-role paths:" >&2
  db_psql -c "
    SELECT COALESCE(string_agg(
      pg_get_userbyid(m.roleid)::text || ':' ||
      m.admin_option::text || ':' ||
      m.inherit_option::text || ':' ||
      m.set_option::text,
      ',' ORDER BY pg_get_userbyid(m.roleid)
    ), 'none')
    FROM pg_auth_members m
    WHERE m.member = 'qa381_create_role_runner'::regrole;
    SELECT COALESCE(string_agg(
      r.rolname || ':' ||
      pg_has_role('qa381_create_role_runner', r.oid, 'USAGE')::text || ':' ||
      pg_has_role('qa381_create_role_runner', r.oid, 'SET')::text,
      ',' ORDER BY r.rolname
    ), 'none')
    FROM pg_roles r
    WHERE r.oid <> 'qa381_create_role_runner'::regrole
      AND pg_has_role('qa381_create_role_runner', r.oid, 'MEMBER');
  " >&2 || true
  echo "QA381 direct-SELECT diagnostic: column-level ACLs and effective SELECT:" >&2
  db_psql -c "
    SELECT COALESCE(string_agg(
      a.attname || ':' ||
      COALESCE(a.attacl::text, 'NULL') || ':' ||
      has_column_privilege(
        'qa381_create_role_runner', a.attrelid, a.attname, 'SELECT'
      )::text,
      ',' ORDER BY a.attnum
    ), 'none')
    FROM pg_attribute a
    WHERE a.attrelid = '$qualified_table'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped;
  " >&2 || true
  echo "QA381 direct-SELECT diagnostic: schema/table owners and ACLs:" >&2
  db_psql -c "
    SELECT
      pg_get_userbyid(n.nspowner)::text || '|' ||
      COALESCE(n.nspacl::text, 'NULL') || '|' ||
      pg_get_userbyid(c.relowner)::text || '|' ||
      COALESCE(c.relacl::text, 'NULL')
    FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = '$schema_name'
      AND c.relname = '$table_name';
    SELECT
      pg_get_userbyid(m.grantor)::text || '|' ||
      m.roleid::regrole::text || '|' ||
      m.member::regrole::text || '|' ||
      m.admin_option::text || '|' ||
      m.inherit_option::text || '|' ||
      m.set_option::text
    FROM pg_auth_members m
    WHERE m.member = 'qa381_create_role_runner'::regrole
      AND m.roleid = '$target_role'::regrole;
  " >&2 || true
}

qa381_expect_direct_select() {
  local target_role="$1"
  local schema_name="$2"
  local table_name="$3"
  local expected="$4"
  local qualified_table="$schema_name.$table_name"
  local log_file="$TEMP_DIR/qa381-$target_role-direct-select.log"
  local output
  local status
  if output="$(qa381_runner_psql -c "SELECT count(*) FROM $qualified_table;" 2>"$log_file")"; then
    status=0
  else
    status=$?
  fi
  if [[ "$expected" == "true" ]]; then
    if [[ "$status" -ne 0 || "$output" != "0" ]]; then
      echo "ERROR: QA381 expected inherited SELECT through $target_role on $qualified_table, got status=$status output='$output'." >&2
      cat "$log_file" >&2
      qa381_direct_select_diagnostic "$target_role" "$schema_name" "$table_name"
      exit 1
    fi
  else
    if [[ "$status" -eq 0 ]]; then
      echo "ERROR: QA381 direct SELECT unexpectedly succeeded without INHERIT through $target_role on $qualified_table (status=$status, output='$output')." >&2
      qa381_direct_select_diagnostic "$target_role" "$schema_name" "$table_name"
      exit 1
    fi
    if ! grep -Fq "permission denied" "$log_file"; then
      echo "ERROR: QA381 direct SELECT failed for an unexpected reason through $target_role on $qualified_table." >&2
      cat "$log_file" >&2
      qa381_direct_select_diagnostic "$target_role" "$schema_name" "$table_name"
      exit 1
    fi
  fi
}

qa381_expect_set_role() {
  local target_role="$1"
  local schema_name="$2"
  local table_name="$3"
  local expected="$4"
  local qualified_table="$schema_name.$table_name"
  local log_file="$TEMP_DIR/qa381-$target_role-set-role.log"
  local output
  local status
  if output="$(qa381_runner_psql -c "SET ROLE $target_role; SELECT current_user; SELECT count(*) FROM $qualified_table; RESET ROLE;" 2>"$log_file")"; then
    status=0
  else
    status=$?
  fi
  if [[ "$expected" == "true" ]]; then
    local expected_output
    expected_output="$target_role"$'\n''0'
    if [[ "$status" -ne 0 || "$output" != "$expected_output" ]]; then
      echo "ERROR: QA381 expected SET ROLE and target privileges for $target_role on $qualified_table, got status=$status output='$output'." >&2
      cat "$log_file" >&2
      exit 1
    fi
  else
    if [[ "$status" -eq 0 ]] || ! grep -Fq "permission denied to set role" "$log_file"; then
      echo "ERROR: QA381 expected SET ROLE $target_role to be denied without SET." >&2
      cat "$log_file" >&2
      exit 1
    fi
  fi
}

qa381_assert_catalog_state "qa381_default_target" "1|1|0|0|0|1|0"
qa381_assert_catalog_state "qa381_set_target" "2|1|1|0|0|2|1"
qa381_assert_catalog_state "qa381_inherit_target" "2|1|0|1|0|2|1"
qa381_assert_catalog_state "qa381_both_target" "2|1|0|0|1|2|1"

qa381_assert_effective_state "qa381_default_target" "false|false"
qa381_assert_effective_state "qa381_set_target" "true|false"
qa381_assert_effective_state "qa381_inherit_target" "false|true"
qa381_assert_effective_state "qa381_both_target" "true|true"

qa381_expect_direct_select "qa381_default_target" "qa381_probe_default" "inherit_probe" "false"
qa381_expect_direct_select "qa381_set_target" "qa381_probe_set" "inherit_probe" "false"
qa381_expect_direct_select "qa381_inherit_target" "qa381_probe_inherit" "inherit_probe" "true"
qa381_expect_direct_select "qa381_both_target" "qa381_probe_both" "inherit_probe" "true"

qa381_expect_set_role "qa381_default_target" "qa381_probe_default" "inherit_probe" "false"
qa381_expect_set_role "qa381_set_target" "qa381_probe_set" "inherit_probe" "true"
qa381_expect_set_role "qa381_inherit_target" "qa381_probe_inherit" "inherit_probe" "false"
qa381_expect_set_role "qa381_both_target" "qa381_probe_both" "inherit_probe" "true"

db_psql -c "
  DROP SCHEMA qa381_probe_default CASCADE;
  DROP SCHEMA qa381_probe_set CASCADE;
  DROP SCHEMA qa381_probe_inherit CASCADE;
  DROP SCHEMA qa381_probe_both CASCADE;
"
admin_psql -c "
  DROP ROLE qa381_default_target, qa381_set_target, qa381_inherit_target, qa381_both_target;
  DROP ROLE qa381_create_role_runner;
"
qa381_cleanup_state="$(db_psql -c "
  SELECT
    (SELECT count(*) FROM pg_roles WHERE rolname LIKE 'qa381_%')::text || '|' ||
    (SELECT count(*) FROM pg_namespace WHERE nspname LIKE 'qa381_probe_%')::text;
")"
if [[ "$qa381_cleanup_state" != "0|0" ]]; then
  echo "ERROR: QA381 left temporary roles or schema behind: '$qa381_cleanup_state'." >&2
  exit 1
fi

echo "QA381 passed: CREATEROLE's bootstrap ADMIN grant remained separate from the optional createrole_self_grant SET/INHERIT membership; catalog rows, effective privileges, direct SELECT, SET ROLE, and cleanup matched all four settings."
