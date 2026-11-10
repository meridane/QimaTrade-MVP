#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable PostgreSQL CI database}"

# This runner creates and drops a dedicated database and role. Fail closed
# unless DATABASE_URL is the exact loopback qima_test service used by CI.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing wrapper-owner regression: DATABASE_URL must target qima_test on a loopback host at port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DATABASE="qima_wrapper_owner_test_db"
TEST_ROLE="qima_wrapper_owner_test"
TEST_DATABASE_URL="${DATABASE_URL%/qima_test}/${TEST_DATABASE}"
created_database=0
created_role=0
created_anon=0
created_authenticated=0

cleanup() {
  local status=$?
  trap - EXIT

  if [[ "$created_database" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP DATABASE ${TEST_DATABASE} WITH (FORCE)" >/dev/null || status=1
    remaining="$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_database WHERE datname = '${TEST_DATABASE}'" 2>/dev/null || true)"
    if [[ "$remaining" == "1" ]]; then
      echo "::error::Disposable wrapper-owner database was not removed." >&2
      status=1
    fi
  fi

  if [[ "$created_role" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE ${TEST_ROLE}" >/dev/null || status=1
  fi
  if [[ "$created_authenticated" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE authenticated" >/dev/null || status=1
  fi
  if [[ "$created_anon" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP ROLE anon" >/dev/null || status=1
  fi

  exit "$status"
}
trap cleanup EXIT

if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_database WHERE datname = '${TEST_DATABASE}'")" == "1" ]]; then
  echo "::error::Refusing to reuse existing ${TEST_DATABASE}; no database was modified." >&2
  exit 2
fi
if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = '${TEST_ROLE}'")" == "1" ]]; then
  echo "::error::Refusing to reuse existing ${TEST_ROLE}; no role was modified." >&2
  exit 2
fi

if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = 'anon'")" != "1" ]]; then
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE anon NOLOGIN"
  created_anon=1
fi
if [[ "$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = 'authenticated'")" != "1" ]]; then
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE authenticated NOLOGIN"
  created_authenticated=1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE ROLE ${TEST_ROLE} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT"
created_role=1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE DATABASE ${TEST_DATABASE} TEMPLATE template0"
created_database=1

psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/tests/sql/create-offer-wrapper-owner-regression.sql"
