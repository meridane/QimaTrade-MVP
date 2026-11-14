\set ON_ERROR_STOP on

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

-- QA412: omitting p_market uses its declared NULL::text default.
-- Replaying the same request with explicit NULL must be an exact replay.
DO $qa412_market_default_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa412-market-default-replay';
  v_input jsonb := '{"case":"qa412-market-default-replay"}'::jsonb;
  v_offer_name text := 'QA412 Market Default Replay Offer';
  v_first_result jsonb;
  v_replay_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_original_hash text;
  v_replay_hash text;
  v_idempotency_execution_id uuid;
  v_idempotency_status text;
  v_idempotency_result jsonb;
  v_execution_status text;
  v_execution_input jsonb;
  v_execution_result jsonb;
  v_execution_object_id uuid;
  v_offer_market text;
  v_event_payload jsonb;
  v_after_first record;
  v_after_replay record;
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
    RAISE EXCEPTION 'QA412 fixture data already exists';
  END IF;

  -- First call intentionally omits p_conditions; PostgreSQL applies the function default.
  v_first_result := public.execute_create_offer_v1(
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
    -- p_market intentionally omitted so PostgreSQL applies its declared default.
    p_geography => NULL,
    p_attributes => '{}'::jsonb,
    p_documentation_status => NULL,
    p_lifecycle => NULL,
    p_offer_type => 'fixture-offer-type-stable',
    p_pricing_model => 'fixture-pricing-model-stable'
  );

  IF jsonb_typeof(v_first_result) IS DISTINCT FROM 'object'
     OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_first_result->>'executionId', '') IS NULL
     OR nullif(v_first_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA412 omitted-default request did not return a complete success result: %',
      coalesce(v_first_result::text, '<SQL NULL>');
  END IF;

  v_execution_id := (v_first_result->>'executionId')::uuid;
  v_offer_id := (v_first_result->>'objectId')::uuid;

  SELECT request_hash, execution_id, status, result
  INTO v_original_hash, v_idempotency_execution_id, v_idempotency_status, v_idempotency_result
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF NOT FOUND
     OR v_original_hash IS NULL
     OR v_idempotency_execution_id IS DISTINCT FROM v_execution_id
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_idempotency_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA412 initial idempotency record does not match the omitted-default request';
  END IF;

  SELECT status, input, result, object_id
  INTO v_execution_status, v_execution_input, v_execution_result, v_execution_object_id
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id AND idempotency_key = v_key AND id = v_execution_id;
  IF NOT FOUND
     OR v_execution_status IS DISTINCT FROM 'COMPLETED'
     OR v_execution_input IS DISTINCT FROM v_input
     OR v_execution_result IS DISTINCT FROM v_first_result
     OR v_execution_object_id IS DISTINCT FROM v_offer_id THEN
    RAISE EXCEPTION 'QA412 initial action execution does not match the omitted-default request';
  END IF;

  SELECT market INTO v_offer_market
  FROM public.offers
  WHERE id = v_offer_id AND name = v_offer_name;
  IF NOT FOUND OR v_offer_market IS NOT NULL THEN
    RAISE EXCEPTION 'QA412 omitted p_market did not persist NULL from the declared text default';
  END IF;

  SELECT payload INTO v_event_payload
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id;
  IF NOT FOUND OR v_event_payload IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA412 original success event does not match the omitted-default result';
  END IF;

  SELECT
    (SELECT count(*)::integer FROM public.idempotency_keys WHERE tenant_id = v_tenant_id AND key = v_key) AS idempotency_count,
    (SELECT count(*)::integer FROM public.action_executions WHERE tenant_id = v_tenant_id AND idempotency_key = v_key) AS execution_count,
    (SELECT count(*)::integer FROM public.offers WHERE id = v_offer_id) AS offer_count,
    (SELECT count(*)::integer FROM public.action_events WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED') AS event_count
  INTO v_after_first;
  IF v_after_first.idempotency_count <> 1
     OR v_after_first.execution_count <> 1
     OR v_after_first.offer_count <> 1
     OR v_after_first.event_count <> 1 THEN
    RAISE EXCEPTION 'QA412 initial request did not persist exactly one idempotency row, execution, offer and success event';
  END IF;

  -- Replay supplies the exact declared default explicitly; no effective input changes.
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

  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA412 explicit NULL replay did not return the exact original result';
  END IF;

  SELECT
    (SELECT count(*)::integer FROM public.idempotency_keys WHERE tenant_id = v_tenant_id AND key = v_key) AS idempotency_count,
    (SELECT count(*)::integer FROM public.action_executions WHERE tenant_id = v_tenant_id AND idempotency_key = v_key) AS execution_count,
    (SELECT count(*)::integer FROM public.offers WHERE id = v_offer_id) AS offer_count,
    (SELECT count(*)::integer FROM public.action_events WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED') AS event_count
  INTO v_after_replay;
  IF v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count
     OR v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count
     OR v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count
     OR v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count THEN
    RAISE EXCEPTION 'QA412 equivalent explicit-default replay created duplicate persisted rows';
  END IF;

  SELECT request_hash, execution_id, status, result
  INTO v_replay_hash, v_idempotency_execution_id, v_idempotency_status, v_idempotency_result
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF NOT FOUND
     OR v_replay_hash IS DISTINCT FROM v_original_hash
     OR v_idempotency_execution_id IS DISTINCT FROM v_execution_id
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_idempotency_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA412 explicit-default replay changed the original idempotency record';
  END IF;

  SELECT status, input, result, object_id
  INTO v_execution_status, v_execution_input, v_execution_result, v_execution_object_id
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id AND idempotency_key = v_key AND id = v_execution_id;
  IF NOT FOUND
     OR v_execution_status IS DISTINCT FROM 'COMPLETED'
     OR v_execution_input IS DISTINCT FROM v_input
     OR v_execution_result IS DISTINCT FROM v_first_result
     OR v_execution_object_id IS DISTINCT FROM v_offer_id THEN
    RAISE EXCEPTION 'QA412 explicit-default replay changed the original action execution';
  END IF;

  SELECT market INTO v_offer_market
  FROM public.offers
  WHERE id = v_offer_id AND name = v_offer_name;
  IF NOT FOUND OR v_offer_market IS NOT NULL THEN
    RAISE EXCEPTION 'QA412 explicit-default replay changed the original offer market';
  END IF;

  SELECT payload INTO v_event_payload
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id;
  IF NOT FOUND OR v_event_payload IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA412 explicit-default replay changed the original success event';
  END IF;

  RAISE NOTICE 'QA412 PASS: omitting p_conditions applies the declared NULL::text default and exactly replays an explicit NULL request without duplicate persisted state';
END
$qa412_market_default_replay$;
