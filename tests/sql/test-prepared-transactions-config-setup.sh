#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_SCRIPT="$ROOT/tests/sql/enable-prepared-transactions-config.sh"
RESTORE_SCRIPT="$ROOT/tests/sql/restore-prepared-transactions-config.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/mock-bin"
EVENTS="$TEMP_DIR/events.log"
OUTPUT="$TEMP_DIR/output.log"
GITHUB_OUTPUT_FILE="$TEMP_DIR/github-output"
mkdir -p "$MOCK_BIN"
: > "$GITHUB_OUTPUT_FILE"

cat > "$MOCK_BIN/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  ps)
    ps_output="${MOCK_PS_OUTPUT-postgres-container}"
    if [[ -n "$ps_output" ]]; then
      printf '%s\n' "$ps_output"
    fi
    printf '%s\n' docker-ps >> "$MOCK_EVENTS"
    exit "${MOCK_DOCKER_PS_STATUS:-0}"
    ;;
  exec)
    if [[ "$*" != *"ALTER SYSTEM SET max_prepared_transactions = '10'"* ]]; then
      echo "Unexpected docker exec command." >&2
      exit 90
    fi
    if ! grep -Fxq 'baseline=0' "$MOCK_GITHUB_OUTPUT" ||
       ! grep -Fxq 'restore_required=true' "$MOCK_GITHUB_OUTPUT"; then
      echo "Restoration intent was not recorded before ALTER SYSTEM SET." >&2
      exit 91
    fi
    printf '%s\n' docker-exec-set >> "$MOCK_EVENTS"
    exit "${MOCK_DOCKER_EXEC_STATUS:-0}"
    ;;
  restart)
    if ! grep -Fxq 'restore_required=true' "$MOCK_GITHUB_OUTPUT"; then
      echo "Restoration intent was lost before restart." >&2
      exit 92
    fi
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
if [[ "$*" == *"SHOW max_prepared_transactions"* ]]; then
  count_file="${MOCK_EVENTS}.show-count"
  show_count=0
  if [[ -f "$count_file" ]]; then
    read -r show_count < "$count_file"
  fi
  show_count=$((show_count + 1))
  printf '%s\n' "$show_count" > "$count_file"
  printf 'psql-show-%s\n' "$show_count" >> "$MOCK_EVENTS"
  if (( show_count == 1 )) && [[ "${MOCK_INITIAL_SHOW_STATUS:-0}" != "0" ]]; then
    exit "$MOCK_INITIAL_SHOW_STATUS"
  fi
  if (( show_count > 1 )) && [[ "${MOCK_SHOW_STATUS:-0}" != "0" ]]; then
    exit "$MOCK_SHOW_STATUS"
  fi
  if (( show_count == 1 )); then
    printf '%s\n' "${MOCK_INITIAL_CONFIGURED_VALUE:-0}"
  else
    printf '%s\n' "${MOCK_CONFIGURED_VALUE:-10}"
  fi
  exit 0
fi
echo "Unexpected psql invocation." >&2
exit 90
PSQL
chmod +x "$MOCK_BIN/psql"

cat > "$MOCK_BIN/pg_isready" <<'READY'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' pg-isready >> "$MOCK_EVENTS"
exit "${MOCK_READY_STATUS:-0}"
READY
chmod +x "$MOCK_BIN/pg_isready"

cat > "$MOCK_BIN/sleep" <<'SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep-%s\n' "$*" >> "$MOCK_EVENTS"
exit 0
SLEEP
chmod +x "$MOCK_BIN/sleep"

run_setup() {
  local expected_status="$1"
  shift
  : > "$EVENTS"
  : > "$GITHUB_OUTPUT_FILE"
  rm -f "$EVENTS.show-count"
  set +e
  env PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$EVENTS" \
    MOCK_GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE" \
    "$@" bash "$SETUP_SCRIPT" > "$OUTPUT" 2>&1
  local actual_status=$?
  set -e
  if [[ "$actual_status" -ne "$expected_status" ]]; then
    echo "ERROR: expected setup exit $expected_status, received $actual_status." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
}

