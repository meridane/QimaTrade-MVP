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
    ps_output="${MOCK_PS_OUTPUT-${MOCK_CONTAINERS:-postgres-container}}"
    if [[ -n "$ps_output" ]]; then
      printf '%s\n' "$ps_output"
    fi
    printf '%s\n' docker-ps >> "$MOCK_EVENTS"
    exit "${MOCK_DOCKER_PS_STATUS:-0}"
    ;;
  exec)
    if [[ "$*" != *"ALTER SYSTEM RESET max_prepared_transactions"* ]]; then
      echo "Unexpected docker exec command." >&2
      exit 90
    fi
    printf '%s\n' docker-exec-reset >> "$MOCK_EVENTS"
    exit "${MOCK_DOCKER_EXEC_STATUS:-0}"
    ;;
  restart)
    printf '%s\n' docker-restart >> "$MOCK_EVENTS"
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
    printf '%s\n' psql-show >> "$MOCK_EVENTS"
    if [[ "${MOCK_SHOW_STATUS:-0}" != "0" ]]; then
      exit "$MOCK_SHOW_STATUS"
    fi
    show_count_file="${MOCK_EVENTS}.show-count"
    show_count=0
    if [[ -f "$show_count_file" ]]; then
      read -r show_count < "$show_count_file"
    fi
    show_count=$((show_count + 1))
    printf '%s\n' "$show_count" > "$show_count_file"
    show_wrong_first_calls="${MOCK_SHOW_WRONG_FIRST_CALLS:-0}"
    if [[ "$show_wrong_first_calls" =~ ^[0-9]+$ ]] &&
      (( show_count <= show_wrong_first_calls )); then
      printf '%s\n' "${MOCK_SHOW_WRONG_VALUE:-10}"
    else
      printf '%s\n' "${MOCK_RESTORED_VALUE:-0}"
    fi
    ;;
  *"pg_prepared_xacts"*)
    printf '%s\n' psql-prepared >> "$MOCK_EVENTS"
    if [[ "${MOCK_PREPARED_STATUS:-0}" != "0" ]]; then
      exit "$MOCK_PREPARED_STATUS"
    fi
    printf '%s\n' "${MOCK_PREPARED_COUNT:-0}"
    ;;
  *"pg_database"*)
    printf '%s\n' psql-database >> "$MOCK_EVENTS"
    if [[ "${MOCK_DATABASE_STATUS:-0}" != "0" ]]; then
      exit "$MOCK_DATABASE_STATUS"
    fi
    printf '%s\n' "${MOCK_DATABASE_COUNT:-0}"
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
count_file="${MOCK_EVENTS}.ready-count"
ready_count=0
if [[ -f "$count_file" ]]; then
  read -r ready_count < "$count_file"
fi
ready_count=$((ready_count + 1))
printf '%s\n' "$ready_count" > "$count_file"
printf '%s\n' pg-isready >> "$MOCK_EVENTS"
if [[ -n "${MOCK_READY_FAIL_CALLS:-}" ]]; then
  case ",${MOCK_READY_FAIL_CALLS}," in
    *",${ready_count},"*) exit "${MOCK_READY_FAILURE_STATUS:-1}" ;;
  esac
fi
if [[ "${MOCK_READY_FAIL_FROM_CALL:-0}" =~ ^[0-9]+$ ]] &&
  (( ${MOCK_READY_FAIL_FROM_CALL:-0} > 0 && ready_count >= MOCK_READY_FAIL_FROM_CALL )); then
  exit "${MOCK_READY_FAILURE_STATUS:-1}"
fi
exit "${MOCK_READY_STATUS:-0}"
READY
chmod +x "$MOCK_BIN/pg_isready"

cat > "$MOCK_BIN/sleep" <<'SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep-%s\n' "$*" >> "$MOCK_EVENTS"
exit "${MOCK_SLEEP_STATUS:-0}"
SLEEP
chmod +x "$MOCK_BIN/sleep"

