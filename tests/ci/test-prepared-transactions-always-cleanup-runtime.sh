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
    printf '%s\n' docker-ps >> "$MOCK_EVENTS"
    if [[ "${MOCK_DOCKER_PS_EXIT:-0}" != "0" ]]; then
      echo "mock Docker discovery failure" >&2
      exit "$MOCK_DOCKER_PS_EXIT"
    fi
    if [[ "${MOCK_DOCKER_PS_OUTPUT+x}" == "x" ]]; then
      printf '%s' "$MOCK_DOCKER_PS_OUTPUT"
    else
      printf '%s\n' 0123456789ab
    fi
    ;;
  exec)
    if [[ "$#" -ne 11 || "$2" != "${MOCK_DOCKER_EXPECTED_ID:-0123456789ab}" || "$3" != "psql" ||
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
    if [[ "$#" -ne 2 || "$2" != "${MOCK_DOCKER_EXPECTED_ID:-0123456789ab}" ]]; then
      echo "Unexpected Docker restart target." >&2
      exit 91
    fi
    printf '%s\n' docker-restart >> "$MOCK_EVENTS"
    if [[ "${MOCK_RESTART_EXIT:-0}" != "0" ]]; then
      exit "$MOCK_RESTART_EXIT"
    fi
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
  "$1" != "${MOCK_PSQL_EXPECTED_URL:-postgresql://postgres:postgres@localhost:5432/qima_test}" ||
  "$2" != "-X" || "$3" != "-v" || "$4" != "ON_ERROR_STOP=1" ||
  "$5" != "-Atqc" ]]; then
  echo "Unexpected psql target or argument contract." >&2
  exit 93
fi
case "$6" in
  "SHOW max_prepared_transactions")
    printf '%s\n' psql-show >> "$MOCK_EVENTS"
    case "${MOCK_PSQL_SHOW_MODE:-state}" in
      state)
        cat "$MOCK_STATE_FILE"
        ;;
      after-three-stale)
        show_count_file="${MOCK_PSQL_SHOW_COUNT_FILE:?MOCK_PSQL_SHOW_COUNT_FILE is required for after-three-stale mode}"
        show_count=0
        if [[ -f "$show_count_file" ]]; then
          read -r show_count < "$show_count_file"
        fi
        show_count=$((show_count + 1))
        printf '%s\n' "$show_count" > "$show_count_file"
        if (( show_count <= 3 )); then
          printf '10\n'
        else
          cat "$MOCK_STATE_FILE"
        fi
        ;;
      invalid-value)
        printf 'not-a-number\n'
        ;;
      command-failure)
        echo "mock psql SHOW failure" >&2
        exit 73
        ;;
      *)
        echo "Unexpected psql SHOW mock mode." >&2
        exit 95
        ;;
    esac
    ;;
  "SELECT count(*) FROM pg_prepared_xacts WHERE gid = 'qa266_prepared_cleanup_blocker'")
    printf '%s\n' psql-prepared >> "$MOCK_EVENTS"
    case "${MOCK_PSQL_PREPARED_MODE:-success}" in
      success)
        printf '0\n'
        ;;
      command-failure)
        echo "mock psql prepared-count failure" >&2
        exit 75
        ;;
      *)
        echo "Unexpected psql prepared-count mock mode." >&2
        exit 96
        ;;
    esac
    ;;
  "SELECT count(*) FROM pg_database WHERE datname = 'qima_message_migration_test'")
    printf '%s\n' psql-database >> "$MOCK_EVENTS"
    case "${MOCK_PSQL_DATABASE_MODE:-success}" in
      success)
        printf '0\n'
        ;;
      command-failure)
        echo "mock psql disposable-database count failure" >&2
        exit 76
        ;;
      invalid-value)
        printf 'not-a-number\n'
        ;;
      *)
        echo "Unexpected psql database-count mock mode." >&2
        exit 97
        ;;
    esac
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
  after-restart-three)
    if grep -Fxq docker-restart "${MOCK_EVENTS:?MOCK_EVENTS is required for after-restart-three mode}"; then
      ready_count_file="${MOCK_READY_COUNT_FILE:?MOCK_READY_COUNT_FILE is required for after-restart-three mode}"
      ready_count=0
      if [[ -f "$ready_count_file" ]]; then
        read -r ready_count < "$ready_count_file"
      fi
      ready_count=$((ready_count + 1))
      printf '%s\n' "$ready_count" > "$ready_count_file"
      if (( ready_count <= 3 )); then
        printf '%s\n' pg-isready-failed >> "$MOCK_EVENTS"
        exit 1
      fi
    fi
    printf '%s\n' pg-isready >> "$MOCK_EVENTS"
    ;;
  after-restart-never)
    if grep -Fxq docker-restart "${MOCK_EVENTS:?MOCK_EVENTS is required for after-restart-never mode}"; then
      ready_count_file="${MOCK_READY_COUNT_FILE:?MOCK_READY_COUNT_FILE is required for after-restart-never mode}"
      ready_count=0
      if [[ -f "$ready_count_file" ]]; then
        read -r ready_count < "$ready_count_file"
      fi
      ready_count=$((ready_count + 1))
      printf '%s\n' "$ready_count" > "$ready_count_file"
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

