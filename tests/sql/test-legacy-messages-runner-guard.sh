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



# Exercise the EXIT trap after the migration command fails. The mock psql records
# the order of operations and deliberately exits 42 for the migration file.
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
EVENTS="$TEMP_DIR/psql-events.log"
cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  case "$arg" in
    *"DROP DATABASE IF EXISTS qima_message_migration_test WITH (FORCE)"*)
      printf '%s\n' drop >> "$MOCK_PSQL_EVENTS"
      exit 0
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
      exit 42
      ;;
  esac
done
echo "ERROR: unexpected psql invocation: $*" >&2
exit 90
PSQL
chmod +x "$MOCK_BIN/psql"

set +e
PATH="$MOCK_BIN:$PATH" \
  MOCK_PSQL_EVENTS="$EVENTS" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
runner_status=$?
set -e

if [[ "$runner_status" -ne 42 ]]; then
  echo "ERROR: expected original migration failure exit 42, received $runner_status" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

expected_events="$(printf '%s\n' legacy drop create fixture migration drop)"
actual_events="$(cat "$EVENTS")"
if [[ "$actual_events" != "$expected_events" ]]; then
  echo "ERROR: expected EXIT-trap cleanup sequence after migration failure" >&2
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected_events" "$actual_events" >&2
  exit 1
fi

echo "Disposable PostgreSQL URL guard rejected unsafe URLs; EXIT trap dropped the temporary database after migration failure and preserved exit 42."

