#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
CALLS="$TEMP_DIR/psql-calls.log"
OUTPUT="$TEMP_DIR/runner-output.log"
mkdir -p "$MOCK_BIN"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

line_number() {
  local needle="$1"
  local line
  line="$(grep -nF -- "$needle" "$RUNNER" | head -n 1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "required runner contract was not found: $needle"
  printf '%s' "$line"
}

guard_line="$(line_number 'if [[ ! "$DATABASE_URL" =~')"
preflight_file_line="$(line_number 'preflight_sql="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"')"
preflight_line="$(line_number 'if preflight_state=')"
fixture_line="$(line_number '"${PSQL[@]}" -f "$ROOT/tests/sql/fixtures/create-offer-schema.sql"')"

if ! (( guard_line < preflight_file_line && preflight_file_line < preflight_line && preflight_line < fixture_line )); then
  fail "URL allowlist, read-only shared preflight, and first fixture DDL must remain in that order"
fi

grep -Fq 'expected_database=qima_test' "$RUNNER" ||
  fail "runner must bind the expected database name into the shared preflight SQL"

query="$(cat "$ROOT/tests/sql/create-offer-bootstrap-preflight.sql")"

for required in "current_database()" "pg_namespace" "pg_class" "pg_proc" "pg_type" "pg_operator" "pg_opclass" "pg_opfamily" "pg_collation" "pg_publication" "pg_ts_dict" "pg_ts_config" "pg_conversion" "pg_largeobject_metadata" "pg_foreign_data_wrapper" "pg_foreign_server" "pg_user_mapping" "pg_subscription" "s.subdbid" "db.datname = current_database()" "pg_db_role_setting" "s.setdatabase = (" "pg_default_acl" "pg_depend" "n.nspname = 'public'" "c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f', 'c')" "d.deptype = 'e'" "t.typtype IN ('b', 'd', 'e', 'r', 'm')" "t.typelem = 0"; do
  grep -Fq -- "$required" <<< "$query" || fail "preflight SQL is missing required catalog check: $required"
done

for required in "d.classid = 'pg_proc'::regclass" "d.classid = 'pg_type'::regclass" "d.classid = 'pg_operator'::regclass" "d.classid = 'pg_opclass'::regclass" "d.classid = 'pg_opfamily'::regclass" "d.classid = 'pg_collation'::regclass" "d.classid = 'pg_publication'::regclass" "dep.classid = 'pg_ts_dict'::regclass" "dep.classid = 'pg_ts_config'::regclass" "dep.classid = 'pg_conversion'::regclass" "d.classid = 'pg_foreign_data_wrapper'::regclass" "d.classid = 'pg_foreign_server'::regclass" "d.classid = 'pg_user_mapping'::regclass" "d.refclassid = 'pg_extension'::regclass" "WHEN current_database() <> :'expected_database'"; do
  grep -Fq -- "$required" <<< "$query" || fail "preflight SQL is missing extension-ownership or database-identity check: $required"
done

RUNTIME_TEST="$ROOT/tests/sql/test-create-offer-bootstrap-catalog-runtime.sh"
SETTINGS_RUNTIME="$ROOT/tests/sql/test-create-offer-database-settings-acl-runtime.sh"
SETTINGS_STATIC="$ROOT/tests/sql/test-create-offer-database-settings-acl-preflight.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
for required in "CREATE EXTENSION pgcrypto" "CREATE EXTENSION hstore" "CREATE EXTENSION btree_gist" "CREATE EXTENSION unaccent" "extension_dictionary_count" "CREATE TEXT SEARCH DICTIONARY public.qa366_user_dictionary" "CREATE TEXT SEARCH CONFIGURATION public.qa366_user_config" "CREATE CONVERSION public.qa366_user_conversion" "CREATE STATISTICS public.qa366_extended_stats_probe" "CREATE POLICY qa366_policy_probe" "CREATE EVENT TRIGGER qa366_user_event_trigger" "qa366_event_trigger_fn" "CREATE FUNCTION public.qa364_user_function" "CREATE TYPE public.qa364_user_enum AS ENUM" "CREATE DOMAIN public.qa364_user_domain" "AS RANGE" "qa364_user_composite" "CREATE OPERATOR public.===" "CREATE OPERATOR FAMILY public.qa365_user_opfamily" "CREATE OPERATOR CLASS public.qa365_user_opclass" "CREATE COLLATION public.qa365_user_collation" "CREATE PUBLICATION qa365_user_publication" "CREATE EXTENSION postgres_fdw" "extension_fdw_count" "SELECT lo_create(0)" "pg_largeobject_metadata" "SELECT lo_unlink" "CREATE FOREIGN DATA WRAPPER qa367_user_fdw" "CREATE SERVER qa367_user_server" "ALTER EXTENSION postgres_fdw ADD SERVER" "CREATE USER MAPPING FOR CURRENT_USER" "pg_user_mapping" "extension_server_count" "extension_operator_count" "extension_opclass_count" "extension_opfamily_count" "CREATE SUBSCRIPTION" "WITH (connect = false, slot_name = NONE, enabled = false, create_slot = false, copy_data = false)" "pg_subscription" "pg_replication_slots" "pg_replication_origin_create" "pg_replication_origin_drop" "preflight_admin_state" "subscription_cluster_count" "origin_cluster_count" "host=127.0.0.1 port=1 dbname=qa368_remote" "DROP SUBSCRIPTION IF EXISTS" "DROP DATABASE IF EXISTS"; do
  grep -Fq -- "$required" "$RUNTIME_TEST" || fail "QA366 runtime test is missing catalog probe: $required"
