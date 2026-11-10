#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable PostgreSQL CI database}"

# This runner creates and drops dedicated databases and roles. Fail closed
# unless DATABASE_URL is the exact loopback qima_test service used by CI.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing wrapper-owner regression: DATABASE_URL must target qima_test on a loopback host at port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DATABASE="qima_wrapper_owner_test_db"
TEST_ROLE="qima_wrapper_owner_test"
TEST_DELEGATE_ROLE="qima_wrapper_delegate_test"
TEST_DATABASE_URL="${DATABASE_URL%/qima_test}/${TEST_DATABASE}"
created_databases=()
created_role=0
created_delegate_role=0
created_anon=0
created_authenticated=0
temporary_files=()
membership_grants=()
delegate_memberships=()

cleanup() {
  local status=$?
  trap - EXIT

  for database in "${created_databases[@]}"; do
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP DATABASE IF EXISTS ${database} WITH (FORCE)" >/dev/null || status=1
    remaining="$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_database WHERE datname = '${database}'" 2>/dev/null || true)"
    if [[ "$remaining" == "1" ]]; then
      echo "::error::Disposable wrapper-owner database ${database} was not removed." >&2
      status=1
    fi
  done

  for member in "${membership_grants[@]}"; do
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "REVOKE ${TEST_ROLE} FROM ${member}" >/dev/null || status=1
  done
  for member in "${delegate_memberships[@]}"; do
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "REVOKE ${TEST_DELEGATE_ROLE} FROM ${member}" >/dev/null || status=1
  done
  if [[ "$created_delegate_role" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "REVOKE ${TEST_ROLE} FROM ${TEST_DELEGATE_ROLE}" >/dev/null || status=1
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE ${TEST_DELEGATE_ROLE}" >/dev/null || status=1
  fi
  if [[ "$created_role" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE ${TEST_ROLE}" >/dev/null || status=1
  fi
  if [[ "$created_authenticated" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE authenticated" >/dev/null || status=1
  fi
  if [[ "$created_anon" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE anon" >/dev/null || status=1
  fi

  if ((${#temporary_files[@]} > 0)); then
    rm -f -- "${temporary_files[@]}"
  fi
  exit "$status"
}
trap cleanup EXIT

assert_database_absent() {
  local database="$1"
  if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_database WHERE datname = '${database}'")" == "1" ]]; then
    echo "::error::Refusing to reuse existing ${database}; no database was modified." >&2
    return 2
  fi
}

create_database() {
  local database="$1"
  assert_database_absent "$database"
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE DATABASE ${database} TEMPLATE template0"
  created_databases+=("$database")
}

if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = 'anon'")" != "1" ]]; then
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE anon NOLOGIN"
  created_anon=1
fi
if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = 'authenticated'")" != "1" ]]; then
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE authenticated NOLOGIN"
  created_authenticated=1
fi
if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = '${TEST_ROLE}'")" == "1" ]]; then
  echo "::error::Refusing to reuse existing ${TEST_ROLE}; no role was modified." >&2
  exit 2
fi
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE ${TEST_ROLE} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT"
created_role=1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE ${TEST_DELEGATE_ROLE} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT"
created_delegate_role=1

# Positive path: distinct trusted wrapper owner, exact-overload isolation,
# client direct-call denial, and successful SECURITY DEFINER invocation.
create_database "$TEST_DATABASE"
psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/tests/sql/create-offer-wrapper-owner-regression.sql"

run_negative_case() {
  local scenario="$1"
  local wrapper_mode="$2"
  local wrapper_owner="$3"
  local expected_error="$4"
  local client_member="${5:-}"
  local membership_kind="${6:-direct}"
  local database="qima_wrapper_negative_${scenario}"
  local database_url="${DATABASE_URL%/qima_test}/${database}"
  local security_clause="SECURITY DEFINER"
  local log_file
  local membership_state

  create_database "$database"

  psql "$database_url" -X -v ON_ERROR_STOP=1 <<'SQL'
GRANT USAGE ON SCHEMA public TO anon, authenticated, qima_wrapper_owner_test;
GRANT CREATE ON SCHEMA public TO qima_wrapper_owner_test;

CREATE FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
)
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $low_level$
  SELECT '70000000-0000-4000-8000-000000000001'::uuid
$low_level$;

-- Preserve explicit client grants so a failed migration must roll back its
-- preceding REVOKE rather than leave a partially restricted function.
GRANT EXECUTE ON FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
) TO anon, authenticated;
SQL

  if [[ "$wrapper_mode" != "missing" ]]; then
    if [[ "$wrapper_mode" == "invoker" ]]; then
      security_clause="SECURITY INVOKER"
    fi

    if [[ "$wrapper_owner" == "anon" || "$wrapper_owner" == "authenticated" ]]; then
      psql "$database_url" -X -v ON_ERROR_STOP=1 -q -c "GRANT CREATE ON SCHEMA public TO ${wrapper_owner}"
    fi

    psql "$database_url" -X -v ON_ERROR_STOP=1 <<SQL
CREATE FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
)
RETURNS jsonb
LANGUAGE sql
${security_clause}
SET search_path = public
AS \$wrapper\$
  SELECT '{}'::jsonb
\$wrapper\$;

