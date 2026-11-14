#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"

# This SQL fixture creates a schema and roles, truncates its fixture tables, and
# replaces test policies. Reject every destination except the dedicated CI DB.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing participant self-enrollment regression: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/tests/sql/participant-self-enrollment-regression.sql"