run_restore() {
  local expected_status="$1"
  shift
  : > "$EVENTS"
  rm -f "$EVENTS.ready-count" "$EVENTS.show-count"
  set +e
  PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$EVENTS" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    RESTORE_REQUIRED=true \
    BASELINE_MAX_PREPARED_TRANSACTIONS=0 \
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
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] || ! grep -Fq "returned to baseline 0" "$OUTPUT"; then
  echo "ERROR: restoration did not follow the expected reset/restart/verification sequence." >&2
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# If setup never recorded a change, the always() restoration step must be a no-op.
: > "$EVENTS"
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" RESTORE_REQUIRED=false \
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
if [[ -s "$EVENTS" ]]; then
  echo "ERROR: restoration performed operations when no configuration change was recorded." >&2
  cat "$EVENTS" >&2
  exit 1
fi

# Remote URLs are rejected before docker or psql can be invoked.
: > "$EVENTS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" \
  DATABASE_URL="postgresql://postgres:postgres@db.example:5432/qima_test" \
  RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=0 \
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
unsafe_status=$?
set -e
if [[ "$unsafe_status" -ne 2 || -s "$EVENTS" ]]; then
  echo "ERROR: remote DATABASE_URL was not rejected before external commands." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A docker ps command that emits partial output and then fails must not allow
# restoration to act on that partial container ID or even probe PostgreSQL.
run_restore 54 env MOCK_PS_OUTPUT=partial-container MOCK_DOCKER_PS_STATUS=54
if [[ "$(cat "$EVENTS")" != "docker-ps" ]] ||
  ! grep -Fq "docker ps exit 54" "$OUTPUT" ||
  grep -Fq "pg-isready" "$EVENTS" ||
  grep -Fq "docker-exec-reset" "$EVENTS"; then
  echo "ERROR: restoration used partial docker ps output after discovery failed." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Empty successful discovery must fail before readiness or configuration operations.
run_restore 1 env MOCK_PS_OUTPUT=
if [[ "$(cat "$EVENTS")" != "docker-ps" ]] ||
  ! grep -Fq "found 0" "$OUTPUT" ||
  grep -Fq "pg-isready" "$EVENTS"; then
  echo "ERROR: empty PostgreSQL container discovery was not rejected before restoration." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Multiple service containers must fail closed before ALTER SYSTEM RESET.
: > "$EVENTS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" MOCK_CONTAINERS=$'one\ntwo' \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=0 \
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

# A leftover disposable database must also fail the post-restore verification.
run_restore 1 env MOCK_DATABASE_COUNT=1
if ! grep -Fq "disposable QA266 resources remain" "$OUTPUT"; then
  echo "ERROR: leftover disposable database was not reported." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A failed ALTER SYSTEM RESET must stop before restart or postcondition checks,
# report the command failure, and preserve its exit status.
run_restore 42 env MOCK_DOCKER_EXEC_STATUS=42
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] || ! grep -Fq "ALTER SYSTEM RESET max_prepared_transactions failed (docker exec exit 42)" "$OUTPUT"; then
  echo "ERROR: RESET failure was not reported precisely or the workflow continued." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A failed container restart must stop before readiness and configuration checks,
# report that restoration is unconfirmed, and preserve the restart exit status.
run_restore 43 env MOCK_DOCKER_RESTART_STATUS=43
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] || ! grep -Fq "PostgreSQL service restart failed (docker restart exit 43)" "$OUTPUT"; then
  echo "ERROR: restart failure was not reported precisely or the workflow claimed verification." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA269-A: PostgreSQL remains unavailable after the successful restart command.