# QA455: readiness lost after restart must block postcondition queries and success.
POST_RESTART_EVENTS="$TEMP_DIR/post-restart-readiness-events.log"
POST_RESTART_LOG="$TEMP_DIR/post-restart-readiness.log"
POST_RESTART_COUNT_FILE="$TEMP_DIR/post-restart-readiness-count"
EXPECTED_POST_RESTART_EVENTS="$TEMP_DIR/post-restart-readiness-expected.log"
: > "$POST_RESTART_EVENTS"
rm -f "$POST_RESTART_COUNT_FILE"
printf '10\n' > "$STATE_FILE"
post_restart_status=0
if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$POST_RESTART_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
  MOCK_READY_MODE=after-restart-never MOCK_READY_COUNT_FILE="$POST_RESTART_COUNT_FILE" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$POST_RESTART_LOG" 2>&1; then
  post_restart_status=0
else
  post_restart_status=$?
fi
{
  printf 'docker-ps\npg-isready\ndocker-exec-reset\ndocker-restart\n'
  for attempt in {1..60}; do
    printf 'pg-isready-failed\nsleep-1\n'
  done
} > "$EXPECTED_POST_RESTART_EVENTS"
if [[ "$post_restart_status" -ne 1 ]] ||
  [[ "$(cat "$POST_RESTART_LOG")" != "::error::PostgreSQL did not return to max_prepared_transactions=0 after ALTER SYSTEM RESET and restart." ]] ||
  [[ "$(cat "$POST_RESTART_EVENTS")" != "$(cat "$EXPECTED_POST_RESTART_EVENTS")" ]] ||
  [[ "$(cat "$POST_RESTART_COUNT_FILE")" != "60" ]] ||
  [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  grep -Eq 'psql-' "$POST_RESTART_EVENTS"; then
  echo "ERROR: post-restart readiness timeout did not stop before postcondition queries or claim restoration." >&2
  cat "$POST_RESTART_EVENTS" >&2
  cat "$POST_RESTART_LOG" >&2
  exit 1
fi
echo "QA455 post-restart readiness timeout passed: RESET and restart completed, then 60 failed readiness probes blocked all psql postconditions and success reporting."


# QA456: a ready server may still report the pre-RESET setting briefly. Keep
# retrying SHOW until the baseline is observed; do not run resource postconditions early.
CONFIG_CONVERGENCE_EVENTS="$TEMP_DIR/config-convergence-events.log"
CONFIG_CONVERGENCE_LOG="$TEMP_DIR/config-convergence.log"
CONFIG_CONVERGENCE_COUNT_FILE="$TEMP_DIR/config-convergence-show-count"
EXPECTED_CONFIG_CONVERGENCE_EVENTS="$TEMP_DIR/config-convergence-expected.log"
: > "$CONFIG_CONVERGENCE_EVENTS"
rm -f "$CONFIG_CONVERGENCE_COUNT_FILE"
printf '10\n' > "$STATE_FILE"
config_convergence_status=0
if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$CONFIG_CONVERGENCE_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
  MOCK_READY_MODE=ready MOCK_PSQL_SHOW_MODE=after-three-stale \
  MOCK_PSQL_SHOW_COUNT_FILE="$CONFIG_CONVERGENCE_COUNT_FILE" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$CONFIG_CONVERGENCE_LOG" 2>&1; then
  config_convergence_status=0
else
  config_convergence_status=$?
fi
{
  printf 'docker-ps\npg-isready\ndocker-exec-reset\ndocker-restart\n'
  for attempt in {1..3}; do
    printf 'pg-isready\npsql-show\nsleep-1\n'
  done
  printf '%s\n' pg-isready psql-show psql-prepared psql-database
} > "$EXPECTED_CONFIG_CONVERGENCE_EVENTS"
if [[ "$config_convergence_status" -ne 0 ]] ||
  [[ "$(cat "$CONFIG_CONVERGENCE_EVENTS")" != "$(cat "$EXPECTED_CONFIG_CONVERGENCE_EVENTS")" ]] ||
  [[ "$(cat "$CONFIG_CONVERGENCE_COUNT_FILE")" != "4" ]] ||
  [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  ! grep -Fq "QA267 passed" "$CONFIG_CONVERGENCE_LOG" ||
  grep -Fq "PostgreSQL did not return to max_prepared_transactions=0" "$CONFIG_CONVERGENCE_LOG" ||
  grep -Fq "postgres:postgres" "$CONFIG_CONVERGENCE_LOG"; then
  echo "ERROR: restoration did not retry stale SHOW values until the baseline was observed before resource postconditions." >&2
  cat "$CONFIG_CONVERGENCE_EVENTS" >&2
  cat "$CONFIG_CONVERGENCE_LOG" >&2
  exit 1
fi
echo "QA456 configuration-convergence guard passed: three stale SHOW values and sleeps were followed by baseline 0; postconditions ran only after convergence."

# QA457: invalid or failed post-restart SHOW must stop before resource postconditions.
run_post_restart_show_failure_case() {
  local mode="$1"
  local expected_status="$2"
  local expected_diagnostic="$3"
  local label="$4"
  local failure_events="$TEMP_DIR/post-restart-show-${label}-events.log"
  local failure_log="$TEMP_DIR/post-restart-show-${label}.log"
  local expected_failure_events="$TEMP_DIR/post-restart-show-${label}-expected.log"
  local failure_status=0

  : > "$failure_events"
  printf '10\n' > "$STATE_FILE"
  if PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$failure_events" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
    MOCK_READY_MODE=ready MOCK_PSQL_SHOW_MODE="$mode" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    RESTORE_REQUIRED="$RESTORE_REQUIRED" \
    BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
    bash "$RESTORE_SCRIPT" > "$failure_log" 2>&1; then
    failure_status=0
  else
    failure_status=$?
  fi

  printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show > "$expected_failure_events"
  if [[ "$failure_status" -ne "$expected_status" ]] ||
    [[ "$(cat "$failure_events")" != "$(cat "$expected_failure_events")" ]] ||
    [[ "$(cat "$STATE_FILE")" != "0" ]] ||
    ! grep -Fq "$expected_diagnostic" "$failure_log" ||
    grep -Fq "QA267 passed" "$failure_log" ||
    grep -Eq 'psql-prepared|psql-database' "$failure_events" ||
    grep -Fq "postgres:postgres" "$failure_log"; then
    echo "ERROR: post-restart SHOW $label failure did not stop before resource postconditions or success reporting." >&2
    cat "$failure_events" >&2
    cat "$failure_log" >&2
    exit 1
  fi
}

run_post_restart_show_failure_case \
  invalid-value \
  1 \
  "::error::PostgreSQL returned an invalid max_prepared_transactions value after restart; configuration restoration is not confirmed." \
  invalid-value
run_post_restart_show_failure_case \
  command-failure \
  73 \
  "::error::Could not read max_prepared_transactions after PostgreSQL restart (psql exit 73); configuration restoration is not confirmed." \
  command-failure
echo "QA457 post-restart SHOW failure guard passed: invalid configuration output and psql exit 73 both stopped before resource postconditions or success reporting."

# QA458: transient unavailability after restart must be retried before SHOW and postconditions.
POST_RESTART_TRANSIENT_EVENTS="$TEMP_DIR/post-restart-transient-events.log"
POST_RESTART_TRANSIENT_LOG="$TEMP_DIR/post-restart-transient.log"
POST_RESTART_TRANSIENT_COUNT_FILE="$TEMP_DIR/post-restart-transient-count"
EXPECTED_POST_RESTART_TRANSIENT_EVENTS="$TEMP_DIR/post-restart-transient-expected.log"
: > "$POST_RESTART_TRANSIENT_EVENTS"
rm -f "$POST_RESTART_TRANSIENT_COUNT_FILE"
printf '10\n' > "$STATE_FILE"
post_restart_transient_status=0
if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$POST_RESTART_TRANSIENT_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
  MOCK_READY_MODE=after-restart-three MOCK_READY_COUNT_FILE="$POST_RESTART_TRANSIENT_COUNT_FILE" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$POST_RESTART_TRANSIENT_LOG" 2>&1; then
  post_restart_transient_status=0
else
  post_restart_transient_status=$?
fi
{
  printf 'docker-ps\npg-isready\ndocker-exec-reset\ndocker-restart\n'
  for attempt in {1..3}; do
    printf 'pg-isready-failed\nsleep-1\n'
  done
  printf '%s\n' pg-isready psql-show psql-prepared psql-database
} > "$EXPECTED_POST_RESTART_TRANSIENT_EVENTS"
if [[ "$post_restart_transient_status" -ne 0 ]] ||
  [[ "$(cat "$POST_RESTART_TRANSIENT_EVENTS")" != "$(cat "$EXPECTED_POST_RESTART_TRANSIENT_EVENTS")" ]] ||
  [[ "$(cat "$POST_RESTART_TRANSIENT_COUNT_FILE")" != "4" ]] ||
  [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  ! grep -Fq "QA267 passed" "$POST_RESTART_TRANSIENT_LOG" ||
  grep -Fq "postgres:postgres" "$POST_RESTART_TRANSIENT_LOG"; then
  echo "ERROR: post-restart transient readiness failures did not delay SHOW and postconditions until the service became ready." >&2
  cat "$POST_RESTART_TRANSIENT_EVENTS" >&2
  cat "$POST_RESTART_TRANSIENT_LOG" >&2
  exit 1
fi
echo "QA458 post-restart transient-readiness guard passed: three failed probes and sleeps were followed by readiness before SHOW and resource postconditions."

# QA459: a failed Docker restart must preserve its exit status and block every
# post-restart readiness probe, SQL postcondition, and success marker.
RESTART_FAILURE_EVENTS="$TEMP_DIR/restart-failure-events.log"
RESTART_FAILURE_LOG="$TEMP_DIR/restart-failure.log"
EXPECTED_RESTART_FAILURE_EVENTS="$TEMP_DIR/restart-failure-expected.log"
: > "$RESTART_FAILURE_EVENTS"
printf '10\n' > "$STATE_FILE"
restart_failure_status=0
if PATH="$MOCK_BIN:$PATH" \
  MOCK_EVENTS="$RESTART_FAILURE_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 \
  MOCK_RESTART_EXIT=74 MOCK_READY_MODE=ready \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED="$RESTORE_REQUIRED" \
  BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
  bash "$RESTORE_SCRIPT" > "$RESTART_FAILURE_LOG" 2>&1; then
  restart_failure_status=0
else
  restart_failure_status=$?
fi
printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart > "$EXPECTED_RESTART_FAILURE_EVENTS"
if [[ "$restart_failure_status" -ne 74 ]] ||
  [[ "$(cat "$RESTART_FAILURE_EVENTS")" != "$(cat "$EXPECTED_RESTART_FAILURE_EVENTS")" ]] ||
  [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  [[ "$(cat "$RESTART_FAILURE_LOG")" != "::error::PostgreSQL service restart failed (docker restart exit 74); configuration restoration is not confirmed." ]] ||
  grep -Fq "QA267 passed" "$RESTART_FAILURE_LOG" ||
  grep -Eq 'psql-' "$RESTART_FAILURE_EVENTS" ||
  grep -Fq "postgres:postgres" "$RESTART_FAILURE_LOG"; then
  echo "ERROR: Docker restart failure was not preserved or post-restart verification ran after failure." >&2
  cat "$RESTART_FAILURE_EVENTS" >&2
  cat "$RESTART_FAILURE_LOG" >&2
  exit 1
fi
echo "QA459 restart-failure guard passed: Docker restart exit 74 was preserved and no post-restart readiness or psql postconditions ran."

# QA460: a failed prepared-transaction count query must preserve its psql exit
# status and prevent the later disposable-database query or success marker.
PREPARED_COUNT_FAILURE_EVENTS="$TEMP_DIR/prepared-count-failure-events.log"
PREPARED_COUNT_FAILURE_LOG="$TEMP_DIR/prepared-count-failure.log"
EXPECTED_PREPARED_COUNT_FAILURE_EVENTS="$TEMP_DIR/prepared-count-failure-expected.log"
: > "$PREPARED_COUNT_FAILURE_EVENTS"
printf '10\n' > "$STATE_FILE"
prepared_count_failure_status=0
if PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$PREPARED_COUNT_FAILURE_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 MOCK_PSQL_PREPARED_MODE=command-failure MOCK_READY_MODE=ready DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="$RESTORE_REQUIRED" BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" bash "$RESTORE_SCRIPT" > "$PREPARED_COUNT_FAILURE_LOG" 2>&1; then
  prepared_count_failure_status=0
else
  prepared_count_failure_status=$?
fi
printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared > "$EXPECTED_PREPARED_COUNT_FAILURE_EVENTS"
if [[ "$prepared_count_failure_status" -ne 75 ]] ||
  [[ "$(cat "$PREPARED_COUNT_FAILURE_EVENTS")" != "$(cat "$EXPECTED_PREPARED_COUNT_FAILURE_EVENTS")" ]] ||
  [[ "$(cat "$STATE_FILE")" != "0" ]] ||
  ! grep -Fq "::error::Could not verify QA266 prepared-transaction cleanup (psql exit 75); restoration is not confirmed." "$PREPARED_COUNT_FAILURE_LOG" ||
  grep -Fq "QA267 passed" "$PREPARED_COUNT_FAILURE_LOG" ||
  grep -Fq "psql-database" "$PREPARED_COUNT_FAILURE_EVENTS" ||
  grep -Fq "postgres:postgres" "$PREPARED_COUNT_FAILURE_LOG"; then
  echo "ERROR: prepared-transaction count query failure was not preserved or later postconditions ran." >&2
  cat "$PREPARED_COUNT_FAILURE_EVENTS" >&2
  cat "$PREPARED_COUNT_FAILURE_LOG" >&2
  exit 1
fi

echo "QA460 prepared-count failure guard passed: psql exit 75 was preserved and the disposable-database postcondition and success marker were blocked."

# QA461: the disposable migration-database postcondition must fail closed when
# its psql query errors or returns a non-numeric count.
run_database_count_failure_case() {
  local mode="$1"
  local expected_status="$2"
  local expected_diagnostic="$3"
  local label="$4"
  local failure_events="$TEMP_DIR/database-count-${label}-events.log"
  local failure_log="$TEMP_DIR/database-count-${label}.log"
  local expected_failure_events="$TEMP_DIR/database-count-${label}-expected.log"
  local failure_status=0

  : > "$failure_events"
  printf '10\n' > "$STATE_FILE"
  if PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$failure_events" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 MOCK_READY_MODE=ready MOCK_PSQL_DATABASE_MODE="$mode" DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="$RESTORE_REQUIRED" BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" bash "$RESTORE_SCRIPT" > "$failure_log" 2>&1; then
    failure_status=0
  else
    failure_status=$?
  fi

  printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database > "$expected_failure_events"
  if [[ "$failure_status" -ne "$expected_status" ]] ||
    [[ "$(cat "$failure_events")" != "$(cat "$expected_failure_events")" ]] ||
    [[ "$(cat "$STATE_FILE")" != "0" ]] ||
    ! grep -Fq "$expected_diagnostic" "$failure_log" ||
    grep -Fq "QA267 passed" "$failure_log" ||
    grep -Fq "postgres:postgres" "$failure_log"; then
    echo "ERROR: disposable migration-database postcondition $label failure was not preserved or success was reported." >&2
    cat "$failure_events" >&2
    cat "$failure_log" >&2
    exit 1
  fi
}

run_database_count_failure_case \
  command-failure \
  76 \
  "::error::Could not verify disposable migration database cleanup (psql exit 76); restoration is not confirmed." \
  command-failure
run_database_count_failure_case \
  invalid-value \
  1 \
  "::error::PostgreSQL returned an invalid disposable migration database count; restoration is not confirmed." \
  invalid-value
echo "QA461 disposable-database postcondition guard passed: psql exit 76 and non-numeric counts both blocked the success marker."

# QA462: Docker discovery failure must preserve its exit status and prevent all
# readiness, configuration, restart, and SQL operations.
DOCKER_DISCOVERY_FAILURE_EVENTS="$TEMP_DIR/docker-discovery-failure-events.log"
DOCKER_DISCOVERY_FAILURE_LOG="$TEMP_DIR/docker-discovery-failure.log"
EXPECTED_DOCKER_DISCOVERY_FAILURE_EVENTS="$TEMP_DIR/docker-discovery-failure-expected.log"
: > "$DOCKER_DISCOVERY_FAILURE_EVENTS"
printf '10\n' > "$STATE_FILE"
docker_discovery_failure_status=0
if PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$DOCKER_DISCOVERY_FAILURE_EVENTS" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 MOCK_DOCKER_PS_EXIT=78 MOCK_READY_MODE=ready DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="$RESTORE_REQUIRED" BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" bash "$RESTORE_SCRIPT" > "$DOCKER_DISCOVERY_FAILURE_LOG" 2>&1; then
  docker_discovery_failure_status=0
else
  docker_discovery_failure_status=$?
fi
printf '%s\n' docker-ps > "$EXPECTED_DOCKER_DISCOVERY_FAILURE_EVENTS"
if [[ "$docker_discovery_failure_status" -ne 78 ]] ||
  [[ "$(cat "$DOCKER_DISCOVERY_FAILURE_EVENTS")" != "$(cat "$EXPECTED_DOCKER_DISCOVERY_FAILURE_EVENTS")" ]] ||
  [[ "$(cat "$STATE_FILE")" != "10" ]] ||
  ! grep -Fqx "::error::Could not discover the disposable PostgreSQL 16 service container for restoration (docker ps exit 78); no readiness, database, or configuration operation was attempted." "$DOCKER_DISCOVERY_FAILURE_LOG" ||
  grep -Eq 'pg-isready|docker-exec-reset|docker-restart|psql-' "$DOCKER_DISCOVERY_FAILURE_EVENTS" ||
  grep -Fq "postgres:postgres" "$DOCKER_DISCOVERY_FAILURE_LOG"; then
  echo "ERROR: Docker discovery failure was not preserved or a later readiness/database/configuration operation ran." >&2
  cat "$DOCKER_DISCOVERY_FAILURE_EVENTS" >&2
  cat "$DOCKER_DISCOVERY_FAILURE_LOG" >&2
  exit 1
fi

echo "QA462 Docker-discovery failure guard passed: docker ps exit 78 was preserved and all readiness, configuration, restart, and SQL operations were blocked."

# QA464: successful Docker discovery must still fail closed unless exactly one
# valid PostgreSQL service container ID is returned.
run_docker_discovery_output_case() {
  local output="$1"
  local expected_diagnostic="$2"
  local label="$3"
  local failure_events="$TEMP_DIR/docker-discovery-${label}-events.log"
  local failure_log="$TEMP_DIR/docker-discovery-${label}.log"
  local expected_failure_events="$TEMP_DIR/docker-discovery-${label}-expected.log"
  local failure_status=0

  : > "$failure_events"
  printf '10\n' > "$STATE_FILE"
  if PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$failure_events" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 MOCK_DOCKER_PS_EXIT=0 MOCK_DOCKER_PS_OUTPUT="$output" MOCK_READY_MODE=ready DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="$RESTORE_REQUIRED" BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" bash "$RESTORE_SCRIPT" > "$failure_log" 2>&1; then
    failure_status=0
  else
    failure_status=$?
  fi

  printf '%s\n' docker-ps > "$expected_failure_events"
  if [[ "$failure_status" -ne 1 ]] ||
    [[ "$(cat "$failure_events")" != "$(cat "$expected_failure_events")" ]] ||
    [[ "$(cat "$STATE_FILE")" != "10" ]] ||
    ! grep -Fqx "$expected_diagnostic" "$failure_log" ||
    grep -Eq 'pg-isready|docker-exec-reset|docker-restart|psql-' "$failure_events" ||
    grep -Fq "QA267 passed" "$failure_log" ||
    grep -Fq "postgres:postgres" "$failure_log"; then
    echo "ERROR: Docker discovery output case $label did not fail closed before readiness or configuration operations." >&2
    cat "$failure_events" >&2
    cat "$failure_log" >&2
    exit 1
  fi
}

run_docker_discovery_output_case \
  "" \
  "::error::Expected exactly one PostgreSQL 16 service container during restoration; found 0. No readiness, database, or configuration operation was attempted." \
  no-container
run_docker_discovery_output_case \
  $'0123456789ab\nabcdef012345\n' \
  "::error::Expected exactly one PostgreSQL 16 service container during restoration; found 2. No readiness, database, or configuration operation was attempted." \
  multiple-containers
run_docker_discovery_output_case \
  $'not-a-valid-container-id\n' \
  "::error::Docker returned an invalid PostgreSQL 16 service container ID during restoration; no readiness or configuration operation was attempted." \
  invalid-container-id

echo "QA464 Docker-discovery output guard passed: empty, multiple, and malformed container IDs were rejected before readiness, SQL, reset, or restart."

# QA465: enforce Docker container-ID length and lowercase hexadecimal boundaries.
# A 64-character full ID must be forwarded unchanged to exec and restart; IDs
# outside the accepted 12..64 lowercase-hex range must fail before readiness.
run_docker_container_id_boundary_case() {
  local container_id="$1"
  local expected_status="$2"
  local label="$3"
  local expected_diagnostic="$4"
  local boundary_events="$TEMP_DIR/docker-id-$label-events.log"
  local boundary_log="$TEMP_DIR/docker-id-$label.log"
  local expected_boundary_events="$TEMP_DIR/docker-id-$label-expected.log"
  local boundary_status=0

  : > "$boundary_events"
  printf '10\n' > "$STATE_FILE"
  if PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$boundary_events" MOCK_STATE_FILE="$STATE_FILE" MOCK_RESTORE_EXIT=0 MOCK_DOCKER_PS_EXIT=0 MOCK_DOCKER_PS_OUTPUT="$container_id" MOCK_DOCKER_EXPECTED_ID="$container_id" MOCK_READY_MODE=ready DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="$RESTORE_REQUIRED" BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" bash "$RESTORE_SCRIPT" > "$boundary_log" 2>&1; then
    boundary_status=0
  else
    boundary_status=$?
  fi

  if [[ "$expected_status" == "0" ]]; then
    printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database > "$expected_boundary_events"
    if [[ "$boundary_status" -ne 0 ]] ||
      [[ "$(cat "$boundary_events")" != "$(cat "$expected_boundary_events")" ]] ||
      [[ "$(cat "$STATE_FILE")" != "0" ]] ||
      ! grep -Fq "QA267 passed" "$boundary_log" ||
      grep -Fq "postgres:postgres" "$boundary_log"; then
      echo "ERROR: valid Docker container ID boundary case $label was not forwarded unchanged through restoration." >&2
      cat "$boundary_events" >&2
      cat "$boundary_log" >&2
      exit 1
    fi
  else
    printf '%s\n' docker-ps > "$expected_boundary_events"
    if [[ "$boundary_status" -ne "$expected_status" ]] ||
      [[ "$(cat "$boundary_events")" != "$(cat "$expected_boundary_events")" ]] ||
      [[ "$(cat "$STATE_FILE")" != "10" ]] ||
      ! grep -Fqx "$expected_diagnostic" "$boundary_log" ||
      grep -Fq "QA267 passed" "$boundary_log" ||
      grep -Fq "postgres:postgres" "$boundary_log"; then
      echo "ERROR: invalid Docker container ID boundary case $label did not fail closed." >&2
      cat "$boundary_events" >&2
      cat "$boundary_log" >&2
      exit 1
    fi
  fi
}

full_container_id='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
too_long_container_id="$full_container_id"'0'
invalid_id_diagnostic="::error::Docker returned an invalid PostgreSQL 16 service container ID during restoration; no readiness or configuration operation was attempted."
run_docker_container_id_boundary_case "$full_container_id" 0 valid-64 ""
run_docker_container_id_boundary_case "0123456789a" 1 too-short "$invalid_id_diagnostic"
run_docker_container_id_boundary_case "$too_long_container_id" 1 too-long "$invalid_id_diagnostic"
run_docker_container_id_boundary_case "ABCDEF012345" 1 uppercase "$invalid_id_diagnostic"
echo "QA465 Docker container-ID boundary guard passed: a 64-character lowercase hexadecimal ID was forwarded unchanged; 11-character, 65-character, and uppercase IDs were rejected before readiness or mutation."

# QA469: reject same-length Docker IDs containing non-hex characters or whitespace.
# These cases distinguish the hexadecimal allowlist from a length-only check.
run_docker_container_id_boundary_case "0123456789ag" 1 non-hex "$invalid_id_diagnostic"
run_docker_container_id_boundary_case "0123456789a " 1 trailing-space "$invalid_id_diagnostic"
echo "QA469 Docker container-ID character-class guard passed: same-length non-hex and whitespace IDs were rejected before readiness or mutation."




# QA467: missing required executables must fail before any Docker, readiness,
# or SQL operation. Build a minimal PATH for each case so command discovery,
# rather than a mock command failure, exercises the restore-script preflight.
run_missing_dependency_case() {
  local missing="$1"
  local dependency_bin="$TEMP_DIR/missing-dependency-$missing-bin"
  local dependency_events="$TEMP_DIR/missing-dependency-$missing-events.log"
  local dependency_log="$TEMP_DIR/missing-dependency-$missing.log"
  local dependency_status=0
  local expected_diagnostic="::error::psql, docker, and pg_isready are required to restore the disposable PostgreSQL service."

  mkdir -p "$dependency_bin"
  : > "$dependency_events"
  printf '10\n' > "$STATE_FILE"
  ln -s "$(command -v grep)" "$dependency_bin/grep"

  if [[ "$missing" != "psql" ]]; then
    ln -s "$MOCK_BIN/psql" "$dependency_bin/psql"
  fi
  if [[ "$missing" != "docker" ]]; then
    ln -s "$MOCK_BIN/docker" "$dependency_bin/docker"
  fi
  if [[ "$missing" != "pg_isready" ]]; then
    ln -s "$MOCK_BIN/pg_isready" "$dependency_bin/pg_isready"
  fi

  if PATH="$dependency_bin" \
    MOCK_EVENTS="$dependency_events" MOCK_STATE_FILE="$STATE_FILE" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    RESTORE_REQUIRED="$RESTORE_REQUIRED" \
    BASELINE_MAX_PREPARED_TRANSACTIONS="$BASELINE_MAX_PREPARED_TRANSACTIONS" \
    "$BASH" "$RESTORE_SCRIPT" > "$dependency_log" 2>&1; then
    dependency_status=0
  else
    dependency_status=$?
  fi

  if [[ "$dependency_status" -ne 127 ]] || \
    [[ "$(cat "$dependency_log")" != "$expected_diagnostic" ]] || \
    [[ -s "$dependency_events" ]] || \
    [[ "$(cat "$STATE_FILE")" != "10" ]] || \
    grep -Fq "QA267 passed" "$dependency_log" || \
    grep -Fq "postgres:postgres" "$dependency_log"; then
    echo "ERROR: missing $missing executable did not stop restoration at the dependency preflight." >&2
    cat "$dependency_events" >&2
    cat "$dependency_log" >&2
    exit 1
  fi
}

run_missing_dependency_case psql
run_missing_dependency_case docker
run_missing_dependency_case pg_isready
echo "QA467 dependency-preflight guard passed: missing psql, docker, or pg_isready returned 127 before any mock event, state change, or success marker."


# QA468: restoration must fail closed before Docker/readiness/SQL when the
# target URL contains control characters, is not the disposable loopback
# database, or the captured baseline is not the expected zero. A disabled
# restoration request must remain a harmless no-op without any other inputs.
run_restore_preflight_rejection_case() {
  local label="$1"
  local database_url="$2"
  local baseline="$3"
  local expected_diagnostic="$4"
  local preflight_events="$TEMP_DIR/restore-preflight-$label-events.log"
  local preflight_log="$TEMP_DIR/restore-preflight-$label.log"
  local preflight_status=0

  : > "$preflight_events"
  printf '10\n' > "$STATE_FILE"
  if PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$preflight_events" MOCK_STATE_FILE="$STATE_FILE" \
    DATABASE_URL="$database_url" RESTORE_REQUIRED=true \
    BASELINE_MAX_PREPARED_TRANSACTIONS="$baseline" \
    bash "$RESTORE_SCRIPT" > "$preflight_log" 2>&1; then
    preflight_status=0
  else
    preflight_status=$?
  fi

  if [[ "$preflight_status" -ne 2 ]] || \
    [[ "$(cat "$preflight_log")" != "$expected_diagnostic" ]] || \
    [[ -s "$preflight_events" ]] || \
    [[ "$(cat "$STATE_FILE")" != "10" ]] || \
    grep -Fq "QA267 passed" "$preflight_log" || \
    grep -Fq "postgres:postgres" "$preflight_log"; then
    echo "ERROR: restore preflight case $label did not reject the target before any operation." >&2
    cat "$preflight_events" >&2
    cat "$preflight_log" >&2
    exit 1
  fi
}

unsafe_target_diagnostic="::error::Refusing PostgreSQL configuration restoration: DATABASE_URL must target qima_test on loopback port 5432."
control_character_diagnostic="::error::Refusing PostgreSQL configuration restoration: DATABASE_URL must not contain control characters; no database operation was attempted."
baseline_diagnostic="::error::Expected the captured disposable-service baseline to be 0; refusing an unverified restoration target."

run_restore_preflight_rejection_case \
  external-host \
  "postgresql://postgres:postgres@db.example.invalid:5432/qima_test" \
  0 \
  "$unsafe_target_diagnostic"
run_restore_preflight_rejection_case \
  wrong-port \
  "postgresql://postgres:postgres@localhost:5433/qima_test" \
  0 \
  "$unsafe_target_diagnostic"
run_restore_preflight_rejection_case \
  wrong-database \
  "postgresql://postgres:postgres@localhost:5432/production" \
  0 \
  "$unsafe_target_diagnostic"
run_restore_preflight_rejection_case \
  control-character \
  $'postgresql://postgres:postgres@localhost:5432/qima_test\n' \
  0 \
  "$control_character_diagnostic"
run_restore_preflight_rejection_case \
  nonzero-baseline \
  "postgresql://postgres:postgres@localhost:5432/qima_test" \
  10 \
  "$baseline_diagnostic"

NOOP_BIN="$TEMP_DIR/restore-noop-bin"
NOOP_LOG="$TEMP_DIR/restore-noop.log"
mkdir -p "$NOOP_BIN"
if PATH="$NOOP_BIN" RESTORE_REQUIRED=false "$BASH" "$RESTORE_SCRIPT" > "$NOOP_LOG" 2>&1; then
  :
else
  noop_status=$?
  echo "ERROR: disabled restoration did not remain a successful no-op (exit $noop_status)." >&2
  cat "$NOOP_LOG" >&2
  exit 1
fi
if [[ "$(cat "$NOOP_LOG")" != "Prepared-transaction configuration was not changed; restoration is not required." ]] || \
  [[ "$(cat "$STATE_FILE")" != "10" ]] || \
  grep -Fq "postgres:postgres" "$NOOP_LOG"; then
  echo "ERROR: disabled restoration performed work or emitted an unexpected diagnostic." >&2
  cat "$NOOP_LOG" >&2
  exit 1
fi

echo "QA468 restore-target preflight guard passed: external host, wrong port/database, control characters, and nonzero baseline were rejected before Docker/readiness/SQL; RESTORE_REQUIRED=false remained a no-op."

# QA470: preserve every explicitly supported disposable loopback URL form.
# The mock psql asserts the exact URL passed by the restore script; no real
# PostgreSQL connection is made by these allowlist compatibility cases.
run_restore_allowed_target_case() {
  local label="$1"
  local database_url="$2"
  local allowed_events="$TEMP_DIR/restore-allowed-$label-events.log"
  local allowed_log="$TEMP_DIR/restore-allowed-$label.log"
  local allowed_status=0
  : > "$allowed_events"
  printf '10\n' > "$STATE_FILE"

  if PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$allowed_events" MOCK_STATE_FILE="$STATE_FILE" \
    MOCK_PSQL_EXPECTED_URL="$database_url" MOCK_RESTORE_EXIT=0 MOCK_READY_MODE=ready \
    DATABASE_URL="$database_url" RESTORE_REQUIRED=true \
    BASELINE_MAX_PREPARED_TRANSACTIONS=0 \
    bash "$RESTORE_SCRIPT" > "$allowed_log" 2>&1; then
    allowed_status=0
  else
    allowed_status=$?
  fi

  local expected_allowed_events
  expected_allowed_events="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database)"
  if [[ "$allowed_status" -ne 0 ]] || \
    [[ "$(cat "$allowed_events")" != "$expected_allowed_events" ]] || \
    [[ "$(cat "$STATE_FILE")" != "0" ]] || \
    ! grep -Fq "QA267 passed" "$allowed_log" || \
    grep -Fq "postgres:postgres" "$allowed_log"; then
    echo "ERROR: supported loopback URL case $label was not accepted through the mocked restoration path." >&2
    cat "$allowed_events" >&2
    cat "$allowed_log" >&2
    exit 1
  fi
}

run_restore_allowed_target_case postgresql-localhost "postgresql://postgres:postgres@localhost:5432/qima_test"
run_restore_allowed_target_case postgres-localhost "postgres://postgres:postgres@localhost:5432/qima_test"
run_restore_allowed_target_case postgresql-ipv4 "postgresql://postgres:postgres@127.0.0.1:5432/qima_test"
run_restore_allowed_target_case postgres-ipv4 "postgres://postgres:postgres@127.0.0.1:5432/qima_test"
run_restore_allowed_target_case postgresql-ipv6 "postgresql://postgres:postgres@[::1]:5432/qima_test"
run_restore_allowed_target_case postgres-ipv6 "postgres://postgres:postgres@[::1]:5432/qima_test"

echo "QA470 supported-loopback URL allowlist passed: postgres/postgresql schemes with localhost, IPv4 loopback, and IPv6 loopback completed the mocked restoration sequence; psql received each URL unchanged."

