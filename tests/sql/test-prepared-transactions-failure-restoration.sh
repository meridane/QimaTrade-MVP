#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_SCRIPT="$ROOT/tests/sql/enable-prepared-transactions-config.sh"
RESTORE_SCRIPT="$ROOT/tests/sql/restore-prepared-transactions-config.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "\${1-}" in
  ps)
    printf '%s\n' postgres-container
    printf '%s\n' docker-ps >> "$MOCK_EVENTS"
    ;;
  exec)
    if [[ "$*" == *"ALTER SYSTEM SET max_prepared_transactions = '10'"* ]]; then
      if ! grep -Fxq 'baseline=0' "$MOCK_GITHUB_OUTPUT" ||
         ! grep -Fxq 'restore_required=true' "$MOCK_GITHUB_OUTPUT"; then
        echo "Restoration intent was not persisted before SET." >&2
        exit 91
      fi
      printf '10\n' > "$MOCK_STATE_FILE"
      printf '%s\n' docker-exec-set >> "$MOCK_EVENTS"
      exit "\${MOCK_SET_STATUS:-0}"
    fi
    if [[ "$*" == *"ALTER SYSTEM RESET max_prepared_transactions"* ]]; then
      if [[ "\${RESTORE_REQUIRED-}" != "true" ||
            "\${BASELINE_MAX_PREPARED_TRANSACTIONS-}" != "0" ]]; then
        echo "RESET was invoked without the exact restoration marker and baseline." >&2
        exit 92
      fi
      printf '0\n' > "$MOCK_STATE_FILE"
      printf '%s\n' docker-exec-reset >> "$MOCK_EVENTS"
      exit "\${MOCK_RESET_STATUS:-0}"
    fi
    echo "Unexpected docker exec command." >&2
    exit 90
    ;;
  restart)
    state="$(cat "$MOCK_STATE_FILE")"
    printf '%s\n' docker-restart >> "$MOCK_EVENTS"
    if [[ "$state" == "10" ]]; then
      exit "\${MOCK_SETUP_RESTART_STATUS:-0}"
    fi
    exit "\${MOCK_RESTORE_RESTART_STATUS:-0}"
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
    count_file="\${MOCK_EVENTS}.show-count"
    show_count=0
    if [[ -f "$count_file" ]]; then
      read -r show_count < "$count_file"
    fi
    show_count=$((show_count + 1))
    printf '%s\n' "$show_count" > "$count_file"
    printf 'psql-show-%s\n' "$show_count" >> "$MOCK_EVENTS"
    if (( show_count == 2 )) && [[ "\${MOCK_SETUP_VERIFY_STATUS:-0}" != "0" ]]; then
      exit "$MOCK_SETUP_VERIFY_STATUS"
    fi
    if [[ -f "$MOCK_STATE_FILE" ]]; then
      cat "$MOCK_STATE_FILE"
    else
      printf '0\n'
    fi
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
exit "\${MOCK_READY_STATUS:-0}"
READY
chmod +x "$MOCK_BIN/pg_isready"

cat > "$MOCK_BIN/sleep" <<'SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep-%s\n' "$*" >> "$MOCK_EVENTS"
SLEEP
chmod +x "$MOCK_BIN/sleep"