# The first readiness probe is the pre-reset check; every probe after restart fails.
# The sleep stub makes all 60 retry attempts deterministic and fast.
run_restore 1 env MOCK_READY_FAIL_FROM_CALL=2
if ! grep -Fq "PostgreSQL did not return to max_prepared_transactions=0" "$OUTPUT" ||
  grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "pg-isready" "$EVENTS" || true)" -ne 61 ]] ||
  [[ "$(grep -Fxc "sleep-1" "$EVENTS" || true)" -ne 60 ]] ||
  [[ "$(grep -Fxc "psql-show" "$EVENTS" || true)" -ne 0 ]] ||
  [[ "$(grep -Fxc "psql-prepared" "$EVENTS" || true)" -ne 0 ]] ||
  [[ "$(grep -Fxc "psql-database" "$EVENTS" || true)" -ne 0 ]]; then
  echo "ERROR: unavailable PostgreSQL after restart was not rejected without claiming restoration." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA269-B: PostgreSQL is reachable after restart but still reports the temporary value.
# The runner must exhaust the bounded verification loop and must not check residual
# resources or print the restoration success message.
run_restore 1 env MOCK_RESTORED_VALUE=10
if ! grep -Fq "PostgreSQL did not return to max_prepared_transactions=0" "$OUTPUT" ||
  grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "pg-isready" "$EVENTS" || true)" -ne 61 ]] ||
  [[ "$(grep -Fxc "sleep-1" "$EVENTS" || true)" -ne 60 ]] ||
  [[ "$(grep -Fxc "psql-show" "$EVENTS" || true)" -ne 60 ]] ||
  [[ "$(grep -Fxc "psql-prepared" "$EVENTS" || true)" -ne 0 ]] ||
  [[ "$(grep -Fxc "psql-database" "$EVENTS" || true)" -ne 0 ]]; then
  echo "ERROR: an incorrect post-restart configuration was accepted as restored." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA270: PostgreSQL is reachable after restart, but the SHOW query itself fails.
# Preserve the psql exit status and stop before residual-resource checks or success output.
run_restore 44 env MOCK_SHOW_STATUS=44
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] ||
  ! grep -Fq "Could not read max_prepared_transactions after PostgreSQL restart (psql exit 44)" "$OUTPUT" ||
  grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "psql-prepared" "$EVENTS" || true)" -ne 0 ]] ||
  [[ "$(grep -Fxc "psql-database" "$EVENTS" || true)" -ne 0 ]] ||
  [[ "$(grep -Fxc "sleep-1" "$EVENTS" || true)" -ne 0 ]]; then
  echo "ERROR: a failed post-restart SHOW query was not reported without claiming restoration." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA271-A: the prepared-transaction postcondition query fails.
# Preserve its psql exit status and do not run the database query or claim success.
run_restore 45 env MOCK_PREPARED_STATUS=45
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] ||
  ! grep -Fq "Could not verify QA266 prepared-transaction cleanup (psql exit 45)" "$OUTPUT" ||
  grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "psql-database" "$EVENTS" || true)" -ne 0 ]]; then
  echo "ERROR: a failed prepared-transaction postcondition query was not reported fail-closed." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA271-B: the disposable-database postcondition query fails.
# Preserve its psql exit status and do not claim that cleanup was verified.
run_restore 46 env MOCK_DATABASE_STATUS=46
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] ||
  ! grep -Fq "Could not verify disposable migration database cleanup (psql exit 46)" "$OUTPUT" ||
  grep -Fq "QA267 passed" "$OUTPUT"; then
  echo "ERROR: a failed disposable-database postcondition query was not reported fail-closed." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA272-A: the service is unavailable during the first two pre-reset readiness probes,
# then becomes ready. The bounded retry loop must recover and complete restoration.
run_restore 0 env MOCK_READY_FAIL_CALLS=1,2
expected="$(printf '%s\n' docker-ps pg-isready sleep-1 pg-isready sleep-1 pg-isready docker-exec-reset docker-restart pg-isready psql-show psql-prepared psql-database)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] ||
  ! grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "pg-isready" "$EVENTS" || true)" -ne 4 ]] ||
  [[ "$(grep -Fxc "sleep-1" "$EVENTS" || true)" -ne 2 ]]; then
  echo "ERROR: transient pre-reset PostgreSQL unavailability did not recover within the retry loop." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA272-B: PostgreSQL becomes ready only after two post-restart retries.