done
if grep -Fq "subconninfo" <<< "$query"; then
  fail "bootstrap preflight must never read subscription connection details"
fi
if grep -Fq "pg_replication_origin" <<< "$query"; then
  fail "cluster-wide replication origins must not be treated as database-local bootstrap residue"
fi
if grep -Fq "subconninfo" "$RUNTIME_TEST"; then
  fail "QA368 runtime test must not read subscription connection details"
fi

for required in "pg_db_role_setting" "setdatabase" "setrole" "pg_default_acl" "defaclnamespace" "defaclobjtype"; do
  grep -Fq -- "$required" "$SETTINGS_RUNTIME" || fail "QA370 runtime characterization is missing catalog probe: $required"
done
bash -n "$SETTINGS_RUNTIME" || fail "QA370 runtime script has invalid Bash syntax"
bash -n "$SETTINGS_STATIC" || fail "QA370 static script has invalid Bash syntax"

runtime_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-bootstrap-catalog-runtime.sh' "$WORKFLOW")"
[[ "$runtime_step_count" -eq 2 ]] || fail "QA366 runtime characterization must run on both PostgreSQL jobs; found $runtime_step_count workflow steps"

REPEAT_GUARD="$ROOT/tests/sql/test-create-offer-integration-repeat-guard.sh"
repeat_preflight_line="$(grep -nF 'create-offer-bootstrap-preflight.sql' "$REPEAT_GUARD" | head -n 1 | cut -d: -f1)"
repeat_file_line="$(grep -nF '== *" -f "*' "$REPEAT_GUARD" | head -n 1 | cut -d: -f1)"
[[ -n "$repeat_preflight_line" && -n "$repeat_file_line" && "$repeat_preflight_line" -lt "$repeat_file_line" ]] ||
  fail "repeat-run guard must classify the shared preflight SQL as a read-only query before generic fixture files"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|COPY|EXECUTE|PERFORM|COMMIT|ROLLBACK|SAVEPOINT|SET|RESET)([[:space:]]|;)' <<< "$query"; then
  fail "bootstrap preflight SQL must remain read-only"
fi

grep -Fq "qima_test already contains application catalog objects, database-scoped settings, default ACLs, or non-default schemas" "$RUNNER" ||
  fail "non-empty database refusal diagnostic is missing"
grep -Fq "no fixture DDL/DML was attempted" "$RUNNER" ||
  fail "preflight refusal must explicitly state that fixture DDL/DML was not attempted"

cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *"create-offer-bootstrap-preflight.sql"* ]]; then
  printf 'preflight\n' >> "$MOCK_PSQL_CALLS"
  if [[ "${MOCK_PREFLIGHT_EXIT:-0}" -ne 0 ]]; then
    exit "$MOCK_PREFLIGHT_EXIT"
  fi
  printf '%s\n' "${MOCK_PREFLIGHT_STATE-}"
  exit 0
fi
if [[ " $* " == *" -f "* ]]; then
  printf 'fixture\n' >> "$MOCK_PSQL_CALLS"
  echo "mock psql reached fixture file" >&2
  exit 99
fi
printf 'unexpected\n' >> "$MOCK_PSQL_CALLS"
exit 98
PSQL
chmod +x "$MOCK_BIN/psql"

run_case() {
  local name="$1"
  local state="$2"
  local mock_exit="$3"
  local expected_status="$4"
  local expected_calls="$5"
  local expected_message="$6"
  local status

  : > "$CALLS"
  set +e
  PATH="$MOCK_BIN:$PATH" \
    MOCK_PSQL_CALLS="$CALLS" \
    MOCK_PREFLIGHT_STATE="$state" \
    MOCK_PREFLIGHT_EXIT="$mock_exit" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    bash "$RUNNER" > "$OUTPUT" 2>&1
  status=$?
  set -e

  [[ "$status" -eq "$expected_status" ]] ||
    fail "$name returned exit $status; expected $expected_status: $(cat "$OUTPUT")"
  [[ "$(cat "$CALLS")" == "$expected_calls" ]] ||
    fail "$name made unexpected psql calls: $(cat "$CALLS")"
  if [[ -n "$expected_message" ]]; then
    grep -Fq -- "$expected_message" "$OUTPUT" ||
      fail "$name did not emit its expected refusal diagnostic: $(cat "$OUTPUT")"
  fi
  if grep -Fq "postgres:postgres" "$OUTPUT"; then
    fail "$name exposed DATABASE_URL credentials in its output"
  fi
}

run_case "initialized database" "not_empty" 0 3 "preflight" \
  "qima_test already contains application catalog objects, database-scoped settings, default ACLs, or non-default schemas"
run_case "wrong current database" "wrong_database" 0 3 "preflight" \
  "current database is not qima_test"
run_case "unexpected preflight result" "unexpected" 0 3 "preflight" \
  "preflight returned an unexpected state"
run_case "preflight connection failure" "empty" 42 42 "preflight" \
  "Could not inspect qima_test bootstrap state"
run_case "empty database" "empty" 0 99 $'preflight\nfixture' \
  "mock psql reached fixture file"

echo "QA366/QA367/QA368/QA370 bootstrap catalog contract PASS: extension-aware text-search, conversion, large-object, foreign-data, and database-scoped subscription checks are protected; cluster-wide replication origins are intentionally excluded; the preflight remains read-only and runs on both PostgreSQL jobs."
