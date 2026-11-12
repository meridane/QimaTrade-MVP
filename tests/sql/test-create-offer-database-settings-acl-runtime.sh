#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable qima_test database}"

if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "ERROR: refusing QA370 database-settings characterization outside loopback qima_test; no database connection was attempted." >&2
  exit 2
fi

REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "ERROR: psql is required for QA370 database-settings characterization." >&2
  exit 127
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT_SQL="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
BASE_URL="$(printf '%s\n' "$DATABASE_URL" | sed 's#/qima_test$##')"
RUN_TAG="${GITHUB_RUN_ID:-local}"
TEMP_DB="qima_qa370_current_${RUN_TAG}_$$_$RANDOM"
OTHER_DB="qima_qa370_other_${RUN_TAG}_$$_$RANDOM"
ROLE_NAME="q370_owner_$$_$RANDOM"
GRANTEE_NAME="q370_grantee_$$_$RANDOM"
ADMIN_URL="$BASE_URL/postgres"
TEMP_URL="$BASE_URL/$TEMP_DB"
OTHER_URL="$BASE_URL/$OTHER_DB"
TEMP_DB_CREATED=false
OTHER_DB_CREATED=false
ROLE_CREATED=false
GRANTEE_CREATED=false
PARAMETER_ACL_GRANTED=false

PSQL_ADMIN=("$REAL_PSQL" "$ADMIN_URL" -X -v ON_ERROR_STOP=1)
PSQL_TEMP=("$REAL_PSQL" "$TEMP_URL" -X -v ON_ERROR_STOP=1)
PSQL_OTHER=("$REAL_PSQL" "$OTHER_URL" -X -v ON_ERROR_STOP=1)

