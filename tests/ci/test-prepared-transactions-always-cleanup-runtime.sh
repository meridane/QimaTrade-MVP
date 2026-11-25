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
case "${MOCK_READY_MODE:-ready}" in
  ready)
    printf '%s\n' pg-isready >> "$MOCK_EVENTS"
    ;;
  never)
    printf '%s\n' pg-isready-failed >> "$MOCK_EVENTS"
    exit 1
    ;;
  after-three|after-fifty-nine|after-sixty)
    ready_count_file="${MOCK_READY_COUNT_FILE:?MOCK_READY_COUNT_FILE is required for bounded-readiness modes}"
    ready_count=0
    if [[ -f "$ready_count_file" ]]; then
      read -r ready_count < "$ready_count_file"
    fi
    ready_count=$((ready_count + 1))
    printf '%s\n' "$ready_count" > "$ready_count_file"
    case "$MOCK_READY_MODE" in
      after-three) failure_limit=3 ;;
      after-fifty-nine) failure_limit=59 ;;
      after-sixty) failure_limit=60 ;;
    esac
    if (( ready_count <= failure_limit )); then
      printf '%s\n' pg-isready-failed >> "$MOCK_EVENTS"
      exit 1
    fi
    printf '%s\n' pg-isready >> "$MOCK_EVENTS"
    ;;
  *)
    echo "Unexpected pg_isready mock mode." >&2
    exit 94
    ;;
esac
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
  MOCK_READY_MODE=ready \
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

# QA452: a service that never becomes ready must block every database/configuration mutation.
TIMEOUT_EVENTS="$TEMP_DIR/readiness-timeout-events.log"
TIMEOUT_LOG="$TEMP_DIR/readiness-timeout.log"
EXPECTED_TIMEOUT_EVENTS="$TEMP_DIR/readiness-timeout-expected.log"
: > "$TIMEOUT_EVENTS"
timeout_status=0
if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$TIMEOUT_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
  MOCK_READY_MODE=never \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$TIMEOUT_LOG" 2>&1; then
  timeout_status=0
else
  timeout_status=$?
fi
{
  printf 'docker-ps\n'
  for attempt in {1..60}; do
    printf 'pg-isready-failed\nsleep-1\n'
  done
} > "$EXPECTED_TIMEOUT_EVENTS"
if [[ "$timeout_status" -ne 1 ]] ||
  [[ "$(cat "$TIMEOUT_LOG")" != "::error::The disposable PostgreSQL service did not become ready before configuration restoration." ]] ||
  [[ "$(cat "$TIMEOUT_EVENTS")" != "$(cat "$EXPECTED_TIMEOUT_EVENTS")" ]]; then
  echo "ERROR: readiness timeout did not fail closed before ALTER SYSTEM RESET or restart." >&2
  cat "$TIMEOUT_EVENTS" >&2
  cat "$TIMEOUT_LOG" >&2
  exit 1
fi
if grep -Eq 'docker-exec-reset|docker-restart|psql-' "$TIMEOUT_EVENTS"; then
  echo "ERROR: readiness timeout reached a database/configuration operation." >&2
  cat "$TIMEOUT_EVENTS" >&2
  exit 1
fi
echo "QA452 readiness-timeout guard passed: 60 failed readiness probes blocked ALTER SYSTEM RESET, restart, and postcondition queries."

# QA453: transient startup failures must delay, not suppress, restoration.
TRANSIENT_EVENTS="$TEMP_DIR/readiness-transient-events.log"
TRANSIENT_LOG="$TEMP_DIR/readiness-transient.log"
TRANSIENT_COUNT_FILE="$TEMP_DIR/readiness-transient-count"
EXPECTED_TRANSIENT_EVENTS="$TEMP_DIR/readiness-transient-expected.log"
: > "$TRANSIENT_EVENTS"
transient_status=0
if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$TRANSIENT_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
  MOCK_READY_MODE=after-three MOCK_READY_COUNT_FILE="$TRANSIENT_COUNT_FILE" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$TRANSIENT_LOG" 2>&1; then
  transient_status=0
else
  transient_status=$?
