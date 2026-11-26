\set ON_ERROR_STOP on

-- QA479: characterize the terminal replay fallback only in the disposable qima_test fixture.
-- The transaction is rolled back; this does not inspect or modify any Supabase project.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa479_create$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.execute_create_offer_v1(
    p_tenant_id => '10000000-0000-4000-8000-000000000001'::uuid,
    p_idempotency_key => 'qa479-terminal-null-result',
    p_input => '{"case":"qa479","purpose":"terminal-null-result-characterization"}'::jsonb,
    p_name => 'QA479 terminal null-result characterization',
    p_demand_id => '50000000-0000-4000-8000-000000000001'::uuid,
    p_product_master_id => '40000000-0000-4000-8000-000000000001'::uuid,
    p_provider_actor_id => '30000000-0000-4000-8000-000000000001'::uuid,
    p_quantity => 4::numeric,
    p_price => 25::numeric,
    p_currency => 'USD'
  );

  IF jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA479 initial CREATE_OFFER call did not return a complete succeeded result: %', v_result;
  END IF;
END
$qa479_create$;

-- Return to the disposable fixture owner so the test can inject the legacy row state.
RESET ROLE;

DO $qa479_nullify$
DECLARE
  v_result_nullable text;
  v_updated_rows integer;
BEGIN
  SELECT is_nullable
  INTO v_result_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'idempotency_keys'
    AND column_name = 'result';

  IF v_result_nullable IS DISTINCT FROM 'YES' THEN
    RAISE EXCEPTION 'QA479 fixture result column must be nullable; observed is_nullable=%', v_result_nullable;
  END IF;

  UPDATE public.idempotency_keys
  SET result = NULL
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'::uuid
    AND key = 'qa479-terminal-null-result'
    AND status = 'COMPLETED'
    AND result IS NOT NULL;

  GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
  IF v_updated_rows <> 1 THEN
    RAISE EXCEPTION 'QA479 expected to null exactly one completed fixture result; updated % rows', v_updated_rows;
  END IF;
END
$qa479_nullify$;

SET LOCAL ROLE authenticated;

DO $qa479_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001'::uuid;
  v_key text := 'qa479-terminal-null-result';
  v_input jsonb := '{"case":"qa479","purpose":"terminal-null-result-characterization"}'::jsonb;
  v_name text := 'QA479 terminal null-result characterization';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001'::uuid;
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001'::uuid;
  v_provider_actor_id uuid := '30000000-0000-4000-8000-000000000001'::uuid;
  v_execution_id uuid;
  v_original_result jsonb;
  v_object_id uuid;
  v_replay_result jsonb;
  v_replay_key_count integer;
  v_idempotency_status text;
  v_idempotency_result jsonb;
  v_idempotency_execution_id uuid;
  v_execution_status text;
  v_execution_result jsonb;
  v_execution_object_id uuid;
  v_idempotency_before bigint;
  v_executions_before bigint;
  v_offers_before bigint;
  v_events_before bigint;
  v_idempotency_after bigint;
  v_executions_after bigint;
  v_offers_after bigint;
  v_events_after bigint;
  v_count bigint;