cleanup() {
  local original_status=$?
  local cleanup_status=0
  local remaining_databases=0
  local remaining_roles=0
  set +e

  if [[ "$TEMP_DB_CREATED" == true ]]; then
    "${PSQL_ADMIN[@]}" -c "DROP DATABASE IF EXISTS \"$TEMP_DB\" WITH (FORCE);" >/dev/null 2>&1 || cleanup_status=1
  fi
  if [[ "$OTHER_DB_CREATED" == true ]]; then
    "${PSQL_ADMIN[@]}" -c "DROP DATABASE IF EXISTS \"$OTHER_DB\" WITH (FORCE);" >/dev/null 2>&1 || cleanup_status=1
  fi
  if [[ "$PARAMETER_ACL_GRANTED" == true ]]; then
    "${PSQL_ADMIN[@]}" -c "REVOKE SET ON PARAMETER work_mem FROM \"$ROLE_NAME\";" >/dev/null 2>&1 || cleanup_status=1
  fi
  if [[ "$ROLE_CREATED" == true ]]; then
    "${PSQL_ADMIN[@]}" -c "DROP ROLE IF EXISTS \"$ROLE_NAME\";" >/dev/null 2>&1 || cleanup_status=1
  fi
  if [[ "$GRANTEE_CREATED" == true ]]; then
    "${PSQL_ADMIN[@]}" -c "DROP ROLE IF EXISTS \"$GRANTEE_NAME\";" >/dev/null 2>&1 || cleanup_status=1
  fi

  remaining_databases="$("${PSQL_ADMIN[@]}" -q -A -t -c "SELECT count(*) FROM pg_database WHERE datname IN ('$TEMP_DB', '$OTHER_DB');" 2>/dev/null)"
  remaining_roles="$("${PSQL_ADMIN[@]}" -q -A -t -c "SELECT count(*) FROM pg_roles WHERE rolname IN ('$ROLE_NAME', '$GRANTEE_NAME');" 2>/dev/null)"
  if [[ "$remaining_databases" != "0" || "$remaining_roles" != "0" ]]; then
    echo "ERROR: QA370 cleanup left a disposable database or role behind." >&2
    cleanup_status=1
  fi

  if [[ "$original_status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    echo "ERROR: QA370 could not remove every disposable database and role." >&2
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup EXIT

"${PSQL_ADMIN[@]}" -c "CREATE DATABASE \"$TEMP_DB\" TEMPLATE template0;" >/dev/null
TEMP_DB_CREATED=true
"${PSQL_ADMIN[@]}" -c "CREATE DATABASE \"$OTHER_DB\" TEMPLATE template0;" >/dev/null
OTHER_DB_CREATED=true
"${PSQL_ADMIN[@]}" -c "CREATE ROLE \"$ROLE_NAME\" NOLOGIN;" >/dev/null
ROLE_CREATED=true
"${PSQL_ADMIN[@]}" -c "CREATE ROLE \"$GRANTEE_NAME\" NOLOGIN;" >/dev/null
GRANTEE_CREATED=true

preflight_state() {
  local url="$1"
  local expected_database="$2"
  "$REAL_PSQL" "$url" -X -v ON_ERROR_STOP=1 -q -A -t \
    -v "expected_database=$expected_database" \
    -f "$PREFLIGHT_SQL"
}

assert_state() {
  local url="$1"
  local expected_database="$2"
  local expected="$3"
  local description="$4"
  local actual
  actual="$(preflight_state "$url" "$expected_database")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $description returned '$actual'; expected '$expected'." >&2
    exit 1
  fi
}

query_scalar() {
  local url="$1"
  local query="$2"
  "$REAL_PSQL" "$url" -X -v ON_ERROR_STOP=1 -q -A -t -c "$query"
}

assert_count() {
  local actual="$1"
  local expected="$2"
  local description="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $description returned '$actual'; expected '$expected'." >&2
    exit 1
  fi
}

assert_state "$TEMP_URL" "$TEMP_DB" "empty" "initial QA370 database"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "initial QA370 comparison database"

# QA371: parameter ACLs are cluster-wide (pg_parameter_acl has no database
# ownership key). Characterize the grant from both databases, but do not let
# an unrelated cluster-wide grant make either database look initialized.
parameter_acl_query="SELECT count(*) FROM pg_parameter_acl p CROSS JOIN LATERAL aclexplode(p.paracl) a WHERE p.parname = 'work_mem' AND a.grantee = (SELECT oid FROM pg_roles WHERE rolname = '$ROLE_NAME') AND a.privilege_type = 'SET';"
parameter_acl_before="$(query_scalar "$ADMIN_URL" "$parameter_acl_query")"
assert_count "$parameter_acl_before" "0" "initial QA371 parameter ACL grant"

"${PSQL_ADMIN[@]}" -c "GRANT SET ON PARAMETER work_mem TO \"$ROLE_NAME\";" >/dev/null
PARAMETER_ACL_GRANTED=true

parameter_acl_temp="$(query_scalar "$TEMP_URL" "$parameter_acl_query")"
parameter_acl_other="$(query_scalar "$OTHER_URL" "$parameter_acl_query")"
assert_count "$parameter_acl_temp" "1" "shared parameter ACL visible from current database"
assert_count "$parameter_acl_other" "1" "shared parameter ACL visible from comparison database"
role_has_parameter_set="$(query_scalar "$TEMP_URL" "SELECT has_parameter_privilege('$ROLE_NAME', 'work_mem', 'SET');")"
assert_count "$role_has_parameter_set" "t" "granted role SET privilege on work_mem"
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "cluster-wide parameter ACL must not poison current database"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "cluster-wide parameter ACL must not poison comparison database"

"${PSQL_ADMIN[@]}" -c "REVOKE SET ON PARAMETER work_mem FROM \"$ROLE_NAME\";" >/dev/null
PARAMETER_ACL_GRANTED=false
parameter_acl_after="$(query_scalar "$TEMP_URL" "$parameter_acl_query")"
assert_count "$parameter_acl_after" "0" "QA371 parameter ACL revoke cleanup"
role_has_parameter_set="$(query_scalar "$TEMP_URL" "SELECT has_parameter_privilege('$ROLE_NAME', 'work_mem', 'SET');")"
assert_count "$role_has_parameter_set" "f" "revoked role SET privilege on work_mem"
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "baseline after revoking cluster-wide parameter ACL"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "comparison baseline after revoking cluster-wide parameter ACL"

# ALTER ROLE without IN DATABASE creates a shared role setting (setdatabase=0).
# It is intentionally not attributed to either database by this preflight.
"${PSQL_ADMIN[@]}" -c "ALTER ROLE \"$ROLE_NAME\" SET application_name = 'qa370_global_role_setting';" >/dev/null
global_role_setting_count="$(query_scalar "$ADMIN_URL" "SELECT count(*) FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole WHERE s.setdatabase = 0 AND r.rolname = '$ROLE_NAME';")"
assert_count "$global_role_setting_count" "1" "cluster-wide role setting row"
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "cluster-wide role setting must not poison current database"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "cluster-wide role setting must not poison comparison database"

# Database and role-in-database settings are database-scoped rows in the
# shared catalog. A setting owned by another database must not affect this one.
"${PSQL_ADMIN[@]}" -c "ALTER DATABASE \"$OTHER_DB\" SET work_mem = '16MB';" >/dev/null
"${PSQL_ADMIN[@]}" -c "ALTER ROLE \"$ROLE_NAME\" IN DATABASE \"$OTHER_DB\" SET lock_timeout = '9s';" >/dev/null
other_setting_count="$(query_scalar "$ADMIN_URL" "SELECT count(*) FROM pg_db_role_setting s WHERE s.setdatabase = (SELECT oid FROM pg_database WHERE datname = '$OTHER_DB');")"
assert_count "$other_setting_count" "2" "other-database role/database setting rows"
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "settings owned by another database must not poison current database"
assert_state "$OTHER_URL" "$OTHER_DB" "not_empty" "database and role-in-database settings must be detected in their owner database"

"${PSQL_ADMIN[@]}" -c "ALTER DATABASE \"$OTHER_DB\" RESET work_mem; ALTER ROLE \"$ROLE_NAME\" IN DATABASE \"$OTHER_DB\" RESET lock_timeout;" >/dev/null
other_setting_count="$(query_scalar "$ADMIN_URL" "SELECT count(*) FROM pg_db_role_setting s WHERE s.setdatabase = (SELECT oid FROM pg_database WHERE datname = '$OTHER_DB');")"
assert_count "$other_setting_count" "0" "other-database setting cleanup"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "other-database settings cleanup"

# ALTER DATABASE and ALTER ROLE IN DATABASE both create rows scoped to the
# current database OID and must be rejected independently.
"${PSQL_ADMIN[@]}" -c "ALTER DATABASE \"$TEMP_DB\" SET statement_timeout = '11s';" >/dev/null
current_setting_count="$(query_scalar "$ADMIN_URL" "SELECT count(*) FROM pg_db_role_setting s WHERE s.setdatabase = (SELECT oid FROM pg_database WHERE datname = '$TEMP_DB');")"
assert_count "$current_setting_count" "1" "ALTER DATABASE current-database setting row"
assert_state "$TEMP_URL" "$TEMP_DB" "not_empty" "ALTER DATABASE setting owned by current database"
"${PSQL_ADMIN[@]}" -c "ALTER DATABASE \"$TEMP_DB\" RESET statement_timeout;" >/dev/null
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "ALTER DATABASE setting cleanup"

"${PSQL_ADMIN[@]}" -c "ALTER ROLE \"$ROLE_NAME\" IN DATABASE \"$TEMP_DB\" SET lock_timeout = '13s';" >/dev/null
current_setting_count="$(query_scalar "$ADMIN_URL" "SELECT count(*) FROM pg_db_role_setting s WHERE s.setdatabase = (SELECT oid FROM pg_database WHERE datname = '$TEMP_DB');")"
assert_count "$current_setting_count" "1" "ALTER ROLE IN DATABASE current-database setting row"
assert_state "$TEMP_URL" "$TEMP_DB" "not_empty" "ALTER ROLE IN DATABASE setting owned by current database"
"${PSQL_ADMIN[@]}" -c "ALTER ROLE \"$ROLE_NAME\" IN DATABASE \"$TEMP_DB\" RESET lock_timeout;" >/dev/null
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "ALTER ROLE IN DATABASE setting cleanup"

# pg_default_acl is local to a database. A database-wide default ACL has
# defaclnamespace=0; schema-specific defaults carry that schema's OID.
"${PSQL_TEMP[@]}" -c "ALTER DEFAULT PRIVILEGES FOR ROLE \"$ROLE_NAME\" GRANT SELECT ON TABLES TO \"$GRANTEE_NAME\";" >/dev/null
global_default_acl_count="$(query_scalar "$TEMP_URL" "SELECT count(*) FROM pg_default_acl d WHERE d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = '$ROLE_NAME') AND d.defaclnamespace = 0 AND d.defaclobjtype = 'r';")"
assert_count "$global_default_acl_count" "1" "database-wide default ACL row"
assert_state "$TEMP_URL" "$TEMP_DB" "not_empty" "database-wide default privileges"
"${PSQL_TEMP[@]}" -c "ALTER DEFAULT PRIVILEGES FOR ROLE \"$ROLE_NAME\" REVOKE SELECT ON TABLES FROM \"$GRANTEE_NAME\";" >/dev/null
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "database-wide default ACL cleanup"

"${PSQL_TEMP[@]}" -c "ALTER DEFAULT PRIVILEGES FOR ROLE \"$ROLE_NAME\" IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO \"$GRANTEE_NAME\";" >/dev/null
schema_default_acl_count="$(query_scalar "$TEMP_URL" "SELECT count(*) FROM pg_default_acl d WHERE d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = '$ROLE_NAME') AND d.defaclnamespace = 'public'::regnamespace AND d.defaclobjtype = 'f';")"
assert_count "$schema_default_acl_count" "1" "schema-specific default ACL row"
assert_state "$TEMP_URL" "$TEMP_DB" "not_empty" "schema-specific default privileges"
"${PSQL_TEMP[@]}" -c "ALTER DEFAULT PRIVILEGES FOR ROLE \"$ROLE_NAME\" IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM \"$GRANTEE_NAME\";" >/dev/null
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "schema-specific default ACL cleanup"

# A default ACL in another database is local to that database and must not
# make the current database look initialized.
"${PSQL_OTHER[@]}" -c "ALTER DEFAULT PRIVILEGES FOR ROLE \"$ROLE_NAME\" IN SCHEMA public GRANT SELECT ON TABLES TO \"$GRANTEE_NAME\";" >/dev/null
other_default_acl_count="$(query_scalar "$OTHER_URL" "SELECT count(*) FROM pg_default_acl d WHERE d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = '$ROLE_NAME');")"
assert_count "$other_default_acl_count" "1" "other-database default ACL row"
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "default ACL owned by another database must not poison current database"
assert_state "$OTHER_URL" "$OTHER_DB" "not_empty" "default ACL in its owning database"
"${PSQL_OTHER[@]}" -c "ALTER DEFAULT PRIVILEGES FOR ROLE \"$ROLE_NAME\" IN SCHEMA public REVOKE SELECT ON TABLES FROM \"$GRANTEE_NAME\";" >/dev/null
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "other-database default ACL cleanup"

# The global role setting still exists, but database-local rows have all been
# removed. The current database must remain empty until cleanup drops the role.
global_role_setting_count="$(query_scalar "$ADMIN_URL" "SELECT count(*) FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole WHERE s.setdatabase = 0 AND r.rolname = '$ROLE_NAME';")"
assert_count "$global_role_setting_count" "1" "retained global role setting"
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "final current-database baseline with only a cluster-wide role setting"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "final comparison-database baseline with only a cluster-wide role setting"

echo "QA370 passed: current-database ALTER DATABASE and ALTER ROLE IN DATABASE settings plus database-wide and schema-specific default ACLs were detected; other-database settings/default ACLs and setdatabase=0 global role settings did not poison the current database; all disposable databases and roles were removed."