run_case() {
  local label="$1"
  local expected_setup_status="$2"
  local expected_setup_error="$3"
  shift 3
  local case_dir="$TEMP_DIR/$label"
  local events="$case_dir/events.log"
  local state_file="$case_dir/config-state"
  local output_file="$case_dir/github-output"
  local setup_log="$case_dir/setup.log"
  local restore_log="$case_dir/restore.log"
  mkdir -p "$case_dir"
  : > "$events"
  : > "$output_file"
  rm -f "$events.show-count" "$state_file"

  local setup_status=0
  if env PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$events" MOCK_STATE_FILE="$state_file" \
    MOCK_GITHUB_OUTPUT="$output_file" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    GITHUB_OUTPUT="$output_file" "$@" \
    bash "$SETUP_SCRIPT" > "$setup_log" 2>&1; then
    setup_status=0
  else
    setup_status=$?
  fi

  if [[ "$setup_status" -ne "$expected_setup_status" ]] ||
     ! grep -Fq "$expected_setup_error" "$setup_log"; then
    echo "ERROR: $label setup did not fail at the expected boundary (status=$setup_status)." >&2
    cat "$setup_log" >&2
    exit 1
  fi

  local expected_marker
  expected_marker="$(printf 'baseline=0\nrestore_required=true')"
  if [[ "$(cat "$output_file")" != "$expected_marker" ]] ||
     [[ ! -f "$state_file" ]] || [[ "$(cat "$state_file")" != "10" ]]; then
    echo "ERROR: $label did not leave an exact cleanup marker and a simulated partial configuration change." >&2
    cat "$output_file" >&2
    [[ -f "$state_file" ]] && cat "$state_file" >&2
    exit 1
  fi

  local restore_status=0
  if env PATH="$MOCK_BIN:$PATH" \
    MOCK_EVENTS="$events" MOCK_STATE_FILE="$state_file" \
    MOCK_GITHUB_OUTPUT="$output_file" \
    DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test" \
    RESTORE_REQUIRED=true BASELINE_MAX_PREPARED_TRANSACTIONS=0 "$@" \
    bash "$RESTORE_SCRIPT" > "$restore_log" 2>&1; then
    restore_status=0
  else
    restore_status=$?
  fi

  if [[ "$restore_status" -ne 0 ]] ||
     [[ "$(cat "$state_file")" != "0" ]] ||
     ! grep -Fq "QA267 passed" "$restore_log"; then
    echo "ERROR: $label cleanup did not restore and verify the captured baseline (status=$restore_status)." >&2
    cat "$events" >&2
    cat "$restore_log" >&2
    exit 1
  fi

  local expected_events
  case "$label" in
    set-failure)
      expected_events=$'docker-ps\npsql-show-1\ndocker-exec-set\ndocker-ps\npg-isready\ndocker-exec-reset\ndocker-restart\npg-isready\npsql-show-2\npsql-prepared\npsql-database'
      ;;
    restart-failure)
      expected_events=$'docker-ps\npsql-show-1\ndocker-exec-set\ndocker-restart\ndocker-ps\npg-isready\ndocker-exec-reset\ndocker-restart\npg-isready\npsql-show-2\npsql-prepared\npsql-database'
      ;;
    verify-failure)
      expected_events=$'docker-ps\npsql-show-1\ndocker-exec-set\ndocker-restart\npg-isready\npsql-show-2\ndocker-ps\npg-isready\ndocker-exec-reset\ndocker-restart\npg-isready\npsql-show-3\npsql-prepared\npsql-database'
      ;;
    *)
      echo "ERROR: unknown QA350 case $label." >&2
      exit 1
      ;;
  esac

  if [[ "$(cat "$events")" != "$expected_events" ]]; then
    echo "ERROR: $label command order differed from the expected setup-failure then always-cleanup sequence." >&2
    printf 'Expected:\n%s\nActual:\n' "$expected_events" >&2
    cat "$events" >&2
    exit 1
  fi

  if grep -Fq "postgres:postgres" "$setup_log" "$restore_log"; then
    echo "ERROR: $label diagnostics exposed disposable PostgreSQL credentials." >&2
    exit 1
  fi

  echo "QA350 $label passed: setup exit $setup_status retained the restoration marker; always-cleanup reset and verified baseline 0."
}

run_case "set-failure" 47 "ALTER SYSTEM SET max_prepared_transactions failed (docker exec exit 47)" MOCK_SET_STATUS=47
run_case "restart-failure" 48 "PostgreSQL setup restart failed (docker restart exit 48)" MOCK_SETUP_RESTART_STATUS=48
run_case "verify-failure" 49 "Could not verify prepared-transaction setup (psql exit 49)" MOCK_SETUP_VERIFY_STATUS=49

echo "QA350 passed: simulated partial SET, failed restart, and failed post-restart SHOW each retained the exact cleanup marker; the always() restoration script reset max_prepared_transactions to baseline 0, restarted the disposable service, verified zero prepared transactions and zero leftover migration databases, and did not expose credentials. All external commands were inert local mocks."
