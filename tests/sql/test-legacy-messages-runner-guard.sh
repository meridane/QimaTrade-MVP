#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-legacy-messages-rls-regression.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
OUTPUT="$TEMP_DIR/runner-output.log"

# If the runner reaches psql for an unsafe URL, this stub makes the test fail.
cat > "$TEMP_DIR/psql" <<'PSQL'
#!/usr/bin/env bash
echo "psql must not be invoked for a rejected DATABASE_URL" >&2
exit 99
PSQL
chmod +x "$TEMP_DIR/psql"

unsafe_urls=(
  "postgresql://postgres:postgres@db.example:5432/qima_test"
  "postgresql://postgres:postgres@localhost:5432/production"
  "postgresql://postgres:postgres@localhost:5432/qima_test?sslmode=require"
  "postgresql://postgres:postgres@localhost:5433/qima_test"
  "https://postgres:postgres@localhost:5432/qima_test"
  "postgresql://postgres:postgres@localhost.evil:5432/qima_test"
  "postgresql://postgres:postgres@127.0.0.2:5432/qima_test"
)

for unsafe_url in "${unsafe_urls[@]}"; do
  set +e
  PATH="$TEMP_DIR:$PATH" DATABASE_URL="$unsafe_url" bash "$RUNNER" >"$OUTPUT" 2>&1
  runner_status=$?
  set -e

  if [[ "$runner_status" -ne 2 ]]; then
    echo "ERROR: migration runner expected URL-guard exit 2, received $runner_status" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  if ! grep -Fq "Refusing to run destructive migration fixture" "$OUTPUT"; then
    echo "ERROR: migration runner failed for a reason other than the URL safety guard" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  if grep -Fq "psql must not be invoked" "$OUTPUT"; then
    echo "ERROR: migration runner invoked psql before rejecting an unsafe URL" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  if grep -Fq "postgres:postgres" "$OUTPUT"; then
    echo "ERROR: migration runner refusal output exposed DATABASE_URL credentials" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

# An unset destination must fail closed before psql, just like a malformed URL.
set +e
env -u DATABASE_URL PATH="$TEMP_DIR:$PATH" bash "$RUNNER" >"$OUTPUT" 2>&1
missing_url_status=$?
set -e
if [[ "$missing_url_status" -ne 1 ]] ||
  ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT" ||
  grep -Fq "psql must not be invoked" "$OUTPUT" ||
  grep -Fq "postgres:postgres" "$OUTPUT"; then
  echo "ERROR: migration runner did not safely reject an unset DATABASE_URL before psql." >&2
  cat "$OUTPUT" >&2
  exit 1
fi



# Exercise the EXIT trap when cleanup itself fails. The first DROP is the
# pre-clean and succeeds; the second DROP is the EXIT-trap cleanup and returns
# a controlled failure. The runner must preserve the primary status and report
# the best-effort cleanup failure without exposing DATABASE_URL.
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  case "$arg" in
    *"DROP DATABASE IF EXISTS qima_message_migration_test WITH (FORCE)"*)
      drop_count=0
      if [[ -f "$MOCK_PSQL_DROP_COUNT" ]]; then
        drop_count="$(cat "$MOCK_PSQL_DROP_COUNT")"
      fi
      drop_count=$((drop_count + 1))
      printf '%s\n' "$drop_count" > "$MOCK_PSQL_DROP_COUNT"
      if [[ "$drop_count" -eq 1 ]]; then
        printf '%s\n' drop-pre >> "$MOCK_PSQL_EVENTS"
        exit 0
      fi
      printf '%s\n' drop-exit >> "$MOCK_PSQL_EVENTS"
      exit "${MOCK_EXIT_DROP_STATUS:-0}"
      ;;
    *"CREATE DATABASE qima_message_migration_test"*)
      printf '%s\n' create >> "$MOCK_PSQL_EVENTS"
      exit 0
      ;;
    *legacy-messages-rls-regression.sql)
      printf '%s\n' legacy >> "$MOCK_PSQL_EVENTS"
      exit 0
      ;;
    *legacy-messages-migration-fixture.sql)
      printf '%s\n' fixture >> "$MOCK_PSQL_EVENTS"
      exit 0
      ;;
    *20261028180000_fix_message_participant_authorization.sql)
      printf '%s\n' migration >> "$MOCK_PSQL_EVENTS"
      exit "${MOCK_MIGRATION_STATUS:-42}"
      ;;
    *legacy-messages-migration-assertions.sql)
      printf '%s\n' assertions >> "$MOCK_PSQL_EVENTS"
      exit 0
      ;;
  esac
done
echo "ERROR: unexpected psql invocation: $*" >&2
exit 90
PSQL
chmod +x "$MOCK_BIN/psql"

