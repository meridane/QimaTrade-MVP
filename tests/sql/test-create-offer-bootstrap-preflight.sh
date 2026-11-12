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

for required in "current_database()" "pg_namespace" "pg_class" "pg_proc" "pg_type" "pg_depend" "n.nspname = 'public'" "c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f', 'c')" "d.deptype = 'e'" "t.typtype IN ('b', 'd', 'e', 'r', 'm')" "t.typelem = 0"; do
  grep -Fq -- "$required" <<< "$query" || fail "preflight SQL is missing required catalog check: $required"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|COPY|EXECUTE|PERFORM|COMMIT|ROLLBACK|SAVEPOINT|SET|RESET)([[:space:]]|;)' <<< "$query"; then
  fail "bootstrap preflight SQL must remain read-only"
fi

grep -Fq "qima_test already contains application relations or non-default schemas" "$RUNNER" ||
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
  "qima_test already contains application relations or non-default schemas"
run_case "wrong current database" "wrong_database" 0 3 "preflight" \
  "current database is not qima_test"
run_case "unexpected preflight result" "unexpected" 0 3 "preflight" \
  "preflight returned an unexpected state"
run_case "preflight connection failure" "empty" 42 42 "preflight" \
  "Could not inspect qima_test bootstrap state"
run_case "empty database" "empty" 0 99 $'preflight\nfixture' \
  "mock psql reached fixture file"

echo "QA363 bootstrap preflight contract PASS: initialized, wrong-database, unexpected, and failed preflights stop before fixture DDL/DML; an empty qima_test reaches only the first fixture call."
