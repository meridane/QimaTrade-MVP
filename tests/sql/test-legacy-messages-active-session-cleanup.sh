#!/usr/bin/env bash
set -euo pipefail

DATABASE_URL="${DATABASE_URL-}"
if [[ -z "$DATABASE_URL" ]]; then
  echo "::error::DATABASE_URL is required." >&2
  exit 2
fi

# The runner drops and recreates a database. Restrict this regression to the
# dedicated loopback qima_test service before invoking any database client.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing active-session cleanup regression: DATABASE_URL must target qima_test on a loopback host at port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-legacy-messages-rls-regression.sh"
ASSERTION="$ROOT/tests/sql/assert-legacy-migration-database-absent.sh"
ASSERTIONS_FILE="$ROOT/tests/sql/legacy-messages-migration-assertions.sql"
REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "::error::psql client is required for the active-session cleanup regression." >&2
  exit 127
fi

MIGRATION_DATABASE_NAME="qima_message_migration_test"
MIGRATION_DATABASE_URL="$(printf '%s\n' "$DATABASE_URL" | sed 's#/qima_test$#/qima_message_migration_test#')"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
RUNNER_OUTPUT="$TEMP_DIR/runner-output.log"
ASSERTION_OUTPUT="$TEMP_DIR/assertion-output.log"
SESSION_LOG="$TEMP_DIR/held-session.log"
SESSION_PID_FILE="$TEMP_DIR/held-session.pid"
SESSION_STATUS_FILE="$TEMP_DIR/held-session.status"
SESSION_READY_FILE="$TEMP_DIR/held-session.ready"

# Delegate all normal work to the real psql client. Immediately after the
# migration assertions finish, open a second real PostgreSQL session and keep
# it active in pg_sleep until the runner's EXIT trap drops the database.
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
  if [[ -e "$MOCK_SESSION_PID_FILE" ]]; then
    echo "ERROR: QA264 attempted to create more than one held PostgreSQL session." >&2
    exit 1
  fi

  nohup bash -c '
    set +e
    PGAPPNAME=qa264-held-session "$REAL_PSQL" "$MOCK_MIGRATION_DATABASE_URL" \
      -X -v ON_ERROR_STOP=1 -c "SELECT pg_sleep(60)" > "$MOCK_SESSION_LOG" 2>&1
    session_status=$?
    printf "%s\n" "$session_status" > "$MOCK_SESSION_STATUS_FILE"
    exit 0
  ' </dev/null >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$MOCK_SESSION_PID_FILE"

  for attempt in {1..100}; do
    active_count="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
      "SELECT count(*) FROM pg_stat_activity WHERE datname = 'qima_message_migration_test' AND application_name = 'qa264-held-session' AND state = 'active'")"
    if [[ "$active_count" == "1" ]]; then
      printf '%s\n' ready > "$MOCK_SESSION_READY_FILE"
      echo "QA264 established a second active PostgreSQL session before the runner EXIT trap."
      exit 0
    fi
    sleep 0.1
  done

  echo "ERROR: QA264 could not observe its held PostgreSQL session in pg_stat_activity." >&2
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
  MOCK_SESSION_LOG="$SESSION_LOG" \
  MOCK_SESSION_PID_FILE="$SESSION_PID_FILE" \
  MOCK_SESSION_STATUS_FILE="$SESSION_STATUS_FILE" \
  MOCK_SESSION_READY_FILE="$SESSION_READY_FILE" \
  DATABASE_URL="$DATABASE_URL" \
  bash "$RUNNER" > "$RUNNER_OUTPUT" 2>&1
runner_status=$?
set -e

if [[ "$runner_status" -ne 0 ]]; then
  echo "ERROR: migration runner failed before completing the active-session cleanup path (exit $runner_status)." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if [[ ! -s "$SESSION_READY_FILE" ]]; then
  echo "ERROR: the second PostgreSQL session was not confirmed active before runner cleanup." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

# DROP DATABASE ... WITH (FORCE) should terminate the active pg_sleep backend.
for attempt in {1..100}; do
  [[ -s "$SESSION_STATUS_FILE" ]] && break
  sleep 0.1
done

if [[ ! -s "$SESSION_STATUS_FILE" ]]; then
  echo "ERROR: held PostgreSQL session did not terminate after DROP DATABASE WITH (FORCE)." >&2
  cat "$SESSION_LOG" >&2 || true
  exit 1
fi

session_status="$(cat "$SESSION_STATUS_FILE")"
if [[ "$session_status" -eq 0 ]]; then
  echo "ERROR: held PostgreSQL session completed normally instead of being terminated by database cleanup." >&2
  cat "$SESSION_LOG" >&2
  exit 1
fi

if ! grep -Fq "terminating connection due to administrator command" "$SESSION_LOG"; then
  echo "ERROR: held session failed, but PostgreSQL did not report administrator termination." >&2
  cat "$SESSION_LOG" >&2
  exit 1
fi

# Verify with the unwrapped, real psql client that the database is gone.
if ! DATABASE_URL="$DATABASE_URL" bash "$ASSERTION" > "$ASSERTION_OUTPUT" 2>&1; then
  echo "ERROR: the temporary database remained after active-session cleanup." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if ! grep -Fq "is absent after the migration runner EXIT trap" "$ASSERTION_OUTPUT"; then
  echo "ERROR: post-cleanup database absence was not positively confirmed." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if grep -Fq "postgres:postgres" "$RUNNER_OUTPUT" "$SESSION_LOG"; then
  echo "ERROR: QA264 output exposed disposable database credentials." >&2
  exit 1
fi

echo "QA264 passed: a second real PostgreSQL session was active during runner cleanup, DROP DATABASE WITH (FORCE) terminated it, and pg_database confirmed the temporary database was absent."
