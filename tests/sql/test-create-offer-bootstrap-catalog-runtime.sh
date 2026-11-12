#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable qima_test service}"

if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "ERROR: refusing QA364 catalog characterization outside loopback qima_test; no database connection was attempted." >&2
  exit 2
fi

REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "ERROR: psql is required for QA364 catalog characterization." >&2
  exit 127
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT_SQL="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
ADMIN_URL="${DATABASE_URL%/qima_test}/postgres"
TEMP_DB="qima_preflight_catalog_${$}_${RANDOM}"
TEMP_URL="${DATABASE_URL%/qima_test}/$TEMP_DB"
PSQL_ADMIN=("$REAL_PSQL" "$ADMIN_URL" -X -v ON_ERROR_STOP=1)
PSQL_TEMP=("$REAL_PSQL" "$TEMP_URL" -X -v ON_ERROR_STOP=1)

cleanup() {
  local original_status=$?
  set +e
  if ! "${PSQL_ADMIN[@]}" -c "DROP DATABASE IF EXISTS \"$TEMP_DB\" WITH (FORCE)" >/dev/null 2>&1; then
    echo "ERROR: QA364 could not remove its disposable catalog database." >&2
    if [[ "$original_status" -eq 0 ]]; then
      original_status=1
    fi
  fi
  exit "$original_status"
}
trap cleanup EXIT

"${PSQL_ADMIN[@]}" -c "CREATE DATABASE \"$TEMP_DB\"" >/dev/null

# These extensions install public functions and a public base type. Their
# extension-owned members must not make an otherwise empty database look used.
"${PSQL_TEMP[@]}" -c "CREATE EXTENSION pgcrypto WITH SCHEMA public; CREATE EXTENSION hstore WITH SCHEMA public;" >/dev/null

extension_function_count="$("${PSQL_TEMP[@]}" -q -A -t -c "
  SELECT count(*)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_depend d
    ON d.classid = 'pg_proc'::regclass
   AND d.objid = p.oid
   AND d.refclassid = 'pg_extension'::regclass
   AND d.deptype = 'e'
  JOIN pg_extension e ON e.oid = d.refobjid
  WHERE n.nspname = 'public'
    AND e.extname = 'pgcrypto'
    AND p.proname = 'digest';
")"
if [[ "$extension_function_count" -lt 1 ]]; then
  echo "ERROR: expected pgcrypto digest to be registered as an extension-owned public function." >&2
  exit 1
fi

extension_type_count="$("${PSQL_TEMP[@]}" -q -A -t -c "
  SELECT count(*)
  FROM pg_type t
  JOIN pg_namespace n ON n.oid = t.typnamespace
  JOIN pg_depend d
    ON d.classid = 'pg_type'::regclass
   AND d.objid = t.oid
   AND d.refclassid = 'pg_extension'::regclass
   AND d.deptype = 'e'
  JOIN pg_extension e ON e.oid = d.refobjid
  WHERE n.nspname = 'public'
    AND e.extname = 'hstore'
    AND t.typname = 'hstore';
")"
if [[ "$extension_type_count" -ne 1 ]]; then
  echo "ERROR: expected hstore to be registered as an extension-owned public type." >&2
  exit 1
fi

preflight_state() {
  "${PSQL_TEMP[@]}" -q -A -t -v "expected_database=$TEMP_DB" -f "$PREFLIGHT_SQL"
}

assert_state() {
  local expected="$1"
  local description="$2"
  local actual
  actual="$(preflight_state)"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $description returned '$actual'; expected '$expected'." >&2
    exit 1
  fi
}

assert_state "empty" "extension-only baseline"

"${PSQL_TEMP[@]}" -c "CREATE FUNCTION public.qa364_user_function() RETURNS integer LANGUAGE sql IMMUTABLE AS 'SELECT 1';" >/dev/null
assert_state "not_empty" "standalone user-defined function"
"${PSQL_TEMP[@]}" -c "DROP FUNCTION public.qa364_user_function();" >/dev/null
assert_state "empty" "baseline after dropping user-defined function"

"${PSQL_TEMP[@]}" -c "CREATE TYPE public.qa364_user_enum AS ENUM ('one', 'two');" >/dev/null
assert_state "not_empty" "standalone enum type"
"${PSQL_TEMP[@]}" -c "DROP TYPE public.qa364_user_enum;" >/dev/null
assert_state "empty" "baseline after dropping enum type"

"${PSQL_TEMP[@]}" -c "CREATE DOMAIN public.qa364_user_domain AS text CHECK (VALUE <> '');" >/dev/null
assert_state "not_empty" "standalone domain type"
"${PSQL_TEMP[@]}" -c "DROP DOMAIN public.qa364_user_domain;" >/dev/null
assert_state "empty" "baseline after dropping domain type"

"${PSQL_TEMP[@]}" -c "CREATE TYPE public.qa364_user_range AS RANGE (subtype = integer);" >/dev/null
assert_state "not_empty" "standalone range and generated multirange types"
"${PSQL_TEMP[@]}" -c "DROP TYPE public.qa364_user_range CASCADE;" >/dev/null
assert_state "empty" "baseline after dropping range and multirange types"

"${PSQL_TEMP[@]}" -c "CREATE TYPE public.qa364_user_composite AS (value integer);" >/dev/null
assert_state "not_empty" "standalone composite type relation"
"${PSQL_TEMP[@]}" -c "DROP TYPE public.qa364_user_composite;" >/dev/null
assert_state "empty" "baseline after dropping composite type"

echo "QA364 passed: extension-owned pgcrypto functions and hstore type were ignored; standalone function, enum, domain, range/multirange, and composite type were rejected; all probes ran in a disposable database."