# The initial pre-reset probe succeeds; post-restart probes 2 and 3 fail, then probe 4 succeeds.
run_restore 0 env MOCK_READY_FAIL_CALLS=2,3
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready sleep-1 pg-isready sleep-1 pg-isready psql-show psql-prepared psql-database)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] ||
  ! grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "pg-isready" "$EVENTS" || true)" -ne 4 ]] ||
  [[ "$(grep -Fxc "sleep-1" "$EVENTS" || true)" -ne 2 ]]; then
  echo "ERROR: transient post-restart PostgreSQL unavailability did not recover within the retry loop." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA272-C: PostgreSQL is ready, but SHOW reports the temporary value for two polls
# before converging to the captured baseline. The runner must retry and verify resources only
# after the expected value is observed.
run_restore 0 env MOCK_SHOW_WRONG_FIRST_CALLS=2 MOCK_SHOW_WRONG_VALUE=10 MOCK_RESTORED_VALUE=0
expected="$(printf '%s\n' docker-ps pg-isready docker-exec-reset docker-restart pg-isready psql-show sleep-1 pg-isready psql-show sleep-1 pg-isready psql-show psql-prepared psql-database)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] ||
  ! grep -Fq "QA267 passed" "$OUTPUT" ||
  [[ "$(grep -Fxc "pg-isready" "$EVENTS" || true)" -ne 4 ]] ||
  [[ "$(grep -Fxc "psql-show" "$EVENTS" || true)" -ne 3 ]] ||
  [[ "$(grep -Fxc "sleep-1" "$EVENTS" || true)" -ne 2 ]]; then
  echo "ERROR: transient post-restart configuration mismatch did not converge within the retry loop." >&2
  printf 'Expected events:\n%s\nActual events:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The original baseline is explicit; do not reset against an unrecognized value.
: > "$EVENTS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=10 \
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
baseline_status=$?
set -e
if [[ "$baseline_status" -ne 2 || -s "$EVENTS" ]]; then
  echo "ERROR: an unapproved baseline was not rejected before external commands." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA280: RESTORE_REQUIRED=true without a captured baseline must fail before Docker,
# readiness probes, or any database/configuration operation.
: > "$EVENTS"
set +e
env -u BASELINE_MAX_PREPARED_TRANSACTIONS \
  PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" \
  DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
  RESTORE_REQUIRED=true \
  bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
missing_baseline_status=$?
set -e
if [[ "$missing_baseline_status" -ne 2 || -s "$EVENTS" ]] ||
  ! grep -Fq "Expected the captured disposable-service baseline to be 0" "$OUTPUT" ||
  grep -Fq "QA267 passed" "$OUTPUT"; then
  echo "ERROR: restoration did not reject a missing baseline before external commands." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA281: only the exact captured baseline "0" is accepted. Reject empty,
# alternate numeric, signed, and whitespace-padded values before any external command.
for invalid_baseline in "" "10" "00" "-1" " 0" "0 "; do
  run_restore 2 env "BASELINE_MAX_PREPARED_TRANSACTIONS=$invalid_baseline"
  if [[ -s "$EVENTS" ]] ||
    ! grep -Fq "Expected the captured disposable-service baseline to be 0" "$OUTPUT" ||
    grep -Fq "QA267 passed" "$OUTPUT"; then
    echo "ERROR: noncanonical baseline was not rejected before external commands (value: [$invalid_baseline])." >&2
    cat "$EVENTS" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

if grep -Fq "postgres:postgres" "$OUTPUT"; then
  echo "ERROR: restoration output exposed disposable connection credentials." >&2
  exit 1
fi

echo "Prepared-transaction configuration restoration regression passed: docker ps partial-output failures preserve the exit code; zero/multiple container discovery fails before readiness or RESET; reset/restart order, explicit RESET and restart failure handling with original exit codes, post-restart SHOW and residual-resource query failure propagation, bounded transient recovery and configuration convergence, permanent unavailability and wrong-value rejection, no-op behavior, loopback URL guard, single-container guard, missing-baseline, QA281 noncanonical-baseline matrix, and unapproved-baseline guards, and residual-resource detection."
