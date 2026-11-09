#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable PostgreSQL CI database}"

# This runner creates and drops a dedicated database. Fail closed unless the
# supplied URL is the exact qima_test loopback service used by CI.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing ACL regression setup: DATABASE_URL must target qima_test on a loopback host at port 5432." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACL_DATABASE="qima_acl_test"
ACL_DATABASE_URL="${DATABASE_URL%/qima_test}/${ACL_DATABASE}"
created_database=0
created_anon=0
created_authenticated=0

cleanup() {
  local status=$?
  trap - EXIT

  if [[ "$created_database" == "1" ]]; then
    psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "DROP DATABASE ${ACL_DATABASE} WITH (FORCE)" >/dev/null || status=1
    remaining="$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_database WHERE datname = '${ACL_DATABASE}'" 2>/dev/null || true)"
    if [[ "$remaining" == "1" ]]; then
      echo "::error::Disposable ACL database was not removed." >&2
      status=1
    fi
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

existing_database="$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "SELECT 1 FROM pg_database WHERE datname = '${ACL_DATABASE}'")"
if [[ "$existing_database" == "1" ]]; then
  echo "::error::Refusing to reuse an existing ${ACL_DATABASE}; no database was modified." >&2
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

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -c "CREATE DATABASE ${ACL_DATABASE} TEMPLATE template0"
created_database=1

psql "$ACL_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/tests/sql/function-execute-acl-regression.sql"
