#!/usr/bin/env bash
set -euo pipefail

DATABASE_URL="${DATABASE_URL-}"
if [[ -z "$DATABASE_URL" ]]; then
  echo "::error::DATABASE_URL is required." >&2
  exit 2
fi

# This test runs a destructive disposable-database runner. Fail closed before
# invoking any client unless the URL targets the dedicated loopback CI database.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing multiple-session cleanup regression: DATABASE_URL must target qima_test on loopback port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-legacy-messages-rls-regression.sh"
ASSERTION="$ROOT/tests/sql/assert-legacy-migration-database-absent.sh"
ASSERTIONS_FILE="$ROOT/tests/sql/legacy-messages-migration-assertions.sql"
REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "::error::psql client is required for the multiple-session cleanup regression." >&2
  exit 127
fi

MIGRATION_DATABASE_NAME="qima_message_migration_test"
MIGRATION_DATABASE_URL="$(printf '%s\n' "$DATABASE_URL" | sed 's#/qima_test$#/qima_message_migration_test#')"
TEMP_DIR="$(mktemp -d)"
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"

RUNNER_OUTPUT="$TEMP_DIR/runner-output.log"
ASSERTION_OUTPUT="$TEMP_DIR/assertion-output.log"
ACTIVE_ONE_LOG="$TEMP_DIR/active-one.log"
ACTIVE_TWO_LOG="$TEMP_DIR/active-two.log"
IDLE_LOG="$TEMP_DIR/idle-in-transaction.log"
ACTIVE_ONE_STATUS="$TEMP_DIR/active-one.status"
ACTIVE_TWO_STATUS="$TEMP_DIR/active-two.status"
IDLE_STATUS="$TEMP_DIR/idle.status"
ACTIVE_ONE_PID="$TEMP_DIR/active-one.pid"
ACTIVE_TWO_PID="$TEMP_DIR/active-two.pid"
IDLE_READER_PID="$TEMP_DIR/idle-reader.pid"
IDLE_WRITER_PID="$TEMP_DIR/idle-writer.pid"
IDLE_FIFO="$TEMP_DIR/idle-session.fifo"
IDLE_WRITER_READY="$TEMP_DIR/idle-writer.ready"
SESSION_READY="$TEMP_DIR/sessions.ready"