BEGIN
  SELECT k.execution_id, e.result, e.object_id
  INTO v_execution_id, v_original_result, v_object_id
  FROM public.idempotency_keys k
  JOIN public.action_executions e ON e.id = k.execution_id
  WHERE k.tenant_id = v_tenant_id
    AND k.key = v_key
    AND k.status = 'COMPLETED';

  IF NOT FOUND
     OR v_execution_id IS NULL
     OR v_original_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_object_id IS NULL THEN
    RAISE EXCEPTION 'QA479 expected the original completed execution and succeeded result to remain available';
  END IF;

  SELECT count(*) INTO v_idempotency_before FROM public.idempotency_keys;
  SELECT count(*) INTO v_executions_before FROM public.action_executions;
  SELECT count(*) INTO v_offers_before FROM public.offers;
  SELECT count(*) INTO v_events_before FROM public.action_events;

  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_name,
    p_demand_id => v_demand_id,
    p_product_master_id => v_product_master_id,
    p_provider_actor_id => v_provider_actor_id,
    p_quantity => 4::numeric,
    p_price => 25::numeric,
    p_currency => 'USD'
  );

  IF jsonb_typeof(v_replay_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'QA479 expected a JSON object from the current NULL-result fallback; observed %', v_replay_result;
  END IF;

  SELECT count(*) INTO v_replay_key_count
  FROM jsonb_object_keys(v_replay_result);

  IF v_replay_result->>'status' IS DISTINCT FROM 'completed'
     OR v_replay_result->>'executionId' IS DISTINCT FROM v_execution_id::text
     OR v_replay_key_count <> 2
     OR v_replay_result ? 'objectId'
     OR v_replay_result ? 'result' THEN
    RAISE EXCEPTION 'QA479 expected the current NULL-result fallback shape {status: completed, executionId}; observed %', v_replay_result;
  END IF;

  SELECT status, result, execution_id
  INTO v_idempotency_status, v_idempotency_result, v_idempotency_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;

  IF NOT FOUND
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_idempotency_result IS NOT NULL
     OR v_idempotency_execution_id IS DISTINCT FROM v_execution_id THEN
    RAISE EXCEPTION 'QA479 replay unexpectedly changed the terminal idempotency row';
  END IF;

  SELECT status, result, object_id
  INTO v_execution_status, v_execution_result, v_execution_object_id
  FROM public.action_executions
  WHERE id = v_execution_id AND tenant_id = v_tenant_id;

  IF NOT FOUND
     OR v_execution_status IS DISTINCT FROM 'COMPLETED'
     OR v_execution_result IS DISTINCT FROM v_original_result
     OR v_execution_object_id IS DISTINCT FROM v_object_id THEN
    RAISE EXCEPTION 'QA479 replay unexpectedly changed the original action execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_object_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA479 expected the original offer to remain exactly once, found % rows', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND payload = v_original_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA479 expected the original success event to remain exactly once, found % rows', v_count;
  END IF;

  SELECT count(*) INTO v_idempotency_after FROM public.idempotency_keys;
  SELECT count(*) INTO v_executions_after FROM public.action_executions;
  SELECT count(*) INTO v_offers_after FROM public.offers;
  SELECT count(*) INTO v_events_after FROM public.action_events;

  IF v_idempotency_after IS DISTINCT FROM v_idempotency_before
     OR v_executions_after IS DISTINCT FROM v_executions_before
     OR v_offers_after IS DISTINCT FROM v_offers_before
     OR v_events_after IS DISTINCT FROM v_events_before THEN
    RAISE EXCEPTION 'QA479 replay created additional persisted rows';
  END IF;

  RAISE NOTICE 'QA479 CHARACTERIZATION PASS: disposable fixture permits COMPLETED with SQL NULL result; replay currently returns status=completed plus executionId only, without duplicate writes. This is not an approved public contract.';
END
$qa479_replay$;

ROLLBACK;


-- QA483: characterize the FAILED terminal fallback with a coherent synthetic row.
-- Start a fresh transaction because QA479 deliberately rolled its own transaction back.
BEGIN;
-- The row is inserted only in disposable qima_test and the enclosing transaction rolls back.
-- This verifies the SQL branch shape; it does not establish that such rows exist in Production.
RESET ROLE;

DO $qa483_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid;
  v_request_hash text;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001'::uuid;
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001'::uuid;
  v_key text := 'qa483-failed-terminal-null-result';
  v_input jsonb := '{"case":"qa483","purpose":"failed-terminal-null-result-characterization"}'::jsonb;
  v_name text := 'QA483 failed terminal null-result characterization';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001'::uuid;
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001'::uuid;
BEGIN
  SELECT id
  INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published'
  LIMIT 1;

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'QA483 requires the published CREATE_OFFER v1 fixture definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
    'providerActorId', v_actor_id,
    'quantity', 4::numeric,
    'price', 25::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  INSERT INTO public.action_executions(
    action_id,
    action_version,
    actor_id,
    object_type,
    object_id,
    idempotency_key,
    status,
    input,
    result,
    tenant_id
  )
  VALUES (
    v_action_id,
    1,
    v_actor_id,
    'Offer',
    NULL,
    v_key,
    'FAILED',
    v_input,
    NULL,
    v_tenant_id
  )
  RETURNING id INTO v_execution_id;

  INSERT INTO public.idempotency_keys(
    key,
    action_id,
    actor_id,
    request_hash,
    execution_id,
    status,
    result,
    tenant_id,
    completed_at
  )
  VALUES (
    v_key,
    v_action_id,
    v_actor_id,
    v_request_hash,
    v_execution_id,
    'FAILED',
    NULL,
    v_tenant_id,
    now()
  );

  RAISE NOTICE 'QA483 seeded one coherent FAILED/NULL-result idempotency fixture row in the disposable transaction';
END
$qa483_seed$;

SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa483_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001'::uuid;
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001'::uuid;
  v_key text := 'qa483-failed-terminal-null-result';
  v_input jsonb := '{"case":"qa483","purpose":"failed-terminal-null-result-characterization"}'::jsonb;
  v_name text := 'QA483 failed terminal null-result characterization';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001'::uuid;
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001'::uuid;
  v_execution_id uuid;
  v_replay_result jsonb;
  v_replay_key_count integer;
  v_idempotency_status text;
  v_idempotency_result jsonb;
  v_idempotency_execution_id uuid;
  v_execution_status text;
  v_execution_result jsonb;
  v_execution_object_id uuid;
  v_idempotency_before bigint;
  v_executions_before bigint;
  v_offers_before bigint;
  v_events_before bigint;
  v_idempotency_after bigint;
  v_executions_after bigint;
  v_offers_after bigint;
  v_events_after bigint;
BEGIN
  SELECT execution_id
  INTO v_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'FAILED'
    AND result IS NULL;

  IF NOT FOUND OR v_execution_id IS NULL THEN
    RAISE EXCEPTION 'QA483 expected the seeded FAILED/NULL-result idempotency row';
  END IF;

  SELECT count(*) INTO v_idempotency_before FROM public.idempotency_keys;
  SELECT count(*) INTO v_executions_before FROM public.action_executions;
  SELECT count(*) INTO v_offers_before FROM public.offers;
  SELECT count(*) INTO v_events_before FROM public.action_events;

  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_name,
    p_demand_id => v_demand_id,
    p_product_master_id => v_product_master_id,
    p_provider_actor_id => v_actor_id,
    p_quantity => 4::numeric,
    p_price => 25::numeric,
    p_currency => 'USD'
  );

  IF jsonb_typeof(v_replay_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'QA483 expected a JSON object from the FAILED NULL-result fallback; observed %', v_replay_result;
  END IF;

  SELECT count(*) INTO v_replay_key_count
  FROM jsonb_object_keys(v_replay_result);

  IF v_replay_result->>'status' IS DISTINCT FROM 'failed'
     OR v_replay_result->>'executionId' IS DISTINCT FROM v_execution_id::text
     OR v_replay_key_count <> 2
     OR v_replay_result ? 'objectId'
     OR v_replay_result ? 'result' THEN
    RAISE EXCEPTION 'QA483 expected the FAILED NULL-result fallback shape {status: failed, executionId}; observed %', v_replay_result;
  END IF;

  SELECT status, result, execution_id
  INTO v_idempotency_status, v_idempotency_result, v_idempotency_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;

  IF NOT FOUND
     OR v_idempotency_status IS DISTINCT FROM 'FAILED'
     OR v_idempotency_result IS NOT NULL
     OR v_idempotency_execution_id IS DISTINCT FROM v_execution_id THEN
    RAISE EXCEPTION 'QA483 replay unexpectedly changed the terminal idempotency row';
  END IF;

  SELECT status, result, object_id
  INTO v_execution_status, v_execution_result, v_execution_object_id
  FROM public.action_executions
  WHERE id = v_execution_id AND tenant_id = v_tenant_id;

  IF NOT FOUND
     OR v_execution_status IS DISTINCT FROM 'FAILED'
     OR v_execution_result IS NOT NULL
     OR v_execution_object_id IS NOT NULL THEN
    RAISE EXCEPTION 'QA483 replay unexpectedly changed the FAILED action execution';
  END IF;

  SELECT count(*) INTO v_idempotency_after FROM public.idempotency_keys;
  SELECT count(*) INTO v_executions_after FROM public.action_executions;
  SELECT count(*) INTO v_offers_after FROM public.offers;
  SELECT count(*) INTO v_events_after FROM public.action_events;

  IF v_idempotency_after IS DISTINCT FROM v_idempotency_before
     OR v_executions_after IS DISTINCT FROM v_executions_before
     OR v_offers_after IS DISTINCT FROM v_offers_before
     OR v_events_after IS DISTINCT FROM v_events_before THEN
    RAISE EXCEPTION 'QA483 FAILED replay created additional persisted rows';
  END IF;

  RAISE NOTICE 'QA483 CHARACTERIZATION PASS: coherent disposable FAILED/NULL-result row replays as status=failed plus executionId only, without additional writes.';
END
$qa483_replay$;

ROLLBACK;
