\set ON_ERROR_STOP on
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

-- Additional valid synthetic references for one-field idempotency retries.
-- These rows exist only in the disposable PostgreSQL fixture used by CI.
INSERT INTO public.product_masters (id, code, name, canonical_name, status)
VALUES (
  '40000000-0000-4000-8000-000000000002',
  'FIXTURE-2',
  'Fixture Product Alternate',
  'Fixture Product Alternate',
  'active'
);

INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000002',
    'Fixture Demand Alternate',
    'published',
    '30000000-0000-4000-8000-000000000002'
  ),
  (
    '50000000-0000-4000-8000-000000000003',
    'Tenant Scope Fixture Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  );

SET ROLE authenticated;

DO $$
DECLARE
  first_result jsonb;
  retry_result jsonb;
  v_count integer;
BEGIN
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-1',
    '{"case":"same-payload"}'::jsonb,
    'Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected public result status succeeded, got %', first_result;
  END IF;

  retry_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-1',
    '{"case":"same-payload"}'::jsonb,
    'Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );
  IF retry_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'Identical retry did not return the same result';
  END IF;

  SELECT count(*) INTO v_count FROM public.offers;
  IF v_count <> 1 THEN RAISE EXCEPTION 'Expected one offer after retry, found %', v_count; END IF;
  SELECT count(*) INTO v_count FROM public.action_executions WHERE status = 'COMPLETED';
  IF v_count <> 1 THEN RAISE EXCEPTION 'Expected one completed execution, found %', v_count; END IF;
  SELECT count(*) INTO v_count FROM public.idempotency_keys WHERE status = 'COMPLETED';
  IF v_count <> 1 THEN RAISE EXCEPTION 'Expected one completed idempotency row, found %', v_count; END IF;
  SELECT count(*) INTO v_count FROM public.action_events WHERE event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 1 THEN RAISE EXCEPTION 'Expected one success event, found %', v_count; END IF;

  -- JSONB object key order is not semantically significant for an identical request.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-jsonb-order',
    '{"alpha":1,"beta":2,"items":[1,2]}'::jsonb,
    'JSONB Order Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected JSONB-order fixture to succeed, got %', first_result;
  END IF;

  retry_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-jsonb-order',
    '{"beta":2,"items":[1,2],"alpha":1}'::jsonb,
    'JSONB Order Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );
  IF retry_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'Semantically identical JSONB payload with reordered keys did not replay the same result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'JSONB Order Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one JSONB-order offer after retry, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-jsonb-order';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one JSONB-order execution after retry, found %', v_count;
  END IF;

  -- JSONB array order is significant and must participate in the idempotency hash.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-jsonb-order',
      '{"beta":2,"items":[2,1],"alpha":1}'::jsonb,
      'JSONB Order Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD'
    );
    RAISE EXCEPTION 'Expected reordered JSONB array values to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- Nested JSONB object key order is insignificant at every nesting level.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-jsonb-nested-object',
    '{"meta":{"alpha":1,"nested":{"x":true,"y":"value"}},"items":[1,2]}'::jsonb,
    'Nested JSONB Order Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected nested JSONB-order fixture to succeed, got %', first_result;
  END IF;

  retry_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-jsonb-nested-object',
    '{"items":[1,2],"meta":{"nested":{"y":"value","x":true},"alpha":1}}'::jsonb,
    'Nested JSONB Order Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );
  IF retry_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'Nested JSONB object key reordering did not replay the same result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Nested JSONB Order Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one nested JSONB-order offer after retry, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-jsonb-nested-object';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one nested JSONB-order execution after retry, found %', v_count;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      13,
      'USD'
    );
    RAISE EXCEPTION 'Expected changed effective payload to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- NULL and an empty attributes object have the same effective request hash.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-attributes-null-empty',
    '{"case":"attributes-null-empty"}'::jsonb,
    'Attributes Null Empty Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD',
    p_attributes => NULL
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected NULL attributes fixture to succeed, got %', first_result;
  END IF;

  retry_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-attributes-null-empty',
    '{"case":"attributes-null-empty"}'::jsonb,
    'Attributes Null Empty Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD',
    p_attributes => '{}'::jsonb
  );
  IF retry_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'NULL and empty attributes retries did not replay the same result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Attributes Null Empty Offer'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one offer with normalized empty attributes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-attributes-null-empty';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for NULL/empty attributes retry, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-idempotency-attributes-null-empty'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one completed idempotency row for NULL/empty attributes retry, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x ON x.id = e.execution_id
  WHERE x.idempotency_key = 'fixture-idempotency-attributes-null-empty'
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one success event for NULL/empty attributes retry, found %', v_count;
  END IF;

  -- Optional business parameters must participate in the idempotency hash too.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      p_attributes => '{"quality":"A"}'::jsonb
    );
    RAISE EXCEPTION 'Expected changed optional attributes to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- A different market must not replay the completed result for the same key.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      p_market => 'industrial'
    );
    RAISE EXCEPTION 'Expected changed market to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- A different conditions value must not replay the completed result for the same key.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      p_conditions => 'Net 30'
    );
    RAISE EXCEPTION 'Expected changed conditions to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- A different pricing model must not replay the completed result for the same key.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'Expected changed pricing model to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- Geography is part of the effective request and must be hashed.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      p_geography => 'KR'
    );
    RAISE EXCEPTION 'Expected changed geography to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- Documentation status is part of the effective request hash, including NULL versus empty text.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-1',
      '{"case":"same-payload"}'::jsonb,
      'Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      p_documentation_status => ''
    );
    RAISE EXCEPTION 'Expected changed documentation status to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  -- Lifecycle uses the application default "draft" and must participate in the request hash.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-lifecycle',
    '{"case":"lifecycle-hash"}'::jsonb,
    'Lifecycle Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD',
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected lifecycle hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-lifecycle',
      '{"case":"lifecycle-hash"}'::jsonb,
      'Lifecycle Hash Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD',
      p_lifecycle => NULL,
      p_offer_type => 'supplier_offer'
    );
    RAISE EXCEPTION 'Expected changed lifecycle to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Lifecycle Hash Offer'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one lifecycle hash offer with application defaults, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-lifecycle';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for lifecycle hash fixture, found %', v_count;
  END IF;

  -- Offer type uses the application default "supplier_offer" and must participate in the request hash.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-offer-type',
    '{"case":"offer-type-hash"}'::jsonb,
    'Offer Type Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD',
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected offer type hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-offer-type',
      '{"case":"offer-type-hash"}'::jsonb,
      'Offer Type Hash Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD',
      p_lifecycle => 'draft',
      p_offer_type => NULL
    );
    RAISE EXCEPTION 'Expected changed offer type to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Offer Type Hash Offer'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one offer type hash offer with application defaults, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-offer-type';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for offer type hash fixture, found %', v_count;
  END IF;

  -- Name is part of the effective request hash.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-name',
    '{"case":"name-hash"}'::jsonb,
    'Name Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected name hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-name',
      '{"case":"name-hash"}'::jsonb,
      'Name Hash Offer Changed',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected changed name to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Name Hash Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one original name hash offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-name';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for name hash fixture, found %', v_count;
  END IF;

  -- Currency is part of the effective request hash; both values are accepted by the RPC.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-currency',
    '{"case":"currency-hash"}'::jsonb,
    'Currency Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected currency hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-currency',
      '{"case":"currency-hash"}'::jsonb,
      'Currency Hash Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'EUR'
    );
    RAISE EXCEPTION 'Expected changed currency to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Currency Hash Offer'
    AND currency = 'USD';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one original USD currency hash offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-currency';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for currency hash fixture, found %', v_count;
  END IF;

  -- A second existing demand isolates demandId in the request hash.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-demand',
    '{"case":"demand-hash"}'::jsonb,
    'Demand Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected demand hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-demand',
      '{"case":"demand-hash"}'::jsonb,
      'Demand Hash Offer',
      '50000000-0000-4000-8000-000000000002',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected changed demandId to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Demand Hash Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one original demand hash offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-demand';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for demand hash fixture, found %', v_count;
  END IF;

  -- A second active Product Master isolates productMasterId in the request hash.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-product-master',
    '{"case":"product-master-hash"}'::jsonb,
    'Product Master Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected Product Master hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-product-master',
      '{"case":"product-master-hash"}'::jsonb,
      'Product Master Hash Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000002',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected changed productMasterId to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Product Master Hash Offer'
    AND product_master_id = '40000000-0000-4000-8000-000000000001';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one original Product Master hash offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-product-master';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for Product Master hash fixture, found %', v_count;
  END IF;

  -- Price is part of the effective request hash and both amounts are valid.
  first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-idempotency-price',
    '{"case":"price-hash"}'::jsonb,
    'Price Hash Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );
  IF first_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected price hash fixture to succeed, got %', first_result;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-idempotency-price',
      '{"case":"price-hash"}'::jsonb,
      'Price Hash Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      11,
      'USD'
    );
    RAISE EXCEPTION 'Expected changed price to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REUSE%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Price Hash Offer'
    AND price = 10;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one original price hash offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-idempotency-price';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one execution for price hash fixture, found %', v_count;
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-invalid-nan',
      '{"case":"nan"}'::jsonb,
      'Invalid NaN Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      'NaN'::numeric,
      12,
      'USD'
    );
    RAISE EXCEPTION 'Expected NaN quantity to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_QUANTITY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000002',
      'fixture-wrong-tenant',
      '{"case":"wrong-tenant"}'::jsonb,
      'Wrong Tenant Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected cross-tenant call to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%TENANT_ACCESS_DENIED%' THEN RAISE; END IF;
  END;


  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-provider-spoof',
      '{"case":"provider-spoof"}'::jsonb,
      'Spoofed Provider Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000002',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected spoofed provider actor to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_PROVIDER_ACTOR%' THEN RAISE; END IF;
  END;

  -- A missing JWT subject must not be accepted by the SECURITY DEFINER wrapper.
  PERFORM set_config('request.jwt.claim.sub', '', true);
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-unauthenticated',
      '{"case":"unauthenticated"}'::jsonb,
      'Unauthenticated Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected unauthenticated caller to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%UNAUTHENTICATED%' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000001', true);

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN ('Spoofed Provider Offer', 'Unauthenticated Offer');
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rejected calls unexpectedly created offers'; END IF;


  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-infinity-quantity',
      '{"case":"infinity-quantity"}'::jsonb,
      'Infinity Quantity Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      'Infinity'::numeric,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected Infinity quantity to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_QUANTITY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-infinity-price',
      '{"case":"infinity-price"}'::jsonb,
      'Infinity Price Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      'Infinity'::numeric,
      'USD'
    );
    RAISE EXCEPTION 'Expected Infinity price to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_PRICE%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-negative-price',
      '{"case":"negative-price"}'::jsonb,
      'Negative Price Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      -1,
      'USD'
    );
    RAISE EXCEPTION 'Expected negative price to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_PRICE%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-invalid-currency',
      '{"case":"unsupported-currency"}'::jsonb,
      'Unsupported Currency Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'XYZ'
    );
    RAISE EXCEPTION 'Expected unsupported currency to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_CURRENCY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-null-currency',
      '{"case":"null-currency"}'::jsonb,
      'Null Currency Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      NULL
    );
    RAISE EXCEPTION 'Expected null currency to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_CURRENCY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-whitespace-currency',
      '{"case":"whitespace-currency"}'::jsonb,
      'Whitespace Currency Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      '   '
    );
    RAISE EXCEPTION 'Expected whitespace-only currency to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_CURRENCY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-padded-currency',
      '{"case":"padded-currency"}'::jsonb,
      'Padded Currency Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      ' USD '
    );
    RAISE EXCEPTION 'Expected padded currency to be rejected by the RPC contract';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_CURRENCY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-lowercase-currency',
      '{"case":"lowercase-currency"}'::jsonb,
      'Lowercase Currency Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'usd'
    );
    RAISE EXCEPTION 'Expected lowercase currency to be rejected by the canonical RPC contract';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%INVALID_CURRENCY%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      '   ',
      '{"case":"blank-key"}'::jsonb,
      'Blank Key Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected blank idempotency key to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%IDEMPOTENCY_KEY_REQUIRED%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-null-input',
      NULL,
      'Null Input Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected null action input to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%ACTION_INPUT_REQUIRED%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-missing-demand',
      '{"case":"missing-demand"}'::jsonb,
      'Missing Demand Offer',
      '50000000-0000-4000-8000-000000000099',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected missing demand to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%DEMAND_NOT_FOUND%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-inactive-product',
      '{"case":"inactive-product"}'::jsonb,
      'Inactive Product Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000099',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected inactive Product Master to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PRODUCT_MASTER_NOT_FOUND%' THEN RAISE; END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'Infinity Quantity Offer', 'Infinity Price Offer', 'Negative Price Offer',
    'Unsupported Currency Offer', 'Null Currency Offer', 'Whitespace Currency Offer', 'Padded Currency Offer', 'Lowercase Currency Offer', 'Blank Key Offer', 'Null Input Offer', 'Missing Demand Offer', 'Inactive Product Offer'
  );
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rejected validation cases created % offers', v_count; END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-rollback',
      '{"case":"rollback"}'::jsonb,
      'Fixture rollback failure',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      10,
      'USD'
    );
    RAISE EXCEPTION 'Expected fixture constraint to force transaction rollback';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-rollback';
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rollback left an orphan action execution'; END IF;
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-rollback';
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rollback left an orphan idempotency row'; END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x ON x.id = e.execution_id
  WHERE x.idempotency_key = 'fixture-rollback';
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rollback left an orphan event'; END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Fixture rollback failure';
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rollback left an offer row'; END IF;

  IF has_function_privilege(
    'authenticated',
    'public.create_offer_v1(text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Authenticated still has direct execute privilege on create_offer_v1';
  END IF;

  BEGIN
    PERFORM public.create_offer_v1(
      'Direct RPC must fail',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1, 10, 'USD', NULL, NULL, NULL, '{}'::jsonb, NULL, NULL, NULL, NULL
    );
    RAISE EXCEPTION 'Expected direct low-level RPC to be denied';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;

RESET ROLE;

-- The same authenticated principal belongs to both tenants for this isolated
-- scope test. Keeping actor and every request parameter identical ensures that
-- only p_tenant_id differs; this does not test demand ownership.
INSERT INTO public.dt_memberships (tenant_id, user_id)
VALUES (
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000001'
);

SET ROLE authenticated;

DO $qima$
DECLARE
  tenant_a_result jsonb;
  tenant_b_result jsonb;
  tenant_a_retry jsonb;
  tenant_b_retry jsonb;
  v_count integer;
BEGIN
  IF (
    SELECT count(*)
    FROM public.dt_memberships
    WHERE user_id = '20000000-0000-4000-8000-000000000001'
      AND tenant_id IN (
        '10000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000002'
      )
  ) <> 2 THEN
    RAISE EXCEPTION 'Expected the fixture user to have valid memberships in both tenants';
  END IF;

  tenant_a_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-same-key-two-tenants',
    '{"case":"tenant-scoped-idempotency"}'::jsonb,
    'Tenant Scoped Idempotency Offer',
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );

  IF tenant_a_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected tenant A request to succeed, got %', tenant_a_result;
  END IF;

  tenant_b_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000002',
    'fixture-same-key-two-tenants',
    '{"case":"tenant-scoped-idempotency"}'::jsonb,
    'Tenant Scoped Idempotency Offer',
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );

  IF tenant_b_result->>'status' <> 'succeeded' THEN
    RAISE EXCEPTION 'Expected tenant B request to succeed independently, got %', tenant_b_result;
  END IF;

  IF tenant_a_result->>'executionId' IS NULL
     OR tenant_b_result->>'executionId' IS NULL
     OR tenant_a_result->>'executionId' = tenant_b_result->>'executionId' THEN
    RAISE EXCEPTION 'The same key in separate tenants must create distinct executions: %, %',
      tenant_a_result, tenant_b_result;
  END IF;

  IF tenant_a_result->>'objectId' IS NULL
     OR tenant_b_result->>'objectId' IS NULL
     OR tenant_a_result->>'objectId' = tenant_b_result->>'objectId' THEN
    RAISE EXCEPTION 'The same key in separate tenants must create distinct offers: %, %',
      tenant_a_result, tenant_b_result;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected one completed idempotency row per tenant, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two completed executions across tenants, found %', v_count;
  END IF;

  SELECT count(DISTINCT request_hash) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected identical request hashes when only tenant scope changes, found % distinct hashes', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id IN (
    (tenant_a_result->>'objectId')::uuid,
    (tenant_b_result->>'objectId')::uuid
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two distinct offers for the two tenant-scoped executions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE event_type = 'ACTION_SUCCEEDED'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND object_id IN (
      (tenant_a_result->>'objectId')::uuid,
      (tenant_b_result->>'objectId')::uuid
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected one success event per tenant-scoped execution, found %', v_count;
  END IF;

  -- Replay each tenant's original request with the same key. Each call must
  -- return that tenant's stored result, never the other tenant's result.
  tenant_a_retry := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-same-key-two-tenants',
    '{"case":"tenant-scoped-idempotency"}'::jsonb,
    'Tenant Scoped Idempotency Offer',
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );

  tenant_b_retry := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000002',
    'fixture-same-key-two-tenants',
    '{"case":"tenant-scoped-idempotency"}'::jsonb,
    'Tenant Scoped Idempotency Offer',
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );

  IF tenant_a_retry IS DISTINCT FROM tenant_a_result THEN
    RAISE EXCEPTION 'Tenant A retry did not return its original result: initial %, retry %',
      tenant_a_result, tenant_a_retry;
  END IF;

  IF tenant_b_retry IS DISTINCT FROM tenant_b_result THEN
    RAISE EXCEPTION 'Tenant B retry did not return its original result: initial %, retry %',
      tenant_b_result, tenant_b_retry;
  END IF;

  IF tenant_a_retry->>'objectId' = tenant_b_retry->>'objectId'
     OR tenant_a_retry->>'executionId' = tenant_b_retry->>'executionId' THEN
    RAISE EXCEPTION 'Tenant retries must remain bound to distinct original offers and executions: %, %',
      tenant_a_retry, tenant_b_retry;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Tenant retries created or lost idempotency rows; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Tenant retries created extra executions; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id IN (
    (tenant_a_result->>'objectId')::uuid,
    (tenant_b_result->>'objectId')::uuid
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Tenant retries created or lost offers; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE event_type = 'ACTION_SUCCEEDED'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND object_id IN (
      (tenant_a_result->>'objectId')::uuid,
      (tenant_b_result->>'objectId')::uuid
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Tenant retries created extra success events; expected 2, found %', v_count;
  END IF;

  -- A changed payload for tenant A must be rejected without disturbing tenant B.
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-same-key-two-tenants',
      '{"case":"tenant-scoped-idempotency"}'::jsonb,
      'Tenant Scoped Idempotency Offer',
      '50000000-0000-4000-8000-000000000003',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1,
      11,
      'USD'
    );
    RAISE EXCEPTION 'Expected tenant A changed-price retry to be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'Expected IDEMPOTENCY_KEY_REUSE for tenant A, got %', SQLERRM;
    END IF;
  END;

  -- Both original requests must still replay their own unchanged results.
  tenant_a_retry := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-same-key-two-tenants',
    '{"case":"tenant-scoped-idempotency"}'::jsonb,
    'Tenant Scoped Idempotency Offer',
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );
  tenant_b_retry := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000002',
    'fixture-same-key-two-tenants',
    '{"case":"tenant-scoped-idempotency"}'::jsonb,
    'Tenant Scoped Idempotency Offer',
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1,
    10,
    'USD'
  );

  IF tenant_a_retry IS DISTINCT FROM tenant_a_result THEN
    RAISE EXCEPTION 'Tenant A original retry changed after rejected payload: initial %, retry %',
      tenant_a_result, tenant_a_retry;
  END IF;
  IF tenant_b_retry IS DISTINCT FROM tenant_b_result THEN
    RAISE EXCEPTION 'Tenant B replay was affected by tenant A rejection: initial %, retry %',
      tenant_b_result, tenant_b_retry;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Rejected tenant A retry changed idempotency rows; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-same-key-two-tenants'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Rejected tenant A retry created an execution; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id IN (
    (tenant_a_result->>'objectId')::uuid,
    (tenant_b_result->>'objectId')::uuid
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Rejected tenant A retry created or lost an offer; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE event_type = 'ACTION_SUCCEEDED'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND object_id IN (
      (tenant_a_result->>'objectId')::uuid,
      (tenant_b_result->>'objectId')::uuid
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Rejected tenant A retry created an event; expected 2, found %', v_count;
  END IF;
END
$qima$;

RESET ROLE;
DELETE FROM public.dt_memberships
WHERE tenant_id = '10000000-0000-4000-8000-000000000002'
  AND user_id = '20000000-0000-4000-8000-000000000001';

SELECT 'CREATE_OFFER integration assertions passed' AS result;


-- OFFER-QA-63: replay terminal FAILED rows and reject an existing IN_PROGRESS row.
-- Seed these records as the fixture owner, then exercise the public RPC as the
-- authenticated fixture user. All records remain in the disposable CI database.
RESET ROLE;

DO $qa63_seed$
DECLARE
  v_action_id uuid;
  v_failed_execution_id uuid := gen_random_uuid();
  v_running_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_user_id uuid := '20000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"offer-status-replay"}'::jsonb;
  v_hash text;
  v_failed_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Existing Status Replay Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', v_actor_id,
    'quantity', 2,
    'price', 12,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  )::text);

  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', 'FIXTURE_FAILURE'
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_failed_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-existing-failed-replay', 'FAILED',
    v_input, v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-existing-failed-replay', v_action_id, v_actor_id, v_hash,
    v_failed_execution_id, 'FAILED', v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_running_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-existing-in-progress-replay', 'RUNNING',
    v_input, NULL, NULL, v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-existing-in-progress-replay', v_action_id, v_actor_id, v_hash,
    v_running_execution_id, 'IN_PROGRESS', NULL, NULL, v_tenant_id
  );