assert_restore_intent() {
  local expected
  expected="$(printf 'baseline=0\nrestore_required=true')"
  local actual
  actual="$(cat "$GITHUB_OUTPUT_FILE")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: restoration intent was not persisted exactly before setup mutation." >&2
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

# Success: baseline is captured, restoration intent is persisted, then SET/restart/verify run.
run_setup 0
assert_restore_intent
expected="$(printf '%s\n' docker-ps psql-show-1 docker-exec-set docker-restart pg-isready psql-show-2)"
actual="$(cat "$EVENTS")"
if [[ "$actual" != "$expected" ]] || ! grep -Fq 'restarted with max_prepared_transactions=10' "$OUTPUT"; then
  echo "ERROR: successful setup did not follow the expected order." >&2
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA275: failure to read the initial baseline must stop before publishing
# restoration intent or performing any configuration mutation.
run_setup 50 env MOCK_INITIAL_SHOW_STATUS=50
expected=$'docker-ps\npsql-show-1'
if [[ "$(cat "$EVENTS")" != "$expected" ]] ||
  [[ -s "$GITHUB_OUTPUT_FILE" ]] ||
  ! grep -Fq "Could not capture the disposable PostgreSQL baseline (psql exit 50)" "$OUTPUT" ||
  grep -Fq "docker-exec-set" "$EVENTS" ||
  grep -Fq "docker-restart" "$EVENTS"; then
  echo "ERROR: an unreadable initial PostgreSQL baseline did not stop before marker publication and mutation." >&2
  cat "$EVENTS" >&2
  cat "$GITHUB_OUTPUT_FILE" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The workflow's always() restoration step receives an empty marker after the
# initial SHOW failure and must therefore be a harmless no-op.
: > "$EVENTS"
: > "$OUTPUT"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="" BASELINE_MAX_PREPARED_TRANSACTIONS="" bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
restore_status=$?
set -e
if [[ "$restore_status" -ne 0 ]] ||
  [[ -s "$EVENTS" ]] ||
  ! grep -Fq "configuration was not changed; restoration is not required" "$OUTPUT"; then
  echo "ERROR: always() restoration did not safely no-op when the initial baseline could not be read." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA276: a readable but non-pristine baseline must be rejected before the
# restoration marker is published or any PostgreSQL configuration is changed.
run_setup 1 env MOCK_INITIAL_CONFIGURED_VALUE=5
expected="$(printf '%s\n' docker-ps psql-show-1)"
if [[ "$(cat "$EVENTS")" != "$expected" ]] ||
  [[ -s "$GITHUB_OUTPUT_FILE" ]] ||
  ! grep -Fq "Expected the pristine disposable PostgreSQL baseline to be 0; found 5" "$OUTPUT" ||
  grep -Fq "docker-exec-set" "$EVENTS" ||
  grep -Fq "docker-restart" "$EVENTS"; then
  echo "ERROR: a non-zero initial PostgreSQL baseline was not rejected before marker publication and mutation." >&2
  cat "$EVENTS" >&2
  cat "$GITHUB_OUTPUT_FILE" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The workflow's always() cleanup must remain a no-op when the baseline was
# readable but did not match the pristine disposable-service contract.
: > "$EVENTS"
: > "$OUTPUT"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="" BASELINE_MAX_PREPARED_TRANSACTIONS="" bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
restore_status=$?
set -e
if [[ "$restore_status" -ne 0 ]] ||
  [[ -s "$EVENTS" ]] ||
  ! grep -Fq "configuration was not changed; restoration is not required" "$OUTPUT"; then
  echo "ERROR: always() restoration did not safely no-op after rejecting a non-pristine baseline." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA277: if the GitHub Actions output file cannot persist the restoration intent,
# setup must stop before ALTER SYSTEM SET/restart, and the workflow's always()
# restoration step must remain a no-op. The BASH_ENV hook injects a controlled
# printf failure at the marker-write boundary; it does not emulate a filesystem
# permission or storage failure.
cat > "$TEMP_DIR/fail-marker-write.bash" <<'BASH_ENV'
printf() {
  case "$1" in
    'baseline=%s\nrestore_required=true\n')
      builtin printf '%s\n' marker-write-failed >> "$MOCK_EVENTS"
      return 52
      ;;
  esac
  builtin printf "$@"
}
BASH_ENV

run_setup 1 env BASH_ENV="$TEMP_DIR/fail-marker-write.bash"
expected=$'docker-ps\npsql-show-1\nmarker-write-failed'
if [[ "$(cat "$EVENTS")" != "$expected" ]] ||
  [[ -s "$GITHUB_OUTPUT_FILE" ]] ||
  ! grep -Fq "Could not persist PostgreSQL restoration intent; no configuration change was attempted." "$OUTPUT" ||
  grep -Fq "docker-exec-set" "$EVENTS" ||
  grep -Fq "docker-restart" "$EVENTS"; then
  echo "ERROR: failed GITHUB_OUTPUT marker persistence did not stop setup before PostgreSQL mutation." >&2
  cat "$EVENTS" >&2
  cat "$GITHUB_OUTPUT_FILE" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The always() cleanup step must be a no-op because setup never persisted a marker