ALTER FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) OWNER TO ${wrapper_owner};
SQL
  fi

  if [[ -n "$client_member" ]]; then
    if [[ "$membership_kind" == "indirect" ]]; then
      # Build a transitive membership path with inheritance and SET ROLE disabled.
      # pg_has_role(..., 'MEMBER') must still detect the client-facing role's
      # indirect membership in the trusted wrapper owner.
      psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "GRANT ${TEST_ROLE} TO ${TEST_DELEGATE_ROLE} WITH INHERIT FALSE, SET FALSE"
      psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "GRANT ${TEST_DELEGATE_ROLE} TO ${client_member} WITH INHERIT FALSE, SET FALSE"
      delegate_memberships+=("$client_member")
    else
      psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "GRANT ${TEST_ROLE} TO ${client_member}"
      membership_grants+=("$client_member")
    fi
    membership_state="$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT pg_has_role('${client_member}', '${TEST_ROLE}', 'MEMBER')")"
    if [[ "$membership_state" != "t" ]]; then
      echo "::error::Expected ${client_member} to be a member of ${TEST_ROLE} for scenario ${scenario} (${membership_kind})." >&2
      return 1
    fi
  fi

  log_file="$(mktemp)"
  temporary_files+=("$log_file")
  if psql "$database_url" -X -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql" >"$log_file" 2>&1; then
    echo "::error::Expected CREATE_OFFER migration failure for scenario ${scenario}, but it succeeded." >&2
    cat "$log_file" >&2
    return 1
  fi

  if ! grep -Fq "$expected_error" "$log_file"; then
    echo "::error::Scenario ${scenario} failed for an unexpected reason." >&2
    cat "$log_file" >&2
    return 1
  fi

  # The migration begins a transaction and revokes client EXECUTE before its
  # wrapper checks. Its expected exception must roll back every ACL change.
  local rollback_state
  rollback_state="$(psql "$database_url" -X -v ON_ERROR_STOP=1 -q -A -t <<'SQL'
SELECT
  has_function_privilege('anon', p.oid, 'EXECUTE')
  AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
  AND EXISTS (
    SELECT 1
    FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
    WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'
  )
  AND EXISTS (
    SELECT 1
    FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
    WHERE a.grantee = (SELECT oid FROM pg_roles WHERE rolname = 'anon')
      AND a.privilege_type = 'EXECUTE'
  )
  AND EXISTS (
    SELECT 1
    FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
    WHERE a.grantee = (SELECT oid FROM pg_roles WHERE rolname = 'authenticated')
      AND a.privilege_type = 'EXECUTE'
  )
FROM pg_proc p
WHERE p.oid = 'public.create_offer_v1(text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure;
SQL
)"

  if [[ "$rollback_state" != "t" ]]; then
    echo "::error::Scenario ${scenario} did not preserve the complete pre-migration ACL after the expected failure (result: ${rollback_state:-no row})." >&2
    cat "$log_file" >&2
    return 1
  fi

  if [[ -n "$client_member" ]]; then
    if [[ "$membership_kind" == "indirect" ]]; then
      psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "REVOKE ${TEST_DELEGATE_ROLE} FROM ${client_member}"
      local -a remaining_delegate_members=()
      for member in "${delegate_memberships[@]}"; do
        if [[ "$member" != "$client_member" ]]; then
          remaining_delegate_members+=("$member")
        fi
      done
      delegate_memberships=("${remaining_delegate_members[@]}")
    else
      psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "REVOKE ${TEST_ROLE} FROM ${client_member}"
      local -a remaining_members=()
      for member in "${membership_grants[@]}"; do
        if [[ "$member" != "$client_member" ]]; then
          remaining_members+=("$member")
        fi
      done
      membership_grants=("${remaining_members[@]}")
    fi
  fi

  echo "CREATE_OFFER negative migration scenario PASS: ${scenario} (expected failure; ACL transaction rolled back)"
}

run_negative_case "missing_wrapper" "missing" "qima_wrapper_owner_test" \
  "Expected CREATE_OFFER SECURITY DEFINER wrapper is missing"
run_negative_case "invoker_wrapper" "invoker" "qima_wrapper_owner_test" \
  "CREATE_OFFER wrapper must remain SECURITY DEFINER"
run_negative_case "anon_wrapper_owner" "definer" "anon" \
  "CREATE_OFFER wrapper must have a trusted non-client owner"
run_negative_case "authenticated_wrapper_owner" "definer" "authenticated" \
  "CREATE_OFFER wrapper must have a trusted non-client owner"
run_negative_case "anon_member_of_wrapper_owner" "definer" "qima_wrapper_owner_test" \
  "CREATE_OFFER wrapper owner must not be a member of a client-facing role" "anon"
run_negative_case "authenticated_member_of_wrapper_owner" "definer" "qima_wrapper_owner_test" \
  "CREATE_OFFER wrapper owner must not be a member of a client-facing role" "authenticated"
run_negative_case "anon_indirect_member_of_wrapper_owner" "definer" "qima_wrapper_owner_test" \
  "CREATE_OFFER wrapper owner must not be a member of a client-facing role" "anon" "indirect"
run_negative_case "authenticated_indirect_member_of_wrapper_owner" "definer" "qima_wrapper_owner_test" \
  "CREATE_OFFER wrapper owner must not be a member of a client-facing role" "authenticated" "indirect"

echo "CREATE_OFFER wrapper-owner positive and negative rollback regressions PASS"