END
$qa63_seed$;

SET ROLE authenticated;

DO $qa63_assert$
DECLARE
  v_failed_expected jsonb;
  v_failed_actual jsonb;
  v_error text;
  v_count integer;
  v_failed_execution_id uuid;
  v_running_execution_id uuid;
BEGIN
  SELECT result, execution_id
  INTO v_failed_expected, v_failed_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-replay'
    AND status = 'FAILED';

  IF v_failed_expected IS NULL OR v_failed_execution_id IS NULL THEN
    RAISE EXCEPTION 'FAILED replay fixture was not seeded with a stored result';
  END IF;

  v_failed_actual := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-existing-failed-replay',
    '{"case":"offer-status-replay"}'::jsonb,
    'Existing Status Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );

  IF v_failed_actual IS DISTINCT FROM v_failed_expected THEN
    RAISE EXCEPTION 'FAILED replay did not return the stored failure result: expected %, got %',
      v_failed_expected, v_failed_actual;
  END IF;

  IF v_failed_actual->>'status' IS DISTINCT FROM 'failed'
     OR v_failed_actual->>'executionId' IS DISTINCT FROM v_failed_execution_id::text
     OR v_failed_actual->>'error' IS DISTINCT FROM 'FIXTURE_FAILURE' THEN
    RAISE EXCEPTION 'FAILED replay returned an unexpected public result: %', v_failed_actual;
  END IF;

  SELECT execution_id INTO v_running_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-in-progress-replay'
    AND status = 'IN_PROGRESS';

  IF v_running_execution_id IS NULL THEN
    RAISE EXCEPTION 'IN_PROGRESS replay fixture was not seeded';
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-existing-in-progress-replay',
      '{"case":"offer-status-replay"}'::jsonb,
      'Existing Status Replay Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
  END;

  IF v_error IS DISTINCT FROM 'ACTION_ALREADY_RUNNING' THEN
    RAISE EXCEPTION 'Expected ACTION_ALREADY_RUNNING for IN_PROGRESS replay, got %', v_error;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-existing-failed-replay',
      'fixture-existing-in-progress-replay'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Status replays changed the seeded idempotency row count; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-existing-failed-replay',
      'fixture-existing-in-progress-replay'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Status replays created or removed executions; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-replay'
    AND status = 'FAILED'
    AND result = v_failed_expected;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED replay changed its stored status/result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-in-progress-replay'
    AND status = 'IN_PROGRESS'
    AND result IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'IN_PROGRESS replay changed its stored status/result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE id IN (v_failed_execution_id, v_running_execution_id)
    AND (
      (id = v_failed_execution_id AND status = 'FAILED' AND result = v_failed_expected)
      OR
      (id = v_running_execution_id AND status = 'RUNNING' AND result IS NULL)
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Status replays changed the corresponding execution states/results';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Existing Status Replay Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Status replays unexpectedly created an offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (v_failed_execution_id, v_running_execution_id);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Status replays unexpectedly created action events, found %', v_count;
  END IF;
END
$qa63_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER FAILED and IN_PROGRESS replay assertions passed' AS result;
