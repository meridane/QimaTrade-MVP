#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must point to the disposable PostgreSQL test database}"

# This check is read-only, but still fail closed to the same dedicated CI database.
# Never print DATABASE_URL because it may contain credentials.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\\.0\\.0\\.1|\\[::1\\]):5432/qima_test$ ]]; then
  echo "::error::Refusing to inspect migration cleanup: DATABASE_URL must target qima_test on a loopback host at port 5432." >&2
  exit 2
fi

MIGRATION_DATABASE_NAME="qima_message_migration_test"
remaining_count="$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
  "SELECT count(*) FROM pg_database WHERE datname = '${MIGRATION_DATABASE_NAME}'")"

if [[ "$remaining_count" != "0" ]]; then
  echo "::error::Disposable migration database ${MIGRATION_DATABASE_NAME} still exists after the runner completed (matching databases: ${remaining_count})." >&2
  exit 1
fi

echo "Verified against the live PostgreSQL service: ${MIGRATION_DATABASE_NAME} is absent after the migration runner EXIT trap."
