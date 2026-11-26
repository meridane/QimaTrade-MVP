#!/usr/bin/env bash
set -euo pipefail

DATABASE_URL="${DATABASE_URL-}"
if [[ -z "$DATABASE_URL" ]]; then
  echo "::error::DATABASE_URL is required." >&2
  exit 2
fi

# The runner creates and drops a database. Permit only the dedicated loopback CI database.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing prepared-transaction cleanup regression: DATABASE_URL must target qima_test on loopback port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-legacy-messages-rls-regression.sh"
ASSERTION="$ROOT/tests/sql/assert-legacy-migration-database-absent.sh"
ASSERTIONS_FILE="$ROOT/tests/sql/legacy-messages-migration-assertions.sql"
REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "::error::psql client is required for the prepared-transaction cleanup regression." >&2
  exit 127
fi

MIGRATION_DATABASE_NAME="qima_message_migration_test"
MIGRATION_DATABASE_URL="$(printf '%s\n' "$DATABASE_URL" | sed 's#/qima_test$#/qima_message_migration_test#')"
PREPARED_GID="qa266_prepared_cleanup_blocker"
TEMP_DIR="$(mktemp -d)"
MOCK_BIN="$TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"

RUNNER_OUTPUT="$TEMP_DIR/runner-output.log"
DROP_BLOCKER_OUTPUT="$TEMP_DIR/drop-blocker-output.log"
ASSERTION_OUTPUT="$TEMP_DIR/assertion-output.log"
PREPARED_READY="$TEMP_DIR/prepared.ready"
PREPARED_SQL="$TEMP_DIR/prepare-transaction.sql"

CLEANUP_DONE=false
cleanup_test_resources() {
  if [[ "$CLEANUP_DONE" != true ]]; then
    # If setup reached PREPARE TRANSACTION, resolve it before dropping the test database.
    "$REAL_PSQL" "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
      -c "ROLLBACK PREPARED '$PREPARED_GID'" >/dev/null 2>&1 || true
    "$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 \
      -c "DROP DATABASE IF EXISTS $MIGRATION_DATABASE_NAME WITH (FORCE)" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup_test_resources EXIT

cat > "$PREPARED_SQL" <<SQL
CREATE TABLE qa266_prepared_marker (id integer NOT NULL);
BEGIN;
INSERT INTO qa266_prepared_marker (id) VALUES (1);
PREPARE TRANSACTION '$PREPARED_GID';
SQL

# Confirm that CI enabled prepared transactions before invoking the destructive runner.
max_prepared="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc "SHOW max_prepared_transactions")"
if [[ ! "$max_prepared" =~ ^[1-9][0-9]*$ ]]; then
  echo "::error::QA266 requires max_prepared_transactions greater than zero on the disposable PostgreSQL service." >&2
  exit 1
fi

# Delegate normal runner commands to the real client. After the migration assertions,
# prepare one real transaction in the disposable migration database. PostgreSQL must
# refuse DROP DATABASE WITH (FORCE) while that prepared transaction remains unresolved.
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

"$REAL_PSQL" "$@"

if [[ "$is_assertions" == true ]]; then
  if [[ -e "$MOCK_PREPARED_READY" ]]; then
    echo "ERROR: QA266 attempted to prepare its blocker more than once." >&2
    exit 1
  fi

  "$REAL_PSQL" "$MOCK_MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
    -f "$MOCK_PREPARED_SQL"
  printf '%s\n' ready > "$MOCK_PREPARED_READY"
  echo "QA266 prepared a real transaction in the disposable migration database."
fi
PSQL
chmod +x "$MOCK_BIN/psql"

set +e
PATH="$MOCK_BIN:$PATH" \
  REAL_PSQL="$REAL_PSQL" \
  MOCK_ASSERTIONS_FILE="$ASSERTIONS_FILE" \
  MOCK_MIGRATION_DATABASE_URL="$MIGRATION_DATABASE_URL" \
  MOCK_PREPARED_SQL="$PREPARED_SQL" \
  MOCK_PREPARED_READY="$PREPARED_READY" \
  DATABASE_URL="$DATABASE_URL" \
  bash "$RUNNER" > "$RUNNER_OUTPUT" 2>&1
runner_status=$?
set -e

if [[ "$runner_status" -ne 0 ]]; then
  echo "::error::QA266 runner should preserve the successful migration status when best-effort cleanup is blocked; got exit $runner_status." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if [[ ! -s "$PREPARED_READY" ]]; then
  echo "::error::QA266 did not create the prepared transaction after migration assertions." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

if ! grep -Fq "Best-effort cleanup of $MIGRATION_DATABASE_NAME failed (psql exit 1)" "$RUNNER_OUTPUT"; then
  echo "::error::Runner did not report the prepared-transaction cleanup blocker." >&2
  cat "$RUNNER_OUTPUT" >&2
  exit 1
fi

prepared_count="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
  "SELECT count(*) FROM pg_prepared_xacts WHERE gid = '$PREPARED_GID' AND database = '$MIGRATION_DATABASE_NAME'")"