cleanup_test_processes() {
  if [[ -s "$IDLE_WRITER_PID" ]]; then
    kill "$(cat "$IDLE_WRITER_PID")" 2>/dev/null || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup_test_processes EXIT

cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail

previous_arg=""
is_assertions=false
for arg in "$@"; do
  if [[ "$previous_arg" == "-f" && "$arg" == "$MOCK_ASSERTIONS_FILE" ]]; then
    is_assertions=true
  fi
  previous_arg="$arg"
done

set +e
"$REAL_PSQL" "$@"
psql_status=$?
set -e
if [[ "$psql_status" -ne 0 ]]; then
  exit "$psql_status"
fi

if [[ "$is_assertions" == true ]]; then
  if [[ -e "$MOCK_SESSION_READY_FILE" ]]; then
    echo "ERROR: QA265 attempted to establish its PostgreSQL sessions more than once." >&2
    exit 1
  fi

  start_active_session() {
    local app_name="$1"
    local log_file="$2"
    local status_file="$3"
    local pid_file="$4"

    MOCK_APP_NAME="$app_name" MOCK_SESSION_LOG="$log_file" MOCK_SESSION_STATUS_FILE="$status_file" \
      nohup bash -c '
        set +e
        PGAPPNAME="$MOCK_APP_NAME" "$REAL_PSQL" "$MOCK_MIGRATION_DATABASE_URL" \
          -X -v ON_ERROR_STOP=1 -c "SELECT pg_sleep(60)" > "$MOCK_SESSION_LOG" 2>&1
        session_status=$?
        printf "%s\n" "$session_status" > "$MOCK_SESSION_STATUS_FILE"
        exit 0
      ' </dev/null >/dev/null 2>&1 &
    printf "%s\n" "$!" > "$pid_file"
  }

  start_active_session "qa265-active-one" "$MOCK_ACTIVE_ONE_LOG" "$MOCK_ACTIVE_ONE_STATUS" "$MOCK_ACTIVE_ONE_PID"
  start_active_session "qa265-active-two" "$MOCK_ACTIVE_TWO_LOG" "$MOCK_ACTIVE_TWO_STATUS" "$MOCK_ACTIVE_TWO_PID"

  # Keep a third psql client connected after BEGIN/SELECT so PostgreSQL reports
  # state='idle in transaction' while the runner's EXIT trap executes.
  mkfifo "$MOCK_IDLE_FIFO"
  MOCK_IDLE_LOG="$MOCK_IDLE_LOG" MOCK_IDLE_STATUS_FILE="$MOCK_IDLE_STATUS" \
    nohup bash -c '
      set +e
      PGAPPNAME=qa265-idle-in-transaction "$REAL_PSQL" "$MOCK_MIGRATION_DATABASE_URL" \
        -X -v ON_ERROR_STOP=1 < "$MOCK_IDLE_FIFO" > "$MOCK_IDLE_LOG" 2>&1
      session_status=$?
      printf "%s\n" "$session_status" > "$MOCK_IDLE_STATUS_FILE"
      exit 0
    ' </dev/null >/dev/null 2>&1 &
  printf "%s\n" "$!" > "$MOCK_IDLE_READER_PID"

  MOCK_IDLE_FIFO="$MOCK_IDLE_FIFO" MOCK_IDLE_WRITER_READY_FILE="$MOCK_IDLE_WRITER_READY_FILE" \
    nohup bash -c '
      exec 9>"$MOCK_IDLE_FIFO"
      printf "BEGIN;\nSELECT 1;\n" >&9
      printf "ready\n" > "$MOCK_IDLE_WRITER_READY_FILE"
      # psql reading a FIFO may wait on stdin without noticing an asynchronous
      # server disconnect. Send a harmless follow-up after DROP DATABASE has
      # had time to run so libpq observes the closed connection and exits.
      sleep 2
      printf "SELECT 2;\n" >&9
      exec sleep 120
    ' </dev/null >/dev/null 2>&1 &
  printf "%s\n" "$!" > "$MOCK_IDLE_WRITER_PID"

  for attempt in {1..100}; do
    if [[ -s "$MOCK_IDLE_WRITER_READY_FILE" ]]; then
      observed="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc "
        SELECT
          count(*) FILTER (WHERE application_name = 'qa265-active-one' AND state = 'active')::text || '|' ||
          count(*) FILTER (WHERE application_name = 'qa265-active-two' AND state = 'active')::text || '|' ||
          count(*) FILTER (WHERE application_name = 'qa265-idle-in-transaction' AND state = 'idle in transaction')::text
        FROM pg_stat_activity
        WHERE datname = '$MOCK_MIGRATION_DATABASE_NAME'
      ")"
      if [[ "$observed" == "1|1|1" ]]; then
        printf "%s\n" "$observed" > "$MOCK_SESSION_READY_FILE"
        echo "QA265 confirmed two active PostgreSQL sessions and one idle-in-transaction session before runner cleanup."
        exit 0
      fi
    fi
    sleep 0.1
  done

  echo "ERROR: QA265 could not confirm both active sessions and the idle-in-transaction session in pg_stat_activity." >&2
  exit 1
fi

exit 0
PSQL
chmod +x "$MOCK_BIN/psql"

set +e
PATH="$MOCK_BIN:$PATH" \
  REAL_PSQL="$REAL_PSQL" \
  MOCK_ASSERTIONS_FILE="$ASSERTIONS_FILE" \
  MOCK_MIGRATION_DATABASE_URL="$MIGRATION_DATABASE_URL" \
  MOCK_MIGRATION_DATABASE_NAME="$MIGRATION_DATABASE_NAME" \
  MOCK_ACTIVE_ONE_LOG="$ACTIVE_ONE_LOG" \
  MOCK_ACTIVE_TWO_LOG="$ACTIVE_TWO_LOG" \
  MOCK_IDLE_LOG="$IDLE_LOG" \
  MOCK_ACTIVE_ONE_STATUS="$ACTIVE_ONE_STATUS" \
  MOCK_ACTIVE_TWO_STATUS="$ACTIVE_TWO_STATUS" \
  MOCK_IDLE_STATUS="$IDLE_STATUS" \
  MOCK_ACTIVE_ONE_PID="$ACTIVE_ONE_PID" \
  MOCK_ACTIVE_TWO_PID="$ACTIVE_TWO_PID" \
  MOCK_IDLE_READER_PID="$IDLE_READER_PID" \
  MOCK_IDLE_WRITER_PID="$IDLE_WRITER_PID" \
  MOCK_IDLE_FIFO="$IDLE_FIFO" \
  MOCK_IDLE_WRITER_READY_FILE="$IDLE_WRITER_READY" \
  MOCK_SESSION_READY_FILE="$SESSION_READY" \
  DATABASE_URL="$DATABASE_URL" \
  bash "$RUNNER" > "$RUNNER_OUTPUT" 2>&1
runner_status=$?
set -e

if [[ "$runner_status" -ne 0 ]]; then
  echo "ERROR: migration runner failed before completing the multiple-session cleanup path (exit $runner_status)." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if [[ "$(cat "$SESSION_READY" 2>/dev/null || true)" != "1|1|1" ]]; then
  echo "ERROR: QA265 did not positively confirm all three PostgreSQL session states before cleanup." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

for attempt in {1..100}; do
  if [[ -s "$ACTIVE_ONE_STATUS" && -s "$ACTIVE_TWO_STATUS" && -s "$IDLE_STATUS" ]]; then
    break
  fi
  sleep 0.1
done

for status_file in "$ACTIVE_ONE_STATUS" "$ACTIVE_TWO_STATUS" "$IDLE_STATUS"; do
  if [[ ! -s "$status_file" ]]; then
    echo "ERROR: one or more held PostgreSQL clients did not exit after DROP DATABASE WITH (FORCE)." >&2
    cat "$ACTIVE_ONE_LOG" "$ACTIVE_TWO_LOG" "$IDLE_LOG" >&2 || true
    exit 1
  fi
  session_status="$(cat "$status_file")"
  if [[ ! "$session_status" =~ ^[0-9]+$ || "$session_status" -eq 0 ]]; then
    echo "ERROR: a held PostgreSQL client did not report an administrative termination (status: $session_status)." >&2
    exit 1
  fi
done

for log_file in "$ACTIVE_ONE_LOG" "$ACTIVE_TWO_LOG"; do
  if ! grep -Fq "terminating connection due to administrator command" "$log_file"; then
    echo "ERROR: PostgreSQL did not record administrator termination for an active held session." >&2
    cat "$log_file" >&2 || true
    exit 1
  fi
done

# The idle-in-transaction psql client is waiting on its FIFO. The writer sends
# SELECT 2 after cleanup so the client observes the already-closed connection.
if ! grep -Fq "terminating connection due to administrator command" "$IDLE_LOG" &&
   ! grep -Eq "server closed the connection unexpectedly|connection to server was lost" "$IDLE_LOG"; then
  echo "ERROR: idle-in-transaction client did not report the database connection being terminated." >&2
  cat "$IDLE_LOG" >&2 || true
  exit 1
fi

# Verify through the unwrapped, real client that the disposable database is gone.
if ! DATABASE_URL="$DATABASE_URL" bash "$ASSERTION" > "$ASSERTION_OUTPUT" 2>&1; then
  echo "ERROR: the temporary database remained after multiple-session cleanup." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if ! grep -Fq "is absent after the migration runner EXIT trap" "$ASSERTION_OUTPUT"; then
  echo "ERROR: post-cleanup database absence was not positively confirmed." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if grep -Fq "postgres:postgres" "$RUNNER_OUTPUT" "$ACTIVE_ONE_LOG" "$ACTIVE_TWO_LOG" "$IDLE_LOG"; then
  echo "ERROR: QA265 output exposed disposable database credentials." >&2
  exit 1
fi

echo "QA265 passed: two real active PostgreSQL sessions and one idle-in-transaction session were confirmed before cleanup; DROP DATABASE WITH (FORCE) terminated all three and pg_database confirmed the temporary database was absent."
