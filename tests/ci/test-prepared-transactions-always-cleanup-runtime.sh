#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESTORE_SCRIPT="$ROOT/tests/sql/restore-prepared-transactions-config.sh"

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${SETUP_OUTCOME:?SETUP_OUTCOME is required}"
: "${RESTORE_REQUIRED:?RESTORE_REQUIRED is required}"
: "${BASELINE_MAX_PREPARED_TRANSACTIONS:?BASELINE_MAX_PREPARED_TRANSACTIONS is required}"

SIMULATE_RESTORE_FAILURE="${SIMULATE_RESTORE_FAILURE:-false}"
case "$SIMULATE_RESTORE_FAILURE" in
  true|false) ;;
  *) echo "ERROR: SIMULATE_RESTORE_FAILURE must be true or false." >&2; exit 1 ;;
esac
MOCK_RESTORE_EXIT=0
if [[ "$SIMULATE_RESTORE_FAILURE" == "true" ]]; then
  MOCK_RESTORE_EXIT=52
fi

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

# QA447: lock down Docker discovery, exec target/SQL arguments, and restart target
cat > "$MOCK_BIN/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  ps)
    if [[ "$#" -ne 5 || "$2" != "--filter" || "$3" != "ancestor=postgres:16" ||
      "$4" != "--format" || "$5" != "{{.ID}}" ]]; then
      echo "Unexpected Docker container discovery arguments." >&2
      exit 89
    fi
    printf '%s\n' 0123456789ab
    printf '%s\n' docker-ps >> "$MOCK_EVENTS"
    ;;
  exec)
    if [[ "$#" -ne 11 || "$2" != "0123456789ab" || "$3" != "psql" ||
      "$4" != "-U" || "$5" != "postgres" || "$6" != "-d" ||
      "$7" != "qima_test" || "$8" != "-v" || "$9" != "ON_ERROR_STOP=1" ||
      "${10}" != "-c" || "${11}" != "ALTER SYSTEM RESET max_prepared_transactions" ]]; then
      echo "Unexpected Docker exec target or argument contract." >&2
      exit 90
    fi
    printf '%s\n' 0 > "$MOCK_STATE_FILE"
    printf '%s\n' docker-exec-reset >> "$MOCK_EVENTS"
    if [[ "${MOCK_RESTORE_EXIT:-0}" != "0" ]]; then
      exit "$MOCK_RESTORE_EXIT"
    fi
    ;;
  restart)
    if [[ "$#" -ne 2 || "$2" != "0123456789ab" ]]; then
      echo "Unexpected Docker restart target." >&2
      exit 91
    fi
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
if [[ "$#" -ne 6 ||
  "$1" != "postgresql://postgres:postgres@localhost:5432/qima_test" ||
  "$2" != "-X" || "$3" != "-v" || "$4" != "ON_ERROR_STOP=1" ||
  "$5" != "-Atqc" ]]; then
  echo "Unexpected psql target or argument contract." >&2
  exit 93
fi
case "$6" in
  "SHOW max_prepared_transactions")
    printf '%s\n' psql-show >> "$MOCK_EVENTS"
    cat "$MOCK_STATE_FILE"
    ;;
  "SELECT count(*) FROM pg_prepared_xacts WHERE gid = 'qa266_prepared_cleanup_blocker'")
    printf '%s\n' psql-prepared >> "$MOCK_EVENTS"
    printf '0\n'
    ;;
  "SELECT count(*) FROM pg_database WHERE datname = 'qima_message_migration_test'")
    printf '%s\n' psql-database >> "$MOCK_EVENTS"
    printf '0\n'
    ;;
  *)
    echo "Unexpected psql target or argument contract." >&2
    exit 93
    ;;
esac
PSQL
chmod +x "$MOCK_BIN/psql"

# QA449: prove that malformed psql invocations are rejected before any mock event.
PSQL_REJECT_EVENTS="$TEMP_DIR/psql-reject-events.log"
PSQL_REJECT_LOG="$TEMP_DIR/psql-reject.log"
: > "$PSQL_REJECT_EVENTS"
assert_psql_rejects() {
  local label="$1"
  shift
  local status=0
  : > "$PSQL_REJECT_EVENTS"
  if env MOCK_EVENTS="$PSQL_REJECT_EVENTS" MOCK_STATE_FILE="$STATE_FILE" \
    "$MOCK_BIN/psql" "$@" > "$PSQL_REJECT_LOG" 2>&1; then
    status=0
  else
    status=$?
  fi
  if [[ "$status" -ne 93 ]] ||
    [[ "$(cat "$PSQL_REJECT_LOG")" != "Unexpected psql target or argument contract." ]] ||
    [[ -s "$PSQL_REJECT_EVENTS" ]]; then
    echo "ERROR: psql mock accepted or mishandled the QA449 $label rejection case." >&2
    cat "$PSQL_REJECT_LOG" >&2
    cat "$PSQL_REJECT_EVENTS" >&2
    exit 1
  fi
}
PSQL_URL="postgresql://postgres:postgres@localhost:5432/qima_test"
assert_psql_rejects "missing-argument" "$PSQL_URL" -X -v ON_ERROR_STOP=1 -Atqc
assert_psql_rejects "extra-argument" "$PSQL_URL" -X -v ON_ERROR_STOP=1 -Atqc "SHOW max_prepared_transactions" extra
assert_psql_rejects "wrong-database" "postgresql://postgres:postgres@localhost:5432/other" -X -v ON_ERROR_STOP=1 -Atqc "SHOW max_prepared_transactions"
assert_psql_rejects "reordered-options" "$PSQL_URL" -v ON_ERROR_STOP=1 -X -Atqc "SHOW max_prepared_transactions"
assert_psql_rejects "unknown-query" "$PSQL_URL" -X -v ON_ERROR_STOP=1 -Atqc "SELECT 1"
echo "QA449 psql mock contract passed: missing, extra, wrong-target, reordered-option, and unknown-query invocations were rejected before recording an event."