run_cleanup_failure_scenario() {
  local scenario="$1"
  local migration_status="$2"
  local cleanup_status="$3"
  local expected_status="$4"
  local events="$TEMP_DIR/$scenario-events.log"
  local drop_count="$TEMP_DIR/$scenario-drop-count"
  rm -f "$drop_count"
  : > "$events"

  set +e
  PATH="$MOCK_BIN:$PATH" \
    MOCK_PSQL_EVENTS="$events" \
    MOCK_PSQL_DROP_COUNT="$drop_count" \
    MOCK_MIGRATION_STATUS="$migration_status" \
    MOCK_EXIT_DROP_STATUS="$cleanup_status" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    bash "$RUNNER" > "$OUTPUT" 2>&1
  local runner_status=$?
  set -e

  if [[ "$runner_status" -ne "$expected_status" ]]; then
    echo "ERROR: $scenario expected exit $expected_status, received $runner_status" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  local expected_events
  if [[ "$migration_status" -eq 0 ]]; then
    expected_events="$(printf '%s\n' legacy drop-pre create fixture migration assertions drop-exit)"
  else
    expected_events="$(printf '%s\n' legacy drop-pre create fixture migration drop-exit)"
  fi
  local actual_events
  actual_events="$(cat "$events")"
  if [[ "$actual_events" != "$expected_events" ]]; then
    echo "ERROR: $scenario executed an unexpected PostgreSQL command sequence" >&2
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected_events" "$actual_events" >&2
    exit 1
  fi

  if ! grep -Fq "Best-effort cleanup of qima_message_migration_test failed (psql exit $cleanup_status)" "$OUTPUT"; then
    echo "ERROR: $scenario did not report the cleanup failure" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
}

# Primary migration failure remains authoritative when EXIT cleanup also fails.
run_cleanup_failure_scenario migration-fails 42 91 42

# A successful migration remains successful, but cleanup failure is visible.
run_cleanup_failure_scenario migration-succeeds 0 91 0

echo "Disposable PostgreSQL runner preserves primary exit 42 when EXIT cleanup fails with 91, and reports best-effort cleanup failure after both failed and successful migrations."


# QA262: exercise the read-only post-run assertion with a psql stub. The real
# PostgreSQL service check is run after the migration runner in CI; these cases
# cover the assertion's fail-closed URL handling and result/error semantics.
ASSERTION_SCRIPT="$ROOT/tests/sql/assert-legacy-migration-database-absent.sh"
ASSERTION_MOCK_BIN="$TEMP_DIR/assertion-mock-bin"
ASSERTION_CALLS="$TEMP_DIR/assertion-psql-calls.log"
mkdir -p "$ASSERTION_MOCK_BIN"
cat > "$ASSERTION_MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$MOCK_ASSERT_PSQL_CALLS"
printf '%s\n' "${MOCK_DATABASE_COUNT:-0}"
exit "${MOCK_PSQL_STATUS:-0}"
PSQL
chmod +x "$ASSERTION_MOCK_BIN/psql"

run_absence_assertion_case() {
  local scenario="$1"
  local database_count="$2"
  local psql_status="$3"
  local expected_status="$4"
  : > "$ASSERTION_CALLS"

  set +e
  PATH="$ASSERTION_MOCK_BIN:$PATH" \
    MOCK_ASSERT_PSQL_CALLS="$ASSERTION_CALLS" \
    MOCK_DATABASE_COUNT="$database_count" \
    MOCK_PSQL_STATUS="$psql_status" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    bash "$ASSERTION_SCRIPT" > "$OUTPUT" 2>&1
  local assertion_status=$?
  set -e

  if [[ "$assertion_status" -ne "$expected_status" ]]; then
    echo "ERROR: $scenario expected exit $expected_status, received $assertion_status" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  if grep -Fq "postgres:postgres" "$OUTPUT"; then
    echo "ERROR: $scenario exposed DATABASE_URL credentials" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
}

# A zero-row result confirms absence; the query must inspect pg_database.
run_absence_assertion_case database-absent 0 0 0
if ! grep -Fq "is absent after the migration runner EXIT trap" "$OUTPUT"; then
  echo "ERROR: absent database was not positively reported" >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "SELECT count(*) FROM pg_database WHERE datname = 'qima_message_migration_test'" "$ASSERTION_CALLS"; then
  echo "ERROR: assertion did not query pg_database for the exact temporary database" >&2
  cat "$ASSERTION_CALLS" >&2
  exit 1
fi

# A remaining database must fail the post-run assertion.
run_absence_assertion_case database-still-exists 1 0 1
if ! grep -Fq "still exists after the runner completed" "$OUTPUT"; then
  echo "ERROR: a remaining migration database was not reported" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A PostgreSQL inspection error must propagate instead of being treated as absence.
run_absence_assertion_case postgres-query-fails 0 91 91

# Unsafe destinations must be rejected before the psql stub is invoked.
: > "$ASSERTION_CALLS"
set +e
PATH="$ASSERTION_MOCK_BIN:$PATH" \
  MOCK_ASSERT_PSQL_CALLS="$ASSERTION_CALLS" \
  DATABASE_URL="postgresql://postgres:postgres@db.example:5432/qima_test" \
  bash "$ASSERTION_SCRIPT" > "$OUTPUT" 2>&1
unsafe_status=$?
set -e
if [[ "$unsafe_status" -ne 2 || -s "$ASSERTION_CALLS" ]]; then
  echo "ERROR: post-run assertion did not reject a remote URL before psql (exit $unsafe_status)" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

echo "QA262 assertion regression passed: absent/present database, psql failure propagation, and remote URL rejection."
