#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESTORE_SCRIPT="$ROOT/tests/sql/restore-prepared-transactions-config.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/mock-bin"
EVENTS="$TEMP_DIR/events.log"
OUTPUT="$TEMP_DIR/output.log"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  ps)
    printf '%s\\n' "${MOCK_CONTAINERS:-postgres-container}"
    printf '%s\\n' docker-ps >> "$MOCK_EVENTS"
    ;;
  exec)
    if [[ "$*" != *"ALTER SYSTEM RESET max_prepared_transactions"* ]]; then
      echo "Unexpected docker exec command." >&2
      exit 90
    fi
    printf '%s\\n' docker-exec-reset >> "$MOCK_EVENTS"
    exit "${MOCK_DOCKER_EXEC_STATUS:-0}"
    ;;
  restart)
    printf '%s\\n' docker-restart >> "$MOCK_EVENTS"
    exit "${MOCK_DOCKER_RESTART_STATUS:-0}"
    ;;
  *)
    echo "Unexpected docker invocation." >&2
    exit 90
    ;;
esac
DOCKER
chmod +x "$MOCK_BIN/docker"

cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *"SHOW max_prepared_transactions"*)
    printf '%s\\n' "${MOCK_RESTORED_VALUE:-0}"
    printf '%s\\n' psql-show >> "$MOCK_EVENTS"
    ;;
  *"pg_prepared_xacts"*)
    printf '%s\\n' "${MOCK_PREPARED_COUNT:-0}"
    printf '%s\\n' psql-prepared >> "$MOCK_EVENTS"
    ;;
  *"pg_database"*)
    printf '%s\\n' "${MOCK_DATABASE_COUNT:-0}"
    printf '%s\\n' psql-database >> "$MOCK_EVENTS"
    ;;
  *)
    echo "Unexpected psql invocation." >&2
    exit 90
    ;;
esac
PSQL
chmod +x "$MOCK_BIN/psql"

cat > "$MOCK_BIN/pg_isready" <<'READY'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' pg-isready >> "$MOCK_EVENTS"
exit "${MOCK_READY_STATUS:-0}"
READY
chmod +x "$MOCK_BIN/pg_isready"

run_restore() {
  local expected_status="$1"
  shift
  : > "$EVENTS"
  set +e
  PATH="$MOCK_BIN:$PATH" \\
    MOCK_EVENTS="$EVENTS" \\
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \\
    RESTORE_REQUIRED=true \\
    BASELINE_MAX_PREPARED_TRANSACTIONS=0 \\
    "$@" bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
  local actual_status=$?
  set -e
  if [[ "$actual_status" -ne "$expected_status" ]]; then
    echo "ERROR: expected restoration exit $expected_status, received $actual_status." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
}

# The successful path must reset, restart, wait, and verify all disposable resources.
run_restore 0
expected="$(printf '%s\\n' docker-ps docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] || ! grep -Fq "returned to baseline 0" "$OUTPUT"; then
  echo "ERROR: restoration did not follow the expected reset/restart/verification sequence." >&2
  printf 'Expected:\\n%s\\nActual:\\n%s\\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# If setup never recorded a change, the always() restoration step must be a no-op.
: > "$EVENTS"
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" RESTORE_REQUIRED=false \\
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
if [[ -s "$EVENTS" ]]; then
  echo "ERROR: restoration performed operations when no configuration change was recorded." >&2
  cat "$EVENTS" >&2
  exit 1
fi

# Remote URLs are rejected before docker or psql can be invoked.
: > "$EVENTS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" \\
  DATABASE_URL="postgresql://postgres:postgres@db.example:5432/qima_test" \\
  RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=0 \\
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
unsafe_status=$?
set -e
if [[ "$unsafe_status" -ne 2 || -s "$EVENTS" ]]; then
  echo "ERROR: remote DATABASE_URL was not rejected before external commands." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Multiple service containers must fail closed before ALTER SYSTEM RESET.
: > "$EVENTS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" MOCK_CONTAINERS=$'one\\ntwo' \\
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \\
  RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=0 \\
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
containers_status=$?
set -e
if [[ "$containers_status" -ne 1 ]] || [[ "$(cat "$EVENTS")" != "docker-ps" ]]; then
  echo "ERROR: ambiguous PostgreSQL service container selection was not rejected safely." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A leftover QA266 prepared transaction must fail the post-restore verification.
run_restore 1 env MOCK_PREPARED_COUNT=1
if ! grep -Fq "disposable QA266 resources remain" "$OUTPUT"; then
  echo "ERROR: leftover prepared transaction was not reported." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The original baseline is explicit; do not reset against an unrecognized value.
: > "$EVENTS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" \\
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \\
  RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=10 \\
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
baseline_status=$?
set -e
if [[ "$baseline_status" -ne 2 || -s "$EVENTS" ]]; then
  echo "ERROR: an unapproved baseline was not rejected before external commands." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if grep -Fq "postgres:postgres" "$OUTPUT"; then
  echo "ERROR: restoration output exposed disposable connection credentials." >&2
  exit 1
fi

echo "Prepared-transaction configuration restoration regression passed: reset/restart order, no-op behavior, loopback URL guard, single-container guard, baseline guard, and residual-resource detection."