cat > "$MOCK_BIN/pg_isready" <<'READY'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -ne 8 || "$1" != "-h" || "$2" != "127.0.0.1" ||
  "$3" != "-p" || "$4" != "5432" || "$5" != "-U" ||
  "$6" != "postgres" || "$7" != "-d" || "$8" != "qima_test" ]]; then
  echo "Unexpected pg_isready target or argument contract." >&2
  exit 92
fi
printf '%s\n' pg-isready >> "$MOCK_EVENTS"
READY
chmod +x "$MOCK_BIN/pg_isready"

# QA450: prove that malformed pg_isready invocations are rejected before any mock event.
READY_REJECT_EVENTS="$TEMP_DIR/ready-reject-events.log"
READY_REJECT_LOG="$TEMP_DIR/ready-reject.log"
: > "$READY_REJECT_EVENTS"
assert_ready_rejects() {
  local label="$1"
  shift
  local status=0
  : > "$READY_REJECT_EVENTS"
  if env MOCK_EVENTS="$READY_REJECT_EVENTS" "$MOCK_BIN/pg_isready" "$@" > "$READY_REJECT_LOG" 2>&1; then
    status=0
  else
    status=$?
  fi
  if [[ "$status" -ne 92 ]] ||
    [[ "$(cat "$READY_REJECT_LOG")" != "Unexpected pg_isready target or argument contract." ]] ||
    [[ -s "$READY_REJECT_EVENTS" ]]; then
    echo "ERROR: pg_isready mock accepted or mishandled the QA450 $label rejection case." >&2
    cat "$READY_REJECT_LOG" >&2
    cat "$READY_REJECT_EVENTS" >&2
    exit 1
  fi
}
READY_ARGS=(-h 127.0.0.1 -p 5432 -U postgres -d qima_test)
assert_ready_rejects "missing-argument" -h 127.0.0.1 -p 5432 -U postgres -d
assert_ready_rejects "extra-argument" "${READY_ARGS[@]}" extra
assert_ready_rejects "wrong-host" -h 127.0.0.2 -p 5432 -U postgres -d qima_test
assert_ready_rejects "wrong-port" -h 127.0.0.1 -p 5433 -U postgres -d qima_test
assert_ready_rejects "wrong-user" -h 127.0.0.1 -p 5432 -U other -d qima_test
assert_ready_rejects "wrong-database" -h 127.0.0.1 -p 5432 -U postgres -d other
assert_ready_rejects "reordered-options" -p 5432 -h 127.0.0.1 -U postgres -d qima_test
assert_ready_rejects "empty-host" -h "" -p 5432 -U postgres -d qima_test
assert_ready_rejects "empty-port" -h 127.0.0.1 -p "" -U postgres -d qima_test
assert_ready_rejects "empty-user" -h 127.0.0.1 -p 5432 -U "" -d qima_test
assert_ready_rejects "empty-database" -h 127.0.0.1 -p 5432 -U postgres -d ""
echo "QA450/QA451 pg_isready mock contract passed: missing, extra, empty host/port/user/database, wrong host/port/user/database, and reordered-option invocations were rejected before recording an event."

cat > "$MOCK_BIN/sleep" <<'SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep-%s\n' "$*" >> "$MOCK_EVENTS"
SLEEP
chmod +x "$MOCK_BIN/sleep"

if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT="$MOCK_RESTORE_EXIT" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$RESTORE_LOG" 2>&1; then
  :
else
  restore_status=$?
  if [[ "$SIMULATE_RESTORE_FAILURE" == "true" ]]; then
    expected_failure_events="$(printf '%s\n' docker-ps pg-isready docker-exec-reset)"
    if [[ "$restore_status" -ne 52 ]] ||
      [[ "$(cat "$EVENTS")" != "$expected_failure_events" ]] ||
      [[ "$(cat "$STATE_FILE")" != "0" ]] ||
      ! grep -Fq "ALTER SYSTEM RESET max_prepared_transactions failed (docker exec exit 52); configuration restoration is not confirmed." "$RESTORE_LOG" ||
      grep -Fq "QA267 passed" "$RESTORE_LOG" ||
      grep -Fq "postgres:postgres" "$RESTORE_LOG"; then
      echo "ERROR: the simulated cleanup failure was not preserved or was incorrectly reported as success." >&2
      cat "$EVENTS" >&2
      cat "$RESTORE_LOG" >&2
      exit 1
    fi
    printf 'cleanup_exit_code=%s\ncleanup_failure_observed=true\n' "$restore_status" >> "$GITHUB_OUTPUT"
    echo "QA354 runtime contract passed: the actual restore script returned the expected ambiguous RESET failure (52), did not restart or verify after failure, and did not publish cleanup_ran=true."
    exit "$restore_status"
  fi
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

printf 'cleanup_ran=true\ncleanup_exit_code=0\ncleanup_failure_observed=false\n' >> "$GITHUB_OUTPUT"
echo "QA353 runtime contract passed: GitHub reported the setup step as failure, forwarded its restoration outputs, and the always() step executed the real restoration script with inert Docker/PostgreSQL mocks; baseline 0 and zero residual resources were verified."
