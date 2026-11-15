#!/usr/bin/env bash
set -euo pipefail

: "\${DATABASE_URL:?DATABASE_URL is required}"
EXPECTED_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test"
if [[ "$DATABASE_URL" != "$EXPECTED_DATABASE_URL" ]]; then
  echo "QA427 requires the disposable loopback qima_test database." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# QA427_FIRST_SESSION_BEGIN
if ! psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 >"$TMP_DIR/first.log" 2>&1 <<'SQL'
BEGIN;
SET application_name = 'qima-qa427-geography-default-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa427_first$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa427-geography-default-committed-replay';
  v_input jsonb := '{"case":"qa427-geography-default-committed-replay"}'::jsonb;
  v_offer_name text := 'QA427 Geography Default Committed Replay Offer';
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_request_hash text;
  v_stored_result jsonb;
  v_idempotency_execution_id uuid;
  v_idempotency_status text;
  v_execution_status text;
  v_execution_input jsonb;
  v_execution_result jsonb;
  v_execution_object_id uuid;
  v_offer_geography text;
  v_event_payload jsonb;
  v_count integer;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_offer_name
  ) THEN
    RAISE EXCEPTION 'QA427 fixture data already exists';
  END IF;

  v_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_offer_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
    p_quantity => 1::numeric,
    p_price => 12::numeric,
    p_currency => 'USD',
    p_conditions => NULL,
    p_market => NULL,
    -- p_geography is intentionally omitted in this first committed session.
    p_attributes => '{}'::jsonb,
    p_documentation_status => NULL,
    p_lifecycle => NULL,
    p_offer_type => 'fixture-offer-type-stable',
    p_pricing_model => 'fixture-pricing-model-stable'
  );

  IF jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA427 first committed request did not return a complete success result: %',
      coalesce(v_result::text, '<SQL NULL>');
  END IF;

  v_execution_id := (v_result->>'executionId')::uuid;
  v_offer_id := (v_result->>'objectId')::uuid;

  SELECT request_hash, execution_id, status, result
  INTO v_request_hash, v_idempotency_execution_id, v_idempotency_status, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF NOT FOUND
     OR v_request_hash IS NULL
     OR v_idempotency_execution_id IS DISTINCT FROM v_execution_id
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_stored_result IS DISTINCT FROM v_result THEN
    RAISE EXCEPTION 'QA427 first committed idempotency record is inconsistent';
  END IF;

  SELECT status, input, result, object_id
  INTO v_execution_status, v_execution_input, v_execution_result, v_execution_object_id
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id AND idempotency_key = v_key AND id = v_execution_id;
  IF NOT FOUND
     OR v_execution_status IS DISTINCT FROM 'COMPLETED'
     OR v_execution_input IS DISTINCT FROM v_input
     OR v_execution_result IS DISTINCT FROM v_result
     OR v_execution_object_id IS DISTINCT FROM v_offer_id THEN
    RAISE EXCEPTION 'QA427 first committed action execution is inconsistent';
  END IF;

  SELECT geography INTO v_offer_geography
  FROM public.offers
  WHERE id = v_offer_id AND name = v_offer_name;
  IF NOT FOUND OR v_offer_geography IS NOT NULL THEN
    RAISE EXCEPTION 'QA427 omitted p_geography did not persist NULL';
  END IF;

  SELECT payload INTO v_event_payload
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id;
  IF NOT FOUND OR v_event_payload IS DISTINCT FROM v_result THEN
    RAISE EXCEPTION 'QA427 first committed success event is inconsistent';
  END IF;

  SELECT count(*) INTO v_count FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF v_count <> 1 THEN RAISE EXCEPTION 'QA427 expected one first-session idempotency row, found %', v_count; END IF;

  SELECT count(*) INTO v_count FROM public.action_executions
  WHERE tenant_id = v_tenant_id AND idempotency_key = v_key;
  IF v_count <> 1 THEN RAISE EXCEPTION 'QA427 expected one first-session execution row, found %', v_count; END IF;

  SELECT count(*) INTO v_count FROM public.offers WHERE id = v_offer_id;
  IF v_count <> 1 THEN RAISE EXCEPTION 'QA427 expected one first-session offer row, found %', v_count; END IF;

  SELECT count(*) INTO v_count FROM public.action_events
  WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 1 THEN RAISE EXCEPTION 'QA427 expected one first-session success event, found %', v_count; END IF;

  RAISE NOTICE 'QA427 FIRST COMMITTED SESSION PASS: backend=%', pg_backend_pid();
END
$qa427_first$;
COMMIT;
SQL
then
  cat "$TMP_DIR/first.log" >&2
  echo "QA427 first committed PostgreSQL session failed." >&2
  exit 1
fi
cat "$TMP_DIR/first.log"
# QA427_FIRST_SESSION_END

# QA427_REPLAY_SESSION_BEGIN
if ! psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 >"$TMP_DIR/replay.log" 2>&1 <<'SQL'
BEGIN;
SET application_name = 'qima-qa427-geography-default-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa427_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa427-geography-default-committed-replay';
  v_input jsonb := '{"case":"qa427-geography-default-committed-replay"}'::jsonb;
  v_offer_name text := 'QA427 Geography Default Committed Replay Offer';
  v_original_hash text;
  v_original_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_replay_result jsonb;
  v_replay_hash text;
  v_idempotency_execution_id uuid;
  v_idempotency_status text;
  v_idempotency_result jsonb;
  v_execution_status text;
  v_execution_input jsonb;
  v_execution_result jsonb;
  v_execution_object_id uuid;
  v_offer_geography text;
  v_event_payload jsonb;
  v_before record;
  v_after record;
