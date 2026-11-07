#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Keep the original predicate-level synthetic regression suite.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/tests/sql/legacy-messages-rls-regression.sql"

# Exercise the actual branch migration in a separate disposable database.
# The CI PostgreSQL service is isolated; never point this runner at production.
MIGRATION_DATABASE_NAME="qima_message_migration_test"
drop_migration_database() {
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS ${MIGRATION_DATABASE_NAME} WITH (FORCE)" >/dev/null 2>&1 || true
}
trap drop_migration_database EXIT

drop_migration_database
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE ${MIGRATION_DATABASE_NAME}"

# CI DATABASE_URL has a single database path component and no query string.
MIGRATION_DATABASE_URL="${DATABASE_URL%/*}/${MIGRATION_DATABASE_NAME}"

psql "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -f "$ROOT/tests/sql/legacy-messages-migration-fixture.sql"
psql "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -f "$ROOT/supabase/migrations/20261028180000_fix_message_participant_authorization.sql"
psql "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -f "$ROOT/tests/sql/legacy-messages-migration-assertions.sql"
