\set ON_ERROR_STOP on

-- QA430: PostgreSQL must replay the same CREATE_OFFER request when UUID-typed
-- RPC arguments differ only in textual case, provided p_input uses the route's
-- canonical lower-case UUID strings. This runs only in the disposable qima_test DB.

INSERT INTO public.product_masters(id, code, name, canonical_name, status)
VALUES (
  'abcdef12-3456-4abc-8def-abcdef123456',
  'QA430-UUID-CASE',
  'QA430 UUID Case Product',
  'QA430 UUID Case Product',
  'active'
);

INSERT INTO public.demands(id, name, demand_status, requester_actor_id)
VALUES (
  'fedcba98-7654-4fed-9cba-fedcba987654',
  'QA430 UUID Case Demand',
  'published',
  '30000000-0000-4000-8000-000000000002'
);

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa430_uuid_case_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_demand_id uuid := 'fedcba98-7654-4fed-9cba-fedcba987654';
  v_product_master_id uuid := 'abcdef12-3456-4abc-8def-abcdef123456';
  v_provider_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa430-uuid-case-replay';
  v_name text := 'QA430 UUID Case Replay Offer';
  v_input jsonb;
  v_first_result jsonb;
  v_retry_result jsonb;
  v_expected_hash text;
  v_stored_hash text;
  v_stored_execution_id uuid;
  v_stored_status text;
  v_stored_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_count integer;
BEGIN
  v_input := jsonb_build_object(
    'name', v_name,
    'demandId', lower(v_demand_id::text),
    'productMasterId', lower(v_product_master_id::text),
    'providerActorId', lower(v_provider_actor_id::text),
    'quantity', 4,
    'price', 25,
    'currency', 'USD',
    'pricingModel', 'fixed',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', 'draft',
    'offerType', 'supplier_offer'
  );

  IF v_input->>'demandId' IS DISTINCT FROM lower(v_demand_id::text)
     OR v_input->>'productMasterId' IS DISTINCT FROM lower(v_product_master_id::text) THEN
    RAISE EXCEPTION 'QA430 fixture input must use canonical lower-case UUID strings';
  END IF;

  -- First call: PostgreSQL parses uppercase UUID text into the same typed UUID values.
  v_first_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_name,
    p_demand_id => upper(v_demand_id::text)::uuid,
    p_product_master_id => upper(v_product_master_id::text)::uuid,
    p_provider_actor_id => v_provider_actor_id,
    p_quantity => 4::numeric,
    p_price => 25::numeric,
    p_currency => 'USD',
    p_conditions => NULL,
    p_market => NULL,
    p_geography => NULL,
    p_attributes => '{}'::jsonb,
    p_documentation_status => NULL,
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer',
    p_pricing_model => 'fixed'
  );

  IF jsonb_typeof(v_first_result) IS DISTINCT FROM 'object'
     OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_first_result->>'executionId', '') IS NULL
     OR nullif(v_first_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA430 first UUID-case request did not return a complete success result: %', v_first_result;
  END IF;

  v_execution_id := (v_first_result->>'executionId')::uuid;
  v_offer_id := (v_first_result->>'objectId')::uuid;

  -- Retry: the same UUID values are passed in their canonical lower-case form.
  v_retry_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_name,
    p_demand_id => v_demand_id,
    p_product_master_id => v_product_master_id,
    p_provider_actor_id => v_provider_actor_id,
    p_quantity => 4::numeric,
    p_price => 25::numeric,
    p_currency => 'USD',
    p_conditions => NULL,
    p_market => NULL,
    p_geography => NULL,
    p_attributes => '{}'::jsonb,
    p_documentation_status => NULL,
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer',
    p_pricing_model => 'fixed'
  );

  IF v_retry_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA430 lower-case UUID retry did not replay the exact original result';
  END IF;

  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
    'providerActorId', v_provider_actor_id,
    'quantity', 4::numeric,
    'price', 25::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL::text,
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  SELECT request_hash, execution_id, status, result
  INTO v_stored_hash, v_stored_execution_id, v_stored_status, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key;

  IF NOT FOUND
     OR v_stored_hash IS DISTINCT FROM v_expected_hash
     OR v_stored_execution_id IS DISTINCT FROM v_execution_id
     OR v_stored_status IS DISTINCT FROM 'COMPLETED'
     OR v_stored_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA430 stored idempotency record does not match the canonical request hash and result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA430 expected exactly one idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND idempotency_key = v_key
    AND id = v_execution_id
    AND status = 'COMPLETED'
    AND input = v_input
    AND result = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA430 expected exactly one completed execution matching the canonical input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = v_name
    AND demand_id = v_demand_id
    AND product_master_id = v_product_master_id
    AND provider_actor_id = v_provider_actor_id
    AND quantity = 4
    AND price = 25
    AND currency = 'USD';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA430 expected exactly one offer matching the UUID-case request, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA430 expected exactly one success event matching the replayed result, found %', v_count;
  END IF;

  RAISE NOTICE 'QA430 PASS: uppercase and lowercase typed UUID arguments replay one canonical request with one idempotency row, execution, offer and success event';
END
$qa430_uuid_case_replay$;
