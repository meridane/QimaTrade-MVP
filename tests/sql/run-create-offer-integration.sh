#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1)

# This script is only intended for the ephemeral PostgreSQL service in CI.
# Never point DATABASE_URL at Supabase production.
"${PSQL[@]}" -f "$ROOT/tests/sql/fixtures/create-offer-schema.sql"
"${PSQL[@]}" -f "$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
"${PSQL[@]}" -f "$ROOT/supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql"
"${PSQL[@]}" -f "$ROOT/tests/sql/create-offer-runtime.sql"

# Race two first-time requests with the same tenant/key. The function's advisory
# transaction lock should make the second request replay the first result.
call_sql="
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-first-insert',
  '{\"case\":\"concurrent\"}'::jsonb,
  'Concurrent Fixture Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  21,
  'USD'
);
"
"${PSQL[@]}" -c "$call_sql" > /tmp/qima-concurrent-1.log &
pid1=$!
"${PSQL[@]}" -c "$call_sql" > /tmp/qima-concurrent-2.log &
pid2=$!
wait "$pid1"
wait "$pid2"

"${PSQL[@]}" <<'SQL'
DO $$
DECLARE
  key_rows integer;
  execution_rows integer;
  offer_rows integer;
BEGIN
  SELECT count(*) INTO key_rows
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-first-insert';
  IF key_rows <> 1 THEN RAISE EXCEPTION 'Expected one idempotency row for concurrent calls, got %', key_rows; END IF;

  SELECT count(*) INTO execution_rows
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-first-insert'
    AND status = 'COMPLETED';
  IF execution_rows <> 1 THEN RAISE EXCEPTION 'Expected one completed execution for concurrent calls, got %', execution_rows; END IF;

  SELECT count(*) INTO offer_rows
  FROM public.offers
  WHERE name = 'Concurrent Fixture Offer';
  IF offer_rows <> 1 THEN RAISE EXCEPTION 'Expected one offer for concurrent calls, got %', offer_rows; END IF;
END
$$;
SELECT 'CREATE_OFFER concurrency assertions passed' AS result;
SQL
