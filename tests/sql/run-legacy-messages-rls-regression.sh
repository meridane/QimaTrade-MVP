#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/tests/sql/legacy-messages-rls-regression.sql"