BEGIN
  SELECT request_hash, execution_id, status, result
  INTO v_original_hash, v_execution_id, v_idempotency_status, v_original_result
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF NOT FOUND
     OR v_original_hash IS NULL
     OR v_execution_id IS NULL
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_original_result->>'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA427 second session cannot see the committed first-session idempotency record';
  END IF;

  v_offer_id := (v_original_result->>'objectId')::uuid;

  SELECT
    (SELECT count(*)::integer FROM public.idempotency_keys WHERE tenant_id = v_tenant_id AND key = v_key) AS idempotency_count,
    (SELECT count(*)::integer FROM public.action_executions WHERE tenant_id = v_tenant_id AND idempotency_key = v_key) AS execution_count,
    (SELECT count(*)::integer FROM public.offers WHERE id = v_offer_id AND name = v_offer_name) AS offer_count,
    (SELECT count(*)::integer FROM public.action_events WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED') AS event_count
  INTO v_before;
  IF v_before.idempotency_count <> 1
     OR v_before.execution_count <> 1
     OR v_before.offer_count <> 1
     OR v_before.event_count <> 1 THEN
    RAISE EXCEPTION 'QA427 second session did not observe exactly one committed row in each persistence table';
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_offer_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
    p_quantity => 1::numeric,
    p_price => 12::numeric,
    p_currency => 'USD',
    p_conditions => NULL,
    p_market => NULL,
    p_geography => NULL,
    p_attributes => '{}'::jsonb,
    p_documentation_status => NULL,
    p_lifecycle => NULL,
    p_offer_type => 'fixture-offer-type-stable',
    p_pricing_model => 'fixture-pricing-model-stable'
  );

  IF v_replay_result IS DISTINCT FROM v_original_result THEN
    RAISE EXCEPTION 'QA427 explicit-NULL replay in a new committed session changed the original result';
  END IF;

  SELECT request_hash, execution_id, status, result
  INTO v_replay_hash, v_idempotency_execution_id, v_idempotency_status, v_idempotency_result
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF NOT FOUND
     OR v_replay_hash IS DISTINCT FROM v_original_hash
     OR v_idempotency_execution_id IS DISTINCT FROM v_execution_id
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_idempotency_result IS DISTINCT FROM v_original_result THEN
    RAISE EXCEPTION 'QA427 cross-session replay changed the original idempotency record';
  END IF;

  SELECT status, input, result, object_id
  INTO v_execution_status, v_execution_input, v_execution_result, v_execution_object_id
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id AND idempotency_key = v_key AND id = v_execution_id;
  IF NOT FOUND
     OR v_execution_status IS DISTINCT FROM 'COMPLETED'
     OR v_execution_input IS DISTINCT FROM v_input
     OR v_execution_result IS DISTINCT FROM v_original_result
     OR v_execution_object_id IS DISTINCT FROM v_offer_id THEN
    RAISE EXCEPTION 'QA427 cross-session replay changed the original action execution';
  END IF;

  SELECT geography INTO v_offer_geography
  FROM public.offers
  WHERE id = v_offer_id AND name = v_offer_name;
  IF NOT FOUND OR v_offer_geography IS NOT NULL THEN
    RAISE EXCEPTION 'QA427 cross-session replay changed the original offer geography';
  END IF;

  SELECT payload INTO v_event_payload
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id;
  IF NOT FOUND OR v_event_payload IS DISTINCT FROM v_original_result THEN
    RAISE EXCEPTION 'QA427 cross-session replay changed the original success event';
  END IF;

  SELECT
    (SELECT count(*)::integer FROM public.idempotency_keys WHERE tenant_id = v_tenant_id AND key = v_key) AS idempotency_count,
    (SELECT count(*)::integer FROM public.action_executions WHERE tenant_id = v_tenant_id AND idempotency_key = v_key) AS execution_count,
    (SELECT count(*)::integer FROM public.offers WHERE id = v_offer_id AND name = v_offer_name) AS offer_count,
    (SELECT count(*)::integer FROM public.action_events WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED') AS event_count
  INTO v_after;
  IF v_after.idempotency_count IS DISTINCT FROM v_before.idempotency_count
     OR v_after.execution_count IS DISTINCT FROM v_before.execution_count
     OR v_after.offer_count IS DISTINCT FROM v_before.offer_count
     OR v_after.event_count IS DISTINCT FROM v_before.event_count THEN
    RAISE EXCEPTION 'QA427 cross-session replay created duplicate persisted rows';
  END IF;

  RAISE NOTICE 'QA427 PASS: omitted geography default committed in one PostgreSQL session replays explicit NULL in a second session without changing the hash, result, or four persisted records; backend=%', pg_backend_pid();
END
$qa427_replay$;
COMMIT;
SQL
then
  cat "$TMP_DIR/replay.log" >&2
  echo "QA427 second committed PostgreSQL session failed." >&2
  exit 1
fi
cat "$TMP_DIR/replay.log"
# QA427_REPLAY_SESSION_END