# and therefore never started a configuration mutation.
: > "$EVENTS"
: > "$OUTPUT"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="" BASELINE_MAX_PREPARED_TRANSACTIONS="" bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
restore_status=$?
set -e
if [[ "$restore_status" -ne 0 ]] ||
  [[ -s "$EVENTS" ]] ||
  ! grep -Fq "configuration was not changed; restoration is not required" "$OUTPUT"; then
  echo "ERROR: always() restoration did not no-op after marker persistence failed before mutation." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# QA278: exercise a real operating-system permission denial on GITHUB_OUTPUT.
# GitHub-hosted Ubuntu jobs normally run unprivileged. If invoked as root, use
# the dedicated nobody account so chmod 0444 produces a genuine EACCES.
qa278_dir="$TEMP_DIR/qa278-permission"
mkdir -p "$qa278_dir"
chmod 755 "$TEMP_DIR" "$MOCK_BIN" "$qa278_dir"
qa278_events="$qa278_dir/events.log"
qa278_show_count="$qa278_events.show-count"
qa278_output="$qa278_dir/github-output"
qa278_log="$qa278_dir/setup.log"
: > "$qa278_events"
echo 0 > "$qa278_show_count"
: > "$qa278_output"

if [[ "$(id -u)" -eq 0 ]]; then
  if ! command -v runuser >/dev/null 2>&1 || ! getent passwd nobody >/dev/null 2>&1; then
    echo "ERROR: QA278 requires runuser and the nobody account when the test process is root." >&2
    exit 1
  fi
  chown nobody "$qa278_events" "$qa278_show_count" "$qa278_output"
  chmod 444 "$qa278_output"
  set +e
  runuser -u nobody -- env \
    PATH="$MOCK_BIN:$PATH" \
    LC_ALL=C \
    MOCK_EVENTS="$qa278_events" \
    MOCK_GITHUB_OUTPUT="$qa278_output" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    GITHUB_OUTPUT="$qa278_output" \
    bash "$SETUP_SCRIPT" > "$qa278_log" 2>&1
  qa278_status=$?
  set -e
else
  chmod 444 "$qa278_output"
  set +e
  env PATH="$MOCK_BIN:$PATH" \
    LC_ALL=C \
    MOCK_EVENTS="$qa278_events" \
    MOCK_GITHUB_OUTPUT="$qa278_output" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    GITHUB_OUTPUT="$qa278_output" \
    bash "$SETUP_SCRIPT" > "$qa278_log" 2>&1
  qa278_status=$?
  set -e
fi

# Restore normal mode for the harness cleanup trap and subsequent assertions.
chmod 644 "$qa278_output"
qa278_event_lines="$(wc -l < "$qa278_events")"
qa278_first_event="$(sed -n '1p' "$qa278_events")"
qa278_second_event="$(sed -n '2p' "$qa278_events")"
if [[ "$qa278_status" -ne 1 ]] ||
  [[ "$qa278_event_lines" -ne 2 ]] ||
  [[ "$qa278_first_event" != "docker-ps" ]] ||
  [[ "$qa278_second_event" != "psql-show-1" ]] ||
  [[ -s "$qa278_output" ]] ||
  ! grep -Fq "Permission denied" "$qa278_log" ||
  ! grep -Fq "Could not persist PostgreSQL restoration intent; no configuration change was attempted." "$qa278_log" ||
  grep -Fq "docker-exec-set" "$qa278_events" ||
  grep -Fq "docker-restart" "$qa278_events"; then
  echo "ERROR: a real GITHUB_OUTPUT filesystem permission denial did not stop setup before PostgreSQL mutation." >&2
  echo "status=$qa278_status" >&2
  cat "$qa278_events" >&2
  cat "$qa278_output" >&2
  cat "$qa278_log" >&2
  exit 1
fi

# The workflow's always() cleanup must still no-op after the real permission
# denial because no restoration marker was persisted and no mutation began.
: > "$EVENTS"
: > "$OUTPUT"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_EVENTS="$EVENTS" DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" RESTORE_REQUIRED="" BASELINE_MAX_PREPARED_TRANSACTIONS="" bash "$RESTORE_SCRIPT" > "$OUTPUT" 2>&1
restore_status=$?
set -e
if [[ "$restore_status" -ne 0 ]] ||
  [[ -s "$EVENTS" ]] ||
  ! grep -Fq "configuration was not changed; restoration is not required" "$OUTPUT"; then
  echo "ERROR: always() restoration did not safely no-op after the real GITHUB_OUTPUT permission denial." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A docker ps command that emits partial output and then fails must not allow
