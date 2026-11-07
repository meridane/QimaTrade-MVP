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
)

for unsafe_url in "${unsafe_urls[@]}"; do
  if PATH="$TEMP_DIR:$PATH" DATABASE_URL="$unsafe_url" bash "$RUNNER" >"$OUTPUT" 2>&1; then
    echo "ERROR: migration runner accepted an unsafe DATABASE_URL" >&2
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
done



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
