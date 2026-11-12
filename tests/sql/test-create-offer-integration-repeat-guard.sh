#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to the disposable qima_test database}"

if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "ERROR: refusing repeat-run verification outside loopback qima_test; no database connection was attempted." >&2
  exit 2
fi

REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]]; then
  echo "ERROR: psql is required for the qima_test repeat-run verification." >&2
  exit 127
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
CALLS="$TEMP_DIR/psql-calls.log"
OUTPUT="$TEMP_DIR/runner-output.log"
mkdir -p "$MOCK_BIN"

snapshot_sql=$(cat <<'QIMA_QA363_SNAPSHOT'
SELECT concat_ws('|',
  current_database(),
  (
    SELECT md5(coalesce(string_agg(n.nspname::text || ':' || c.relkind::text || ':' || c.relname::text,
                                   E'\n' ORDER BY n.nspname, c.relkind, c.relname), ''))
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg_toast%'
      AND n.nspname NOT LIKE 'pg_temp_%'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.dt_tenants AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.dt_memberships AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.profiles AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.product_masters AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.demands AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.action_definitions AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.idempotency_keys AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.action_executions AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.offers AS t
  ),
  (
    SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\n' ORDER BY to_jsonb(t)::text), ''))
    FROM public.action_events AS t
  )
);
QIMA_QA363_SNAPSHOT
)

snapshot() {
  "$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$snapshot_sql"
}

before_snapshot="$(snapshot)"
if [[ -z "$before_snapshot" || "$before_snapshot" != qima_test\|* ]]; then
  echo "ERROR: repeat-run verification did not observe the expected initialized qima_test database." >&2
  exit 1
fi

cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *"create-offer-bootstrap-preflight.sql"* ]]; then
  printf 'query\n' >> "$PSQL_CALL_LOG"
elif [[ " $* " == *" -c "* ]]; then
  printf 'query\n' >> "$PSQL_CALL_LOG"
elif [[ " $* " == *" -f "* ]]; then
  printf 'file\n' >> "$PSQL_CALL_LOG"
else
  printf 'other\n' >> "$PSQL_CALL_LOG"
fi
exec "$REAL_PSQL" "$@"
PSQL
chmod +x "$MOCK_BIN/psql"

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" \
  REAL_PSQL="$REAL_PSQL" \
  PSQL_CALL_LOG="$CALLS" \
  DATABASE_URL="$DATABASE_URL" \
  bash "$RUNNER" > "$OUTPUT" 2>&1
runner_status=$?
set -e

if [[ "$runner_status" -ne 3 ]]; then
  echo "ERROR: second CREATE_OFFER runner invocation returned $runner_status; expected preflight refusal exit 3." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

grep -Fq "qima_test already contains application catalog objects, database-scoped settings, default ACLs, or non-default schemas" "$OUTPUT" || {
  echo "ERROR: second runner invocation failed without the QA366 non-empty-database diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
}

if grep -Fq "postgres:postgres" "$OUTPUT"; then
  echo "ERROR: second runner invocation exposed DATABASE_URL credentials." >&2
  exit 1
fi

if [[ "$(cat "$CALLS")" != "query" ]]; then
  echo "ERROR: second runner invocation performed more than its single read-only preflight psql call: $(cat "$CALLS")" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

after_snapshot="$(snapshot)"
if [[ "$after_snapshot" != "$before_snapshot" ]]; then
  echo "ERROR: initialized qima_test schema or fixture data changed during the rejected second runner invocation." >&2
  diff -u <(printf '%s\n' "$before_snapshot") <(printf '%s\n' "$after_snapshot") >&2 || true
  exit 1
fi

echo "QA363 passed: the second CREATE_OFFER runner invocation was rejected after one read-only preflight query; public schema inventory and all ten fixture-table data digests remained unchanged."
