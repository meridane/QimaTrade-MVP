#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1)
PSQL_TUPLE=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t)

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

# Race the same key in two tenants at once, using distinct authenticated users
# and provider actors. The fixture delay makes simultaneous advisory-lock
# ownership observable without relying on elapsed-time thresholds.
"${PSQL[@]}" <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES (
  '50000000-0000-4000-8000-000000000004',
  'Concurrent Intertenant Demand A',
  'published',
  '30000000-0000-4000-8000-000000000001'
);
SQL

call_sql_a=$(cat <<'SQL'
SET application_name = 'qima-intertenant-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-intertenant',
  '{"case":"intertenant-concurrent"}'::jsonb,
  'Concurrent Intertenant Offer A',
  '50000000-0000-4000-8000-000000000004',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  17,
  'USD'
);
SQL
)

call_sql_b=$(cat <<'SQL'
SET application_name = 'qima-intertenant-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000002',
  'fixture-concurrent-intertenant',
  '{"case":"intertenant-concurrent"}'::jsonb,
  'Concurrent Intertenant Offer B',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  2,
  17,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$call_sql_a" > /tmp/qima-intertenant-a.log &
pid_a=$!
"${PSQL_TUPLE[@]}" -c "$call_sql_b" > /tmp/qima-intertenant-b.log &
pid_b=$!

# Both sessions must be inside the fixture delay while holding distinct,
# granted advisory locks. A tenant-agnostic lock would serialize these calls
# and prevent this observation.
lock_snapshot=""
for attempt in $(seq 1 200); do
  lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(DISTINCT concat(l.classid, ':', l.objid, ':', l.objsubid))
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-intertenant-a', 'qima-intertenant-b')
      AND a.state = 'active'
      AND a.wait_event = 'PgSleep'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock'
      AND l.granted;
  " | tr -d '[:space:]')
  if [[ "$lock_snapshot" == "2|2" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$pid_a"
status_a=$?
wait "$pid_b"
status_b=$?
set -e

if [[ "$status_a" -ne 0 || "$status_b" -ne 0 ]]; then
  echo "Inter-tenant concurrent CREATE_OFFER calls failed (A=$status_a, B=$status_b)." >&2
  cat /tmp/qima-intertenant-a.log /tmp/qima-intertenant-b.log >&2
  exit 1
fi

if [[ "$lock_snapshot" != "2|2" ]]; then
  echo "Expected two distinct granted advisory locks to be held during overlapping PgSleep; observed '$lock_snapshot'." >&2
  cat /tmp/qima-intertenant-a.log /tmp/qima-intertenant-b.log >&2
  exit 1
fi
echo "Observed two distinct granted inter-tenant advisory locks concurrently."

# Replay both successful requests after the concurrent first insert. Keep psql
# in tuples-only mode so each file contains only the returned JSONB value.
# Comparing each replay to its own first result proves tenant-local replay;
# cross-comparisons ensure neither tenant receives the other tenant's result.
"${PSQL_TUPLE[@]}" -c "$call_sql_a" > /tmp/qima-intertenant-a-replay.log
"${PSQL_TUPLE[@]}" -c "$call_sql_b" > /tmp/qima-intertenant-b-replay.log

if ! cmp -s /tmp/qima-intertenant-a.log /tmp/qima-intertenant-a-replay.log; then
  echo "Tenant A replay did not return its exact original result." >&2
  diff -u /tmp/qima-intertenant-a.log /tmp/qima-intertenant-a-replay.log >&2 || true
  exit 1
fi
if ! cmp -s /tmp/qima-intertenant-b.log /tmp/qima-intertenant-b-replay.log; then
  echo "Tenant B replay did not return its exact original result." >&2
  diff -u /tmp/qima-intertenant-b.log /tmp/qima-intertenant-b-replay.log >&2 || true
  exit 1
fi
if cmp -s /tmp/qima-intertenant-a.log /tmp/qima-intertenant-b.log; then
  echo "Expected distinct tenant A and tenant B results; received identical results." >&2
  exit 1
fi
if cmp -s /tmp/qima-intertenant-a-replay.log /tmp/qima-intertenant-b.log; then
  echo "Tenant A replay unexpectedly matches tenant B's original result." >&2
  exit 1
fi
if cmp -s /tmp/qima-intertenant-b-replay.log /tmp/qima-intertenant-a.log; then
  echo "Tenant B replay unexpectedly matches tenant A's original result." >&2
  exit 1
fi
echo "CREATE_OFFER inter-tenant replay returned each tenant's exact original result."

"${PSQL[@]}" <<'SQL'
DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected one completed idempotency row per tenant, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-concurrent-intertenant'
      AND actor_id = '30000000-0000-4000-8000-000000000001'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000002'
      AND key = 'fixture-concurrent-intertenant'
      AND actor_id = '30000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'Expected each tenant idempotency row to retain its own actor';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two completed inter-tenant executions, found %', v_count;
  END IF;

  SELECT count(DISTINCT actor_id) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two distinct authenticated actors, found %', v_count;
  END IF;

  SELECT count(DISTINCT request_hash) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected distinct request hashes for the distinct actor/request pairs, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'Concurrent Intertenant Offer A',
    'Concurrent Intertenant Offer B'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two inter-tenant offers, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'Concurrent Intertenant Offer A'
      AND demand_id = '50000000-0000-4000-8000-000000000004'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'Concurrent Intertenant Offer B'
      AND demand_id = '50000000-0000-4000-8000-000000000001'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'Inter-tenant offers were not created for their expected fixture actors and demands';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.idempotency_key = 'fixture-concurrent-intertenant'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected one success event per concurrent tenant execution, found %', v_count;
  END IF;

  SELECT count(DISTINCT e.tenant_id) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.idempotency_key = 'fixture-concurrent-intertenant'
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected success events in both tenants, found % distinct tenants', v_count;
  END IF;
END
$$;

SELECT 'CREATE_OFFER inter-tenant concurrency assertions passed' AS result;
SQL

# Race two first-time requests in the same tenant with the same idempotency
# key but different effective request hashes (only the price differs). The
# advisory lock must serialize them: one succeeds and the other is rejected.
call_sql_conflict_a=$(cat <<'SQL'
SET application_name = 'qima-same-tenant-conflict-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-same-tenant-conflict',
  '{"case":"same-tenant-concurrent-conflict"}'::jsonb,
  'Concurrent Same-Tenant Conflict Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  20,
  'USD'
);
SQL
)

call_sql_conflict_b=$(cat <<'SQL'
SET application_name = 'qima-same-tenant-conflict-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-same-tenant-conflict',
  '{"case":"same-tenant-concurrent-conflict"}'::jsonb,
  'Concurrent Same-Tenant Conflict Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  21,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$call_sql_conflict_a" > /tmp/qima-same-tenant-conflict-a.log 2>&1 &
pid_conflict_a=$!
"${PSQL_TUPLE[@]}" -c "$call_sql_conflict_b" > /tmp/qima-same-tenant-conflict-b.log 2>&1 &
pid_conflict_b=$!

# The fixture's existing 0.5 s insert delay gives the second session time to
# queue on the same advisory lock. Require one granted and one waiting session
# for one lock key, rather than inferring overlap from elapsed time.
conflict_lock_snapshot=""
for attempt in $(seq 1 200); do
  conflict_lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      (count(DISTINCT a.application_name) FILTER (WHERE l.granted))::text || '|' ||
      (count(DISTINCT a.application_name) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      ))::text || '|' ||
      count(DISTINCT concat(l.classid, ':', l.objid, ':', l.objsubid))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN (
      'qima-same-tenant-conflict-a',
      'qima-same-tenant-conflict-b'
    )
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$conflict_lock_snapshot" == "1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$pid_conflict_a"
status_conflict_a=$?
wait "$pid_conflict_b"
status_conflict_b=$?
set -e

if [[ "$status_conflict_a" -eq 0 && "$status_conflict_b" -ne 0 ]]; then
  success_log=/tmp/qima-same-tenant-conflict-a.log
  failure_log=/tmp/qima-same-tenant-conflict-b.log
  winner_price=20
elif [[ "$status_conflict_b" -eq 0 && "$status_conflict_a" -ne 0 ]]; then
  success_log=/tmp/qima-same-tenant-conflict-b.log
  failure_log=/tmp/qima-same-tenant-conflict-a.log
  winner_price=21
else
  echo "Expected exactly one successful same-tenant request and one rejected request (A=$status_conflict_a, B=$status_conflict_b)." >&2
  cat /tmp/qima-same-tenant-conflict-a.log /tmp/qima-same-tenant-conflict-b.log >&2
  exit 1
fi

if [[ "$conflict_lock_snapshot" != "1|1|1" ]]; then
  echo "Expected one granted and one waiting same-key advisory lock for one lock key; observed '$conflict_lock_snapshot'." >&2
  cat /tmp/qima-same-tenant-conflict-a.log /tmp/qima-same-tenant-conflict-b.log >&2
  exit 1
fi

if ! grep -Fq "IDEMPOTENCY_KEY_REUSE" "$failure_log"; then
  echo "The losing same-tenant request did not fail with IDEMPOTENCY_KEY_REUSE." >&2
  cat "$failure_log" >&2
  exit 1
fi

if [[ ! -s "$success_log" ]]; then
  echo "The successful same-tenant request did not return a result." >&2
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-same-tenant-conflict'
    AND status = 'COMPLETED';
" > /tmp/qima-same-tenant-conflict-stored-result.log

if ! cmp -s "$success_log" /tmp/qima-same-tenant-conflict-stored-result.log; then
  echo "Successful same-tenant response does not match the stored idempotency result." >&2
  diff -u "$success_log" /tmp/qima-same-tenant-conflict-stored-result.log >&2 || true
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa61$
DECLARE
  v_count integer;
  v_price numeric;
  v_request_hash text;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-same-tenant-conflict';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one idempotency row after conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-same-tenant-conflict'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one completed idempotency row after conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-same-tenant-conflict';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one execution for the conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-same-tenant-conflict'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one completed execution for the conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Concurrent Same-Tenant Conflict Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one offer after conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT o.price, ik.request_hash
  INTO v_price, v_request_hash
  FROM public.idempotency_keys ik
  JOIN public.offers o ON o.id = (ik.result->>'objectId')::uuid
  WHERE ik.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND ik.key = 'fixture-concurrent-same-tenant-conflict'
    AND ik.status = 'COMPLETED';

  IF v_price NOT IN (20, 21) THEN
    RAISE EXCEPTION 'Expected the winning offer price to be 20 or 21, found %', v_price;
  END IF;

  IF v_request_hash IS DISTINCT FROM md5(jsonb_build_object(
    'input', '{"case":"same-tenant-concurrent-conflict"}'::jsonb,
    'name', 'Concurrent Same-Tenant Conflict Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', v_price,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  )::text) THEN
    RAISE EXCEPTION 'Stored request hash does not match the winning offer price %', v_price;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-concurrent-same-tenant-conflict'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one success event for the winning request, found %', v_count;
  END IF;
END
$qa61$;

echo "CREATE_OFFER same-tenant concurrent conflicting-hash assertions passed (winning price: $winner_price)."
