#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable PostgreSQL test database}"

# This regression invokes the destructive runner, so enforce the same dedicated
# loopback-only target before creating any temporary files or invoking psql.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing real-failure cleanup regression: DATABASE_URL must target qima_test on a loopback host at port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-legacy-messages-rls-regression.sh"
ASSERTION="$ROOT/tests/sql/assert-legacy-migration-database-absent.sh"
MIGRATION_FILE="$ROOT/supabase/migrations/20261028180000_fix_message_participant_authorization.sql"
REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "::error::psql client is required for the real PostgreSQL failure-path regression." >&2
  exit 127
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
FAILURE_SQL="$TEMP_DIR/qa263-failing-migration.sql"
INTERCEPT_LOG="$TEMP_DIR/migration-intercept.log"
RUNNER_OUTPUT="$TEMP_DIR/runner-output.log"
ASSERTION_OUTPUT="$TEMP_DIR/assertion-output.log"

# The injected SQL must fail on the actual PostgreSQL service, not in a stub.
cat > "$FAILURE_SQL" <<'SQL'
SELECT * FROM qa263_relation_that_must_not_exist;
SQL

# Delegate every PostgreSQL operation to the real client. Only replace the
# branch migration file argument with the deterministic failing SQL file.
cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
for ((index = 0; index < ${#args[@]} - 1; index++)); do
  if [[ "${args[index]}" == "-f" && "${args[index+1]}" == "$MOCK_MIGRATION_FILE" ]]; then
    args[index+1]="$MOCK_FAILURE_SQL"
    printf '%s\n' "intercepted" >> "$MOCK_INTERCEPT_LOG"
  fi
done
exec "$REAL_PSQL" "${args[@]}"
PSQL
chmod +x "$MOCK_BIN/psql"

set +e
PATH="$MOCK_BIN:$PATH" \
  REAL_PSQL="$REAL_PSQL" \
  MOCK_MIGRATION_FILE="$MIGRATION_FILE" \
  MOCK_FAILURE_SQL="$FAILURE_SQL" \
  MOCK_INTERCEPT_LOG="$INTERCEPT_LOG" \
  DATABASE_URL="$DATABASE_URL" \
  bash "$RUNNER" > "$RUNNER_OUTPUT" 2>&1
runner_status=$?
set -e

# psql returns 3 when ON_ERROR_STOP aborts a script after an SQL error.
if [[ "$runner_status" -ne 3 ]]; then
  echo "ERROR: expected the real SQL failure to preserve psql exit 3; received $runner_status." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if [[ ! -f "$INTERCEPT_LOG" ]] || [[ "$(wc -l < "$INTERCEPT_LOG")" -ne 1 ]]; then
  echo "ERROR: the real migration invocation was not intercepted exactly once; failure path is unproven." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if ! grep -Fq "qa263_relation_that_must_not_exist" "$RUNNER_OUTPUT" ||
   ! grep -Fq "does not exist" "$RUNNER_OUTPUT"; then
  echo "ERROR: PostgreSQL did not report the expected missing-relation SQL error." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if grep -Fq "postgres:postgres" "$RUNNER_OUTPUT"; then
  echo "ERROR: runner output exposed the disposable database URL credentials." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

# PATH in this parent shell is unchanged, so this uses the real psql client.
if ! DATABASE_URL="$DATABASE_URL" bash "$ASSERTION" > "$ASSERTION_OUTPUT" 2>&1; then
  echo "ERROR: the temporary database remained after the real SQL failure." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if ! grep -Fq "is absent after the migration runner EXIT trap" "$ASSERTION_OUTPUT"; then
  echo "ERROR: post-failure database absence was not positively confirmed." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

echo "QA263 passed: PostgreSQL executed the injected SQL error (psql exit 3), the runner EXIT trap cleaned up the temporary database, and pg_database confirmed its absence."