# that partial container ID to be used for any PostgreSQL operation.
run_setup 55 env MOCK_PS_OUTPUT=partial-container MOCK_DOCKER_PS_STATUS=55
if [[ "$(cat "$EVENTS")" != "docker-ps" ]] || [[ -s "$GITHUB_OUTPUT_FILE" ]] ||
  ! grep -Fq "docker ps exit 55" "$OUTPUT" ||
  grep -Fq "psql-show" "$EVENTS"; then
  echo "ERROR: partial docker ps output was used after discovery failed." >&2
  cat "$EVENTS" >&2
  cat "$GITHUB_OUTPUT_FILE" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Empty successful discovery must fail before reading the database baseline.
run_setup 1 env MOCK_PS_OUTPUT=
if [[ "$(cat "$EVENTS")" != "docker-ps" ]] || [[ -s "$GITHUB_OUTPUT_FILE" ]] ||
  ! grep -Fq "found 0" "$OUTPUT"; then
  echo "ERROR: an empty PostgreSQL container result was not rejected before database access." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Multiple discovered containers are ambiguous and must also fail before mutation.
run_setup 1 env MOCK_PS_OUTPUT=$'one\ntwo'
if [[ "$(cat "$EVENTS")" != "docker-ps" ]] || [[ -s "$GITHUB_OUTPUT_FILE" ]] ||
  ! grep -Fq "found 2" "$OUTPUT"; then
  echo "ERROR: ambiguous PostgreSQL container discovery was not rejected before database access." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A failed ALTER SYSTEM SET must leave restore_required=true in GITHUB_OUTPUT.
run_setup 47 env MOCK_DOCKER_EXEC_STATUS=47
assert_restore_intent
expected="$(printf '%s\n' docker-ps psql-show-1 docker-exec-set)"
if [[ "$(cat "$EVENTS")" != "$expected" ]] ||
   ! grep -Fq 'restoration remains required' "$OUTPUT"; then
  echo "ERROR: SET failure lost the cleanup marker or continued to restart." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A failed restart must also preserve the cleanup marker.
run_setup 48 env MOCK_DOCKER_RESTART_STATUS=48
assert_restore_intent
expected="$(printf '%s\n' docker-ps psql-show-1 docker-exec-set docker-restart)"
if [[ "$(cat "$EVENTS")" != "$expected" ]] ||
   ! grep -Fq 'setup restart failed' "$OUTPUT"; then
  echo "ERROR: restart failure lost the cleanup marker or continued to readiness checks." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# A post-restart SHOW failure must not clear the cleanup marker.
run_setup 49 env MOCK_SHOW_STATUS=49
assert_restore_intent
expected="$(printf '%s\n' docker-ps psql-show-1 docker-exec-set docker-restart pg-isready psql-show-2)"
if [[ "$(cat "$EVENTS")" != "$expected" ]] ||
   ! grep -Fq 'restoration remains required' "$OUTPUT"; then
  echo "ERROR: SHOW failure lost the cleanup marker or claimed setup success." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# If PostgreSQL never becomes ready, setup fails after publishing the cleanup marker.
run_setup 1 env MOCK_READY_STATUS=1
assert_restore_intent
if [[ "$(grep -Fxc 'pg-isready' "$EVENTS" || true)" -ne 60 ]] ||
   [[ "$(grep -Fxc 'sleep-1' "$EVENTS" || true)" -ne 60 ]] ||
   grep -Fq 'restarted with max_prepared_transactions=10' "$OUTPUT"; then
  echo "ERROR: readiness exhaustion was not bounded or falsely reported setup success." >&2
  cat "$EVENTS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The workflow must run the extracted setup script and always invoke restoration.
grep -Fq 'run: bash tests/sql/enable-prepared-transactions-config.sh' "$WORKFLOW"
grep -Fq 'run: bash tests/sql/test-prepared-transactions-config-setup.sh' "$WORKFLOW"
restore_block="$(awk '/name: Restore prepared-transaction configuration and verify disposable resources/{show=1} show{print} show && /run: bash tests\/sql\/restore-prepared-transactions-config.sh/{exit}' "$WORKFLOW")"
grep -Fq 'if: always()' <<< "$restore_block"
grep -Fq 'RESTORE_REQUIRED: ${{ steps.enable_prepared.outputs.restore_required }}' <<< "$restore_block"
grep -Fq 'BASELINE_MAX_PREPARED_TRANSACTIONS: ${{ steps.enable_prepared.outputs.baseline }}' <<< "$restore_block"

echo "Prepared-transaction setup regression passed: docker ps partial-output failures preserve the exit code; zero/multiple container discovery fails before database access; restoration intent is persisted before mutation; SET, restart, post-restart SHOW and readiness failures preserve the cleanup marker; retry exhaustion is bounded; workflow invokes setup and always() restoration."