database_count="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
  "SELECT count(*) FROM pg_database WHERE datname = '$MIGRATION_DATABASE_NAME'")"
if [[ "$prepared_count" != "1" || "$database_count" != "1" ]]; then
  echo "::error::Expected one unresolved prepared transaction and one remaining disposable database; got prepared=$prepared_count database=$database_count." >&2
  exit 1
fi

# The read-only absence assertion must not mistake the blocked cleanup for success.
set +e
DATABASE_URL="$DATABASE_URL" bash "$ASSERTION" > "$ASSERTION_OUTPUT" 2>&1
assertion_status=$?
set -e
if [[ "$assertion_status" -ne 1 ]] || ! grep -Fq "still exists after the runner completed" "$ASSERTION_OUTPUT"; then
  echo "::error::The post-run assertion did not report the database that remains blocked by a prepared transaction." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

# Ask PostgreSQL directly for the blocker reason before resolving the prepared transaction.
set +e
"$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE $MIGRATION_DATABASE_NAME WITH (FORCE)" > "$DROP_BLOCKER_OUTPUT" 2>&1
drop_status=$?
set -e
if [[ "$drop_status" -eq 0 ]] || ! grep -Fqi "prepared transactions" "$DROP_BLOCKER_OUTPUT"; then
  echo "::error::PostgreSQL did not report the prepared transaction as the DROP DATABASE blocker." >&2
  cat "$DROP_BLOCKER_OUTPUT" >&2
  exit 1
fi

# Resolve only the disposable prepared transaction, then remove and verify the database.
"$REAL_PSQL" "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -c "ROLLBACK PREPARED '$PREPARED_GID'"
"$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE $MIGRATION_DATABASE_NAME WITH (FORCE)"

remaining_prepared="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
  "SELECT count(*) FROM pg_prepared_xacts WHERE gid = '$PREPARED_GID'")"
if [[ "$remaining_prepared" != "0" ]]; then
  echo "::error::QA266 left its prepared transaction unresolved." >&2
  exit 1
fi

if ! DATABASE_URL="$DATABASE_URL" bash "$ASSERTION" > "$ASSERTION_OUTPUT" 2>&1; then
  echo "::error::The disposable migration database remained after explicit rollback and cleanup." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if ! grep -Fq "is absent after the migration runner EXIT trap" "$ASSERTION_OUTPUT"; then
  echo "::error::QA266 did not positively confirm final database absence." >&2
  cat "$ASSERTION_OUTPUT" >&2
  exit 1
fi

if grep -Fq "postgres:postgres" "$RUNNER_OUTPUT" "$DROP_BLOCKER_OUTPUT" "$ASSERTION_OUTPUT"; then
  echo "::error::QA266 output exposed disposable database credentials." >&2
  exit 1
fi

CLEANUP_DONE=true
echo "QA266 passed: PostgreSQL refused forced database cleanup while a real prepared transaction existed; the runner reported the blocker without claiming deletion, the read-only assertion detected the remaining database, and explicit ROLLBACK PREPARED allowed final cleanup and pg_database absence verification."
