#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESTORE_SCRIPT="$ROOT/tests/sql/restore-prepared-transactions-config.sh"

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${SETUP_OUTCOME:?SETUP_OUTCOME is required}"
: "${RESTORE_REQUIRED:?RESTORE_REQUIRED is required}"
: "${BASELINE_MAX_PREPARED_TRANSACTIONS:?BASELINE_MAX_PREPARED_TRANSACTIONS is required}"

if [[ "$SETUP_OUTCOME" != "failure" ]]; then
  echo "ERROR: the simulated setup step did not report outcome=failure." >&2
  exit 1
fi
if [[ "$RESTORE_REQUIRED" != "true" || "$BASELINE_MAX_PREPARED_TRANSACTIONS" != "0" ]]; then
  echo "ERROR: outputs from the failed setup step were not forwarded exactly." >&2
  exit 1
fi

STATE_FILE="$RUNNER_TEMP/qima-prepared-cleanup-contract-state"
if [[ ! -f "$STATE_FILE" || "$(cat "$STATE_FILE")" != "10" ]]; then
  echo "ERROR: the simulated failed setup did not leave the expected partial configuration state." >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "$RUNNER_TEMP/qima-cleanup-contract.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
EVENTS="$TEMP_DIR/events.log"
RESTORE_LOG="$TEMP_DIR/restore.log"
mkdir -p "$MOCK_BIN"
: > "$EVENTS"

cat > "$MOCK_BIN/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  ps)
    printf '%s\n' qima-postgres-container
    printf '%s\n' docker-ps >> "$MOCK_EVENTS"
    ;;
  exec)
    if [[ "$*" != *"ALTER SYSTEM RESET max_prepared_transactions"* ]]; then
      echo "Unexpected docker exec command." >&2
      exit 90
    fi
    printf '%s\n' 0 > "$MOCK_STATE_FILE"
    printf '%s\n' docker-exec-reset >> "$MOCK_EVENTS"
    ;;
  restart)
    printf '%s\n' docker-restart >> "$MOCK_EVENTS"
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
    printf '%s\n' psql-show >> "$MOCK_EVENTS"
    cat "$MOCK_STATE_FILE"
    ;;
  *"pg_prepared_xacts"*)
    printf '%s\n' psql-prepared >> "$MOCK_EVENTS"
    printf '0\n'
    ;;
  *"pg_database"*)
    printf '%s\n' psql-database >> "$MOCK_EVENTS"
    printf '0\n'
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
printf '%s\n' pg-isready >> "$MOCK_EVENTS"
READY
chmod +x "$MOCK_BIN/pg_isready"

cat > "$MOCK_BIN/sleep" <<'SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep-%s\n' "$*" >> "$MOCK_EVENTS"
SLEEP
chmod +x "$MOCK_BIN/sleep"

if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$EVENTS" MOCK_STATE_FILE="$STATE_FILE" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$RESTORE_LOG" 2>&1; then
  :
else
  restore_status=$?
  echo "ERROR: the actual restoration script failed in the always-cleanup harness (exit $restore_status)." >&2
  cat "$EVENTS" >&2
  cat "$RESTORE_LOG" >&2
  exit "$restore_status"
fi

expected_events="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database)"
if [[ "$(cat "$EVENTS")" != "$expected_events" ]]; then
  echo "ERROR: the actual restoration script did not follow the expected cleanup sequence." >&2
  printf 'Expected:\n%s\nActual:\n' "$expected_events" >&2
  cat "$EVENTS" >&2
  exit 1
fi
if [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  ! grep -Fq "QA267 passed" "$RESTORE_LOG" ||
  grep -Fq "postgres:postgres" "$RESTORE_LOG"; then
  echo "ERROR: restoration did not verify baseline 0 or diagnostics exposed credentials." >&2
  cat "$RESTORE_LOG" >&2
  exit 1
fi

printf 'cleanup_ran=true\n' >> "$GITHUB_OUTPUT"
echo "QA353 runtime contract passed: GitHub reported the setup step as failure, forwarded its restoration outputs, and the always() step executed the real restoration script with inert Docker/PostgreSQL mocks; baseline 0 and zero residual resources were verified."