fi
{
  printf 'docker-ps\n'
  for attempt in {1..3}; do
    printf 'pg-isready-failed\nsleep-1\n'
  done
  printf '%s\n' pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database
} > "$EXPECTED_TRANSIENT_EVENTS"
if [[ "$transient_status" -ne 0 ]] ||
  [[ "$(cat "$TRANSIENT_EVENTS")" != "$(cat "$EXPECTED_TRANSIENT_EVENTS")" ]] ||
  [[ "$(cat "$TRANSIENT_COUNT_FILE")" != "5" ]] ||
  [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  ! grep -Fq "QA267 passed" "$TRANSIENT_LOG" ||
  grep -Fq "postgres:postgres" "$TRANSIENT_LOG"; then
  echo "ERROR: transient readiness failures did not converge before restoration and postcondition verification." >&2
  cat "$TRANSIENT_EVENTS" >&2
  cat "$TRANSIENT_LOG" >&2
  exit 1
fi
echo "QA453 transient-readiness guard passed: three failed probes and sleeps were followed by readiness, then RESET, restart, and all postconditions completed."

# QA454: pin the inclusive 60-probe readiness boundary. Probe 60 may proceed;
# readiness first observed on probe 61 must remain outside the bounded loop.
run_readiness_boundary_case() {
  local mode="$1"
  local expected_failures="$2"
  local expected_status="$3"
  local boundary_events="$TEMP_DIR/${mode}-events.log"
  local boundary_log="$TEMP_DIR/${mode}.log"
  local boundary_count_file="$TEMP_DIR/${mode}-count"
  local expected_boundary_events="$TEMP_DIR/${mode}-expected.log"
  local boundary_status=0
  : > "$boundary_events"
  if PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$boundary_events" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
    MOCK_READY_MODE="$mode" MOCK_READY_COUNT_FILE="$boundary_count_file" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    RESTORE_REQUIRED="$RESTORE_REQUIRED" \
    BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
    bash "$RESTORE_SCRIPT" > "$boundary_log" 2>&1; then
    boundary_status=0
  else
    boundary_status=$?
  fi

  {
    printf 'docker-ps\n'
    for ((attempt = 1; attempt <= expected_failures; attempt++)); do
      printf 'pg-isready-failed\nsleep-1\n'
    done
    if [[ "$mode" == "after-fifty-nine" ]]; then
      printf '%s\n' pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database
    fi
  } > "$expected_boundary_events"

  local expected_probe_count=60
  if [[ "$mode" == "after-fifty-nine" ]]; then
    expected_probe_count=61
    if [[ "$boundary_status" -ne "$expected_status" ]] ||
      [[ "$(cat "$boundary_events")" != "$(cat "$expected_boundary_events")" ]] ||
      [[ "$(cat "$boundary_count_file")" != "$expected_probe_count" ]] ||
      [[ "$(cat "$STATE_FILE")" != "0" ]] ||
      ! grep -Fq "QA267 passed" "$boundary_log" ||
      grep -Fq "postgres:postgres" "$boundary_log"; then
      echo "ERROR: readiness on probe 60 did not complete restoration and all postconditions." >&2
      cat "$boundary_events" >&2
      cat "$boundary_log" >&2
      exit 1
    fi
  else
    if [[ "$boundary_status" -ne "$expected_status" ]] ||
      [[ "$(cat "$boundary_events")" != "$(cat "$expected_boundary_events")" ]] ||
      [[ "$(cat "$boundary_count_file")" != "$expected_probe_count" ]] ||
      [[ "$(cat "$boundary_log")" != "::error::The disposable PostgreSQL service did not become ready before configuration restoration." ]] ||
      grep -Eq 'docker-exec-reset|docker-restart|psql-' "$boundary_events"; then
      echo "ERROR: readiness first observed on probe 61 escaped the 60-probe timeout boundary." >&2
      cat "$boundary_events" >&2
      cat "$boundary_log" >&2
      exit 1
    fi
  fi
}

run_readiness_boundary_case after-fifty-nine 59 0
run_readiness_boundary_case after-sixty 60 1
echo "QA454 readiness boundary passed: probe 60 is accepted; readiness first observed on probe 61 is rejected after exactly 60 probes with no RESET, restart, or postcondition query."
