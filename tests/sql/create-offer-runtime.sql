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


-- OFFER-QA-64: a terminal FAILED row with a NULL result must use the
-- coalesce fallback result, preserving the original execution identifier.
-- All records are seeded in and remain limited to the disposable CI database.
RESET ROLE;

DO $qa64_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"failed-null-result-replay"}'::jsonb;
  v_hash text;
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
    'name', 'Existing Failed Null Result Replay Offer',
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

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-existing-failed-null-result-replay', 'FAILED',
    v_input, NULL, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-existing-failed-null-result-replay', v_action_id, v_actor_id, v_hash,
    v_execution_id, 'FAILED', NULL, now(), v_tenant_id
  );
END
$qa64_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa64_assert$
DECLARE
  v_expected jsonb;
  v_actual jsonb;
  v_execution_id uuid;
  v_count integer;
BEGIN
  SELECT execution_id
  INTO v_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-null-result-replay'
    AND status = 'FAILED'
    AND result IS NULL;

  IF v_execution_id IS NULL THEN
    RAISE EXCEPTION 'FAILED NULL-result replay fixture was not seeded';
  END IF;

  v_expected := jsonb_build_object(
    'status', 'failed',
    'executionId', v_execution_id
  );

  v_actual := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-existing-failed-null-result-replay',
    '{"case":"failed-null-result-replay"}'::jsonb,
    'Existing Failed Null Result Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );

  IF v_actual IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'FAILED NULL-result replay did not return the coalesce fallback: expected %, got %',
      v_expected, v_actual;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-null-result-replay'
    AND status = 'FAILED'
    AND execution_id = v_execution_id
    AND result IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED NULL-result replay changed or duplicated its idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-existing-failed-null-result-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED NULL-result replay created or removed an execution; expected 1, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-existing-failed-null-result-replay'
    AND status = 'FAILED'
    AND result IS NULL
    AND object_id IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED NULL-result replay changed the original execution row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Existing Failed Null Result Replay Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAILED NULL-result replay unexpectedly created an offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-existing-failed-null-result-replay';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAILED NULL-result replay unexpectedly created action events';
  END IF;
END
$qa64_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER FAILED NULL-result replay fallback assertions passed' AS result;

-- OFFER-QA-65: a terminal COMPLETED idempotency row with a NULL result
-- must use the SQL fallback, even when the linked execution retains its
-- normal succeeded result. This deliberately records the status-contract
-- difference without changing the migration or choosing a public mapping.
-- All records remain in the disposable PostgreSQL database used by CI.
RESET ROLE;

DO $qa65_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"completed-null-result-replay"}'::jsonb;
  v_execution_result jsonb;
  v_hash text;
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
    'name', 'Existing Completed Null Result Replay Offer',
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

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'Existing Completed Null Result Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    '{}'::jsonb
  );

  v_execution_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-existing-completed-null-result-replay', 'COMPLETED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  -- Model a partial result-column inconsistency: the execution and success
  -- event retain their normal result, while the idempotency row result is NULL.
  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-existing-completed-null-result-replay', v_action_id, v_actor_id, v_hash,
    v_execution_id, 'COMPLETED', NULL, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_execution_result, v_tenant_id
  );
END
$qa65_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa65_assert$
DECLARE
  v_expected jsonb;
  v_actual jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_count integer;
BEGIN
  SELECT execution_id
  INTO v_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-completed-null-result-replay'
    AND status = 'COMPLETED'
    AND result IS NULL;

  IF v_execution_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay fixture was not seeded';
  END IF;

  SELECT object_id
  INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-existing-completed-null-result-replay'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED replay fixture is missing its original offer reference';
  END IF;

  v_expected := jsonb_build_object(
    'status', 'completed',
    'executionId', v_execution_id
  );

  v_actual := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-existing-completed-null-result-replay',
    '{"case":"completed-null-result-replay"}'::jsonb,
    'Existing Completed Null Result Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );

  IF v_actual IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay did not return the coalesce fallback: expected %, got %',
      v_expected, v_actual;
  END IF;

  IF v_actual->>'status' IS DISTINCT FROM 'completed'
     OR v_actual->>'status' = 'succeeded'
     OR v_actual->>'executionId' IS DISTINCT FROM v_execution_id::text THEN
    RAISE EXCEPTION 'COMPLETED NULL-result fallback status/identifier contract changed unexpectedly: %',
      v_actual;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-completed-null-result-replay'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay changed or duplicated its idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-existing-completed-null-result-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay created or removed an execution; expected 1, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND result = jsonb_build_object(
      'status', 'succeeded',
      'executionId', v_execution_id,
      'objectType', 'Offer',
      'objectId', v_offer_id
    );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay changed the original execution result/object';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Existing Completed Null Result Replay Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay created, removed, or changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED NULL-result replay created or removed the original success event';
  END IF;
END
$qa65_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER COMPLETED NULL-result replay fallback assertions passed' AS result;

-- OFFER-QA-66: JSONB null is a non-SQL-NULL stored result and must be
-- returned as-is by COALESCE. This is intentionally distinct from the
-- SQL NULL fallback covered by OFFER-QA-64/65. All rows are CI-only.
RESET ROLE;

DO $qa66_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"completed-json-null-result-replay"}'::jsonb;
  v_execution_result jsonb;
  v_hash text;
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
    'name', 'Existing Completed JSON Null Result Replay Offer',
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

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'Existing Completed JSON Null Result Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    '{}'::jsonb
  );

  v_execution_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-existing-completed-json-null-result-replay', 'COMPLETED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  -- JSONB null is a JSON value, not SQL NULL. COALESCE must therefore
  -- return this stored value rather than constructing the status fallback.
  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-existing-completed-json-null-result-replay', v_action_id, v_actor_id, v_hash,
    v_execution_id, 'COMPLETED', 'null'::jsonb, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_execution_result, v_tenant_id
  );
END
$qa66_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa66_assert$
DECLARE
  v_actual jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_result jsonb;
  v_count integer;
BEGIN
  SELECT execution_id, result
  INTO v_execution_id, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-completed-json-null-result-replay'
    AND status = 'COMPLETED'
    AND result IS NOT NULL
    AND jsonb_typeof(result) = 'null';

  IF v_execution_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay fixture was not seeded';
  END IF;

  IF v_stored_result IS DISTINCT FROM 'null'::jsonb THEN
    RAISE EXCEPTION 'Fixture result must be JSONB null, not SQL NULL or another JSON value: %',
      v_stored_result;
  END IF;

  SELECT object_id
  INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-existing-completed-json-null-result-replay'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay fixture is missing its original offer reference';
  END IF;

  v_actual := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-existing-completed-json-null-result-replay',
    '{"case":"completed-json-null-result-replay"}'::jsonb,
    'Existing Completed JSON Null Result Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );

  IF v_actual IS DISTINCT FROM 'null'::jsonb THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay must return the stored JSON null unchanged; got %',
      v_actual;
  END IF;

  IF jsonb_typeof(v_actual) IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay returned an unexpected JSON type: %',
      jsonb_typeof(v_actual);
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-completed-json-null-result-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay created or removed an idempotency row; expected 1, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-completed-json-null-result-replay'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result IS NOT NULL
    AND jsonb_typeof(result) = 'null';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay changed the original idempotency result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-existing-completed-json-null-result-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay created or removed an execution; expected 1, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND result = jsonb_build_object(
      'status', 'succeeded',
      'executionId', v_execution_id,
      'objectType', 'Offer',
      'objectId', v_offer_id
    );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay changed the original execution result/object';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Existing Completed JSON Null Result Replay Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay created, removed, or changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED JSONB-null replay created or removed the original success event';
  END IF;
END
$qa66_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER COMPLETED JSONB-null replay assertions passed' AS result;

-- OFFER-QA-67: a FAILED idempotency row containing JSONB null must return
-- that stored JSON value unchanged, while preserving the original failure
-- result on action_executions. All rows are limited to disposable CI.
RESET ROLE;

DO $qa67_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"failed-json-null-result-replay"}'::jsonb;
  v_execution_result jsonb;
  v_hash text;
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
    'name', 'Existing Failed JSON Null Result Replay Offer',
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

  v_execution_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-existing-failed-json-null-result-replay', 'FAILED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  -- JSONB null is non-NULL to SQL COALESCE. Keep a separate, meaningful
  -- failure result on the execution row to prove the replay returns the
  -- idempotency row's JSON null rather than the execution's result.
  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-existing-failed-json-null-result-replay', v_action_id, v_actor_id, v_hash,
    v_execution_id, 'FAILED', 'null'::jsonb, now(), v_tenant_id
  );
END
$qa67_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa67_assert$
DECLARE
  v_actual jsonb;
  v_execution_id uuid;
  v_idempotency_result jsonb;
  v_execution_result jsonb;
  v_expected_execution_result jsonb;
  v_count integer;
BEGIN
  SELECT execution_id, result
  INTO v_execution_id, v_idempotency_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-json-null-result-replay'
    AND status = 'FAILED';

  IF v_execution_id IS NULL THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay fixture was not seeded';
  END IF;

  IF v_idempotency_result IS NULL
     OR jsonb_typeof(v_idempotency_result) IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'FAILED JSONB-null fixture must contain JSON null, not SQL NULL';
  END IF;

  v_expected_execution_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );

  SELECT result INTO v_execution_result
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-existing-failed-json-null-result-replay'
    AND status = 'FAILED'
    AND object_id IS NULL;

  IF v_execution_result IS DISTINCT FROM v_expected_execution_result THEN
    RAISE EXCEPTION 'FAILED JSONB-null fixture lost its original execution failure result';
  END IF;

  v_actual := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-existing-failed-json-null-result-replay',
    '{"case":"failed-json-null-result-replay"}'::jsonb,
    'Existing Failed JSON Null Result Replay Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD'
  );

  IF v_actual IS DISTINCT FROM 'null'::jsonb THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay must return stored JSON null unchanged; got %',
      v_actual;
  END IF;

  IF jsonb_typeof(v_actual) IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay returned an unexpected JSON type: %',
      jsonb_typeof(v_actual);
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-json-null-result-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay created or removed an idempotency row; expected 1, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-existing-failed-json-null-result-replay'
    AND status = 'FAILED'
    AND execution_id = v_execution_id
    AND result IS NOT NULL
    AND jsonb_typeof(result) = 'null';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay changed the original idempotency result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-existing-failed-json-null-result-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay created or removed an execution; expected 1, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-existing-failed-json-null-result-replay'
    AND status = 'FAILED'
    AND object_id IS NULL
    AND result = v_expected_execution_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay changed the original execution failure result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Existing Failed JSON Null Result Replay Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay unexpectedly created an offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-existing-failed-json-null-result-replay';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAILED JSONB-null replay unexpectedly created action events';
  END IF;
END
$qa67_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER FAILED JSONB-null replay assertions passed' AS result;


-- OFFER-QA-68: request_hash must be checked before terminal/in-progress
-- status handling. A changed effective business parameter (price) must be
-- rejected as IDEMPOTENCY_KEY_REUSE for both FAILED and IN_PROGRESS rows.
-- Fixtures are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa68_seed$
DECLARE
  v_action_id uuid;
  v_failed_execution_id uuid := gen_random_uuid();
  v_running_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"request-hash-precedence"}'::jsonb;
  v_request_hash text;
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

  -- The stored hash represents the original request at price 12. Both retry
  -- calls below change only price to 13, keeping all other effective inputs.
  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Request Hash Precedence Fixture Offer',
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
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_failed_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-mismatch-failed', 'FAILED',
    v_input, v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-mismatch-failed', v_action_id, v_actor_id, v_request_hash,
    v_failed_execution_id, 'FAILED', v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_running_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-mismatch-in-progress', 'RUNNING',
    v_input, NULL, NULL, v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-mismatch-in-progress', v_action_id, v_actor_id, v_request_hash,
    v_running_execution_id, 'IN_PROGRESS', NULL, NULL, v_tenant_id
  );
END
$qa68_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa68_assert$
DECLARE
  v_error text;
  v_failed_execution_id uuid;
  v_running_execution_id uuid;
  v_failed_result jsonb;
  v_expected_failed_result jsonb;
  v_original_hash text;
  v_expected_hash text;
  v_changed_hash text;
  v_count integer;
BEGIN
  v_expected_hash := md5(jsonb_build_object(
    'input', '{"case":"request-hash-precedence"}'::jsonb,
    'name', 'Request Hash Precedence Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
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
  v_changed_hash := md5(jsonb_build_object(
    'input', '{"case":"request-hash-precedence"}'::jsonb,
    'name', 'Request Hash Precedence Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', 13,
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
  IF v_expected_hash = v_changed_hash THEN
    RAISE EXCEPTION 'Fixture must use different hashes for prices 12 and 13';
  END IF;

  SELECT execution_id, result, request_hash
  INTO v_failed_execution_id, v_failed_result, v_original_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-failed'
    AND status = 'FAILED';

  IF v_failed_execution_id IS NULL
     OR v_failed_result IS NULL
     OR v_original_hash IS DISTINCT FROM v_expected_hash THEN
    RAISE EXCEPTION 'FAILED hash-mismatch fixture was not seeded with the expected original hash/result';
  END IF;

  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );
  IF v_failed_result IS DISTINCT FROM v_expected_failed_result THEN
    RAISE EXCEPTION 'FAILED hash-mismatch fixture has an unexpected stored result';
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-mismatch-failed',
      '{"case":"request-hash-precedence"}'::jsonb,
      'Request Hash Precedence Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      13,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'FAILED hash mismatch must take precedence over terminal replay; expected IDEMPOTENCY_KEY_REUSE, got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT execution_id, request_hash
  INTO v_running_execution_id, v_original_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-in-progress'
    AND status = 'IN_PROGRESS'
    AND result IS NULL;

  IF v_running_execution_id IS NULL
     OR v_original_hash IS DISTINCT FROM v_expected_hash THEN
    RAISE EXCEPTION 'IN_PROGRESS hash-mismatch fixture was not seeded with the expected original hash';
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-mismatch-in-progress',
      '{"case":"request-hash-precedence"}'::jsonb,
      'Request Hash Precedence Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      13,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'IN_PROGRESS hash mismatch must take precedence over running-state handling; expected IDEMPOTENCY_KEY_REUSE, got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-hash-mismatch-failed',
      'fixture-hash-mismatch-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Hash-mismatch retries changed or duplicated idempotency rows; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-failed'
    AND status = 'FAILED'
    AND execution_id = v_failed_execution_id
    AND request_hash = v_expected_hash
    AND result = v_expected_failed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED hash-mismatch retry changed the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-in-progress'
    AND status = 'IN_PROGRESS'
    AND execution_id = v_running_execution_id
    AND request_hash = v_expected_hash
    AND result IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'IN_PROGRESS hash-mismatch retry changed the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-hash-mismatch-failed',
      'fixture-hash-mismatch-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Hash-mismatch retries created or removed executions; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_failed_execution_id
    AND idempotency_key = 'fixture-hash-mismatch-failed'
    AND status = 'FAILED'
    AND result = v_expected_failed_result
    AND object_id IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAILED hash-mismatch retry changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_running_execution_id
    AND idempotency_key = 'fixture-hash-mismatch-in-progress'
    AND status = 'RUNNING'
    AND result IS NULL
    AND object_id IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'IN_PROGRESS hash-mismatch retry changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Request Hash Precedence Fixture Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Hash-mismatch retries unexpectedly created an offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-hash-mismatch-failed',
      'fixture-hash-mismatch-in-progress'
    );
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Hash-mismatch retries unexpectedly created action events';
  END IF;
END
$qa68_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER request_hash precedence assertions passed' AS result;


-- OFFER-QA-69: request_hash mismatch must take precedence for an existing
-- COMPLETED key too. A retry with a changed effective business parameter
-- must not return the previously stored success result or mutate any row.
-- All records are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa69_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"completed-hash-precedence"}'::jsonb;
  v_execution_result jsonb;
  v_original_hash text;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_original_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Request Hash Precedence Completed Fixture Offer',
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

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'Request Hash Precedence Completed Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    '{}'::jsonb
  );

  v_execution_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-hash-mismatch-completed', 'COMPLETED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-mismatch-completed', v_action_id, v_actor_id,
    v_original_hash, v_execution_id, 'COMPLETED',
    v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_execution_result, v_tenant_id
  );
END
$qa69_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa69_assert$
DECLARE
  v_error text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_original_hash text;
  v_changed_hash text;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_count integer;
BEGIN
  v_original_hash := md5(jsonb_build_object(
    'input', '{"case":"completed-hash-precedence"}'::jsonb,
    'name', 'Request Hash Precedence Completed Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
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

  v_changed_hash := md5(jsonb_build_object(
    'input', '{"case":"completed-hash-precedence"}'::jsonb,
    'name', 'Request Hash Precedence Completed Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', 13,
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

  IF v_original_hash = v_changed_hash THEN
    RAISE EXCEPTION 'Fixture must use different hashes for prices 12 and 13';
  END IF;

  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL
     OR v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch fixture was not seeded with the expected original hash';
  END IF;

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', (
      SELECT object_id
      FROM public.action_executions
      WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
        AND id = v_execution_id
        AND idempotency_key = 'fixture-hash-mismatch-completed'
    )
  );

  IF v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'COMPLETED fixture does not contain the expected original success result';
  END IF;

  SELECT object_id
  INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-mismatch-completed'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch fixture is missing its original offer';
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-mismatch-completed',
      '{"case":"completed-hash-precedence"}'::jsonb,
      'Request Hash Precedence Completed Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      13,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'COMPLETED hash mismatch must take precedence over success replay; expected IDEMPOTENCY_KEY_REUSE, got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch retry changed or duplicated the idempotency row; expected 1, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch retry changed the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-hash-mismatch-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch retry created or removed an execution; expected 1, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-mismatch-completed'
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch retry changed the original execution result/object';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Request Hash Precedence Completed Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch retry changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'COMPLETED hash-mismatch retry changed or duplicated the original success event';
  END IF;
END
$qa69_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER COMPLETED request_hash precedence assertions passed' AS result;


-- OFFER-QA-70: a COMPLETED idempotency key must reject changed quantity,
-- currency, and attributes independently. The original offer, execution,
-- key/hash/result, and success event must remain unchanged after every retry.
-- All records are synthetic and confined to the disposable PostgreSQL CI DB.
DO $qa70_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"completed-hash-parameter-coverage"}'::jsonb;
  v_base_payload jsonb;
  v_original_hash text;
  v_execution_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_base_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Request Hash Parameter Coverage Completed Fixture Offer',
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
  );
  v_original_hash := md5(v_base_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'Request Hash Parameter Coverage Completed Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    '{}'::jsonb
  );

  v_execution_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-hash-mismatch-completed-parameters', 'COMPLETED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-mismatch-completed-parameters', v_action_id, v_actor_id,
    v_original_hash, v_execution_id, 'COMPLETED',
    v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_execution_result, v_tenant_id
  );
END
$qa70_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa70_assert$
DECLARE
  v_error text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_base_payload jsonb;
  v_original_hash text;
  v_quantity_hash text;
  v_currency_hash text;
  v_attributes_hash text;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', '{"case":"completed-hash-parameter-coverage"}'::jsonb,
    'name', 'Request Hash Parameter Coverage Completed Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
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
  );
  v_original_hash := md5(v_base_payload::text);
  v_quantity_hash := md5(jsonb_set(v_base_payload, '{quantity}', to_jsonb(3::numeric))::text);
  v_currency_hash := md5(jsonb_set(v_base_payload, '{currency}', to_jsonb('EUR'::text))::text);
  v_attributes_hash := md5(jsonb_set(v_base_payload, '{attributes}', '{"grade":"A"}'::jsonb)::text);

  IF v_original_hash = v_quantity_hash
     OR v_original_hash = v_currency_hash
     OR v_original_hash = v_attributes_hash
     OR v_quantity_hash = v_currency_hash
     OR v_quantity_hash = v_attributes_hash
     OR v_currency_hash = v_attributes_hash THEN
    RAISE EXCEPTION 'Each changed effective parameter must produce a distinct fixture hash';
  END IF;

  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-completed-parameters'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL OR v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'COMPLETED parameter fixture was not seeded with the expected original hash';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-mismatch-completed-parameters'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED parameter fixture is missing its original offer';
  END IF;

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'COMPLETED parameter fixture has an unexpected original result';
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-mismatch-completed-parameters',
      '{"case":"completed-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Completed Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      3,
      12,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Changed quantity must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-mismatch-completed-parameters',
      '{"case":"completed-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Completed Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'EUR'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Changed currency must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-mismatch-completed-parameters',
      '{"case":"completed-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Completed Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD',
      NULL,
      NULL,
      NULL,
      '{"grade":"A"}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Changed attributes must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-completed-parameters';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Parameter mismatch retries changed or duplicated the idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-mismatch-completed-parameters'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Parameter mismatch retries changed the original idempotency key/hash/result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-hash-mismatch-completed-parameters';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Parameter mismatch retries created or removed an execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-mismatch-completed-parameters'
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Parameter mismatch retries changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Request Hash Parameter Coverage Completed Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Parameter mismatch retries changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Parameter mismatch retries changed or duplicated the original success event';
  END IF;
END
$qa70_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER quantity, currency, and attributes hash precedence assertions passed' AS result;


-- OFFER-QA-71: changed quantity, currency, and attributes must take request_hash
-- precedence for both FAILED and IN_PROGRESS keys. The stored execution/key
-- rows must remain unchanged, with no offer or action event created.
-- All records are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa71_seed$
DECLARE
  v_action_id uuid;
  v_failed_execution_id uuid := gen_random_uuid();
  v_running_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"failed-running-hash-parameter-coverage"}'::jsonb;
  v_base_payload jsonb;
  v_request_hash text;
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

  v_base_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Request Hash Parameter Coverage Failed Running Fixture Offer',
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
  );
  v_request_hash := md5(v_base_payload::text);

  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_failed_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-parameters-failed', 'FAILED',
    v_input, v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-parameters-failed', v_action_id, v_actor_id,
    v_request_hash, v_failed_execution_id, 'FAILED',
    v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_running_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-parameters-in-progress', 'RUNNING',
    v_input, NULL, NULL, v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-parameters-in-progress', v_action_id, v_actor_id,
    v_request_hash, v_running_execution_id, 'IN_PROGRESS',
    NULL, NULL, v_tenant_id
  );
END
$qa71_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa71_assert$
DECLARE
  v_error text;
  v_failed_execution_id uuid;
  v_running_execution_id uuid;
  v_base_payload jsonb;
  v_original_hash text;
  v_quantity_hash text;
  v_currency_hash text;
  v_attributes_hash text;
  v_failed_result jsonb;
  v_stored_hash text;
  v_expected_failed_result jsonb;
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
    'name', 'Request Hash Parameter Coverage Failed Running Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
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
  );

  v_original_hash := md5(v_base_payload::text);
  v_quantity_hash := md5(jsonb_set(v_base_payload, '{quantity}', to_jsonb(3::numeric))::text);
  v_currency_hash := md5(jsonb_set(v_base_payload, '{currency}', to_jsonb('EUR'::text))::text);
  v_attributes_hash := md5(jsonb_set(v_base_payload, '{attributes}', '{"grade":"A"}'::jsonb)::text);

  IF v_original_hash = v_quantity_hash
     OR v_original_hash = v_currency_hash
     OR v_original_hash = v_attributes_hash
     OR v_quantity_hash = v_currency_hash
     OR v_quantity_hash = v_attributes_hash
     OR v_currency_hash = v_attributes_hash THEN
    RAISE EXCEPTION 'Changed quantity, currency, and attributes must each produce a distinct fixture hash';
  END IF;

  SELECT execution_id, result, request_hash
  INTO v_failed_execution_id, v_failed_result, v_stored_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-parameters-failed'
    AND status = 'FAILED';

  IF v_failed_execution_id IS NULL
     OR v_failed_result IS NULL THEN
    RAISE EXCEPTION 'FAILED parameter fixture was not seeded';
  END IF;

  IF v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'FAILED parameter fixture has an unexpected original hash';
  END IF;

  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );
  IF v_failed_result IS DISTINCT FROM v_expected_failed_result THEN
    RAISE EXCEPTION 'FAILED parameter fixture has an unexpected stored result';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-hash-parameters-failed'
      AND request_hash = v_original_hash
  ) THEN
    RAISE EXCEPTION 'FAILED parameter fixture has an unexpected original hash';
  END IF;

  SELECT execution_id INTO v_running_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-parameters-in-progress'
    AND status = 'IN_PROGRESS'
    AND result IS NULL
    AND request_hash = v_original_hash;

  IF v_running_execution_id IS NULL THEN
    RAISE EXCEPTION 'IN_PROGRESS parameter fixture was not seeded with the expected hash';
  END IF;

  -- FAILED: quantity, currency, and attributes must all fail before replay.
  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-parameters-failed',
      '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Failed Running Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      3, 12, 'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'FAILED changed quantity must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-parameters-failed',
      '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Failed Running Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2, 12, 'EUR'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'FAILED changed currency must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-parameters-failed',
      '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Failed Running Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2, 12, 'USD',
      NULL, NULL, NULL, '{"grade":"A"}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'FAILED changed attributes must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  -- IN_PROGRESS: the same three variations must fail before running-state handling.
  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-parameters-in-progress',
      '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Failed Running Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      3, 12, 'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'IN_PROGRESS changed quantity must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-parameters-in-progress',
      '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Failed Running Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2, 12, 'EUR'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'IN_PROGRESS changed currency must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-hash-parameters-in-progress',
      '{"case":"failed-running-hash-parameter-coverage"}'::jsonb,
      'Request Hash Parameter Coverage Failed Running Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2, 12, 'USD',
      NULL, NULL, NULL, '{"grade":"A"}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;
  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'IN_PROGRESS changed attributes must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  -- Both original idempotency rows and their hashes/results must remain intact.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-hash-parameters-failed',
      'fixture-hash-parameters-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA71 retries changed or duplicated idempotency rows; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-parameters-failed'
    AND status = 'FAILED'
    AND execution_id = v_failed_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_failed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA71 retries changed the original FAILED idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-parameters-in-progress'
    AND status = 'IN_PROGRESS'
    AND execution_id = v_running_execution_id
    AND request_hash = v_original_hash
    AND result IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA71 retries changed the original IN_PROGRESS idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-hash-parameters-failed',
      'fixture-hash-parameters-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA71 retries created or removed executions; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_failed_execution_id
    AND idempotency_key = 'fixture-hash-parameters-failed'
    AND status = 'FAILED'
    AND object_id IS NULL
    AND result = v_expected_failed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA71 retries changed the original FAILED execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_running_execution_id
    AND idempotency_key = 'fixture-hash-parameters-in-progress'
    AND status = 'RUNNING'
    AND object_id IS NULL
    AND result IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA71 retries changed the original RUNNING execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Request Hash Parameter Coverage Failed Running Fixture Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA71 retries unexpectedly created an offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-hash-parameters-failed',
      'fixture-hash-parameters-in-progress'
    );
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA71 retries unexpectedly created action events';
  END IF;
END
$qa71_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER FAILED and IN_PROGRESS quantity, currency, and attributes hash precedence assertions passed' AS result;


-- OFFER-QA-72: JSONB object key order must not change the effective request hash.
-- The same COMPLETED request is replayed with reordered top-level and nested
-- keys in both p_input and p_attributes. The original result and all records
-- must remain unchanged. All records are synthetic and CI-local.
RESET ROLE;

DO $qa72_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input_original jsonb :=
    '{"case":"jsonb-key-order-canonicalization","metadata":{"a":1,"b":2}}'::jsonb;
  v_attributes_original jsonb :=
    '{"grade":"A","metadata":{"x":1,"y":2}}'::jsonb;
  v_base_payload jsonb;
  v_request_hash text;
  v_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_base_payload := jsonb_build_object(
    'input', v_input_original,
    'name', 'JSONB Key Order Canonicalization Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', v_actor_id,
    'quantity', 2,
    'price', 12,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', v_attributes_original,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_request_hash := md5(v_base_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'JSONB Key Order Canonicalization Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    v_attributes_original
  );

  v_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-jsonb-key-order-completed', 'COMPLETED',
    v_input_original, v_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-jsonb-key-order-completed', v_action_id, v_actor_id,
    v_request_hash, v_execution_id, 'COMPLETED',
    v_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_result, v_tenant_id
  );
END
$qa72_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa72_assert$
DECLARE
  v_input_original jsonb :=
    '{"case":"jsonb-key-order-canonicalization","metadata":{"a":1,"b":2}}'::jsonb;
  v_input_reordered jsonb :=
    '{"metadata":{"b":2,"a":1},"case":"jsonb-key-order-canonicalization"}'::jsonb;
  v_attributes_original jsonb :=
    '{"grade":"A","metadata":{"x":1,"y":2}}'::jsonb;
  v_attributes_reordered jsonb :=
    '{"metadata":{"y":2,"x":1},"grade":"A"}'::jsonb;
  v_base_payload jsonb;
  v_reordered_payload jsonb;
  v_original_hash text;
  v_reordered_hash text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_actual jsonb;
  v_count integer;
BEGIN
  IF v_input_original IS DISTINCT FROM v_input_reordered
     OR v_input_original::text IS DISTINCT FROM v_input_reordered::text THEN
    RAISE EXCEPTION 'Reordered input objects must be equal JSONB with identical canonical text';
  END IF;

  IF v_attributes_original IS DISTINCT FROM v_attributes_reordered
     OR v_attributes_original::text IS DISTINCT FROM v_attributes_reordered::text THEN
    RAISE EXCEPTION 'Reordered attribute objects must be equal JSONB with identical canonical text';
  END IF;

  v_base_payload := jsonb_build_object(
    'input', v_input_original,
    'name', 'JSONB Key Order Canonicalization Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', 12,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', v_attributes_original,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  v_reordered_payload := jsonb_build_object(
    'input', v_input_reordered,
    'name', 'JSONB Key Order Canonicalization Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', 12,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', v_attributes_reordered,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  IF v_base_payload IS DISTINCT FROM v_reordered_payload
     OR v_base_payload::text IS DISTINCT FROM v_reordered_payload::text THEN
    RAISE EXCEPTION 'Equivalent effective request payloads must have identical JSONB values and text';
  END IF;

  v_original_hash := md5(v_base_payload::text);
  v_reordered_hash := md5(v_reordered_payload::text);
  IF v_original_hash IS DISTINCT FROM v_reordered_hash THEN
    RAISE EXCEPTION 'Equivalent effective request payloads must produce the same hash';
  END IF;

  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-jsonb-key-order-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL
     OR v_stored_hash IS DISTINCT FROM v_original_hash
     OR v_stored_hash IS DISTINCT FROM v_reordered_hash THEN
    RAISE EXCEPTION 'Stored idempotency row does not match the canonical request hash';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-jsonb-key-order-completed'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED canonicalization fixture is missing its original offer';
  END IF;

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'Canonicalization fixture has an unexpected stored result';
  END IF;

  SELECT public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-jsonb-key-order-completed',
    v_input_reordered,
    'JSONB Key Order Canonicalization Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2,
    12,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_reordered,
    NULL,
    NULL,
    NULL,
    NULL
  ) INTO v_actual;

  IF v_actual IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'Reordered JSONB replay did not return the original result; got %',
      coalesce(v_actual::text, '<SQL NULL>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-jsonb-key-order-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Canonical JSONB replay changed or duplicated the idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-jsonb-key-order-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Canonical JSONB replay changed the original idempotency key/hash/result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-jsonb-key-order-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Canonical JSONB replay created or removed an execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-jsonb-key-order-completed'
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND input = v_input_original
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Canonical JSONB replay changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'JSONB Key Order Canonicalization Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = v_attributes_original;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Canonical JSONB replay changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Canonical JSONB replay changed or duplicated the original success event';
  END IF;
END
$qa72_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER JSONB key-order canonical hash replay assertions passed' AS result;


-- OFFER-QA-73: characterize numerically equal JSONB values with different scales.
-- PostgreSQL JSONB equality treats 1 and 1.0 as equal, while jsonb::text
-- preserves the numeric scale. This fixture records the current hash/replay
-- behavior without changing the function or any production object.
RESET ROLE;

DO $qa73_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"jsonb-numeric-scale","amount":1}'::jsonb;
  v_payload jsonb;
  v_hash text;
  v_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_payload := jsonb_build_object(
    'input', v_input,
    'name', 'JSONB Numeric Scale Characterization Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', v_actor_id,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_hash := md5(v_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'JSONB Numeric Scale Characterization Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    '{}'::jsonb
  );

  v_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-jsonb-numeric-scale-completed', 'COMPLETED',
    v_input, v_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-jsonb-numeric-scale-completed', v_action_id, v_actor_id,
    v_hash, v_execution_id, 'COMPLETED', v_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_result, v_tenant_id
  );
END
$qa73_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa73_assert$
DECLARE
  v_integer_input jsonb := '{"case":"jsonb-numeric-scale","amount":1}'::jsonb;
  v_decimal_input jsonb := '{"case":"jsonb-numeric-scale","amount":1.0}'::jsonb;
  v_integer_payload jsonb;
  v_decimal_payload jsonb;
  v_original_hash text;
  v_decimal_hash text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_actual jsonb;
  v_error text;
  v_count integer;
BEGIN
  IF v_integer_input IS DISTINCT FROM v_decimal_input THEN
    RAISE EXCEPTION 'JSONB numeric values 1 and 1.0 are expected to compare equal';
  END IF;

  IF v_integer_input::text IS NOT DISTINCT FROM v_decimal_input::text THEN
    RAISE EXCEPTION 'Characterization requires jsonb::text to preserve the numeric scale difference';
  END IF;

  v_integer_payload := jsonb_build_object(
    'input', v_integer_input,
    'name', 'JSONB Numeric Scale Characterization Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  v_decimal_payload := jsonb_build_object(
    'input', v_decimal_input,
    'name', 'JSONB Numeric Scale Characterization Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  IF v_integer_payload IS DISTINCT FROM v_decimal_payload THEN
    RAISE EXCEPTION 'Effective JSONB payloads should remain numerically equal';
  END IF;

  IF v_integer_payload::text IS NOT DISTINCT FROM v_decimal_payload::text THEN
    RAISE EXCEPTION 'Effective payload text unexpectedly normalized numeric scale';
  END IF;

  v_original_hash := md5(v_integer_payload::text);
  v_decimal_hash := md5(v_decimal_payload::text);
  IF v_original_hash IS NOT DISTINCT FROM v_decimal_hash THEN
    RAISE EXCEPTION 'Different numeric-scale text representations unexpectedly produced the same MD5';
  END IF;

  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-jsonb-numeric-scale-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL
     OR v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'Stored idempotency hash does not match the integer-scale request';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-jsonb-numeric-scale-completed'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'Numeric-scale fixture is missing its original offer';
  END IF;

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'Numeric-scale fixture has an unexpected stored result';
  END IF;

  v_error := NULL;
  BEGIN
    v_actual := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-jsonb-numeric-scale-completed',
      v_decimal_input,
      'JSONB Numeric Scale Characterization Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2,
      12,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Current numeric-scale replay behavior expected IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-jsonb-numeric-scale-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Numeric-scale characterization changed or duplicated the idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-jsonb-numeric-scale-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Numeric-scale characterization changed the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-jsonb-numeric-scale-completed'
    AND id = v_execution_id
    AND status = 'COMPLETED'
    AND input::text = v_integer_input::text
    AND result = v_expected_result
    AND object_id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Numeric-scale characterization changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'JSONB Numeric Scale Characterization Fixture Offer'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Numeric-scale characterization changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Numeric-scale characterization changed or duplicated the original success event';
  END IF;
END
$qa73_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER JSONB numeric-scale hash characterization assertions passed' AS result;


-- OFFER-QA-74: characterize numeric scale in the typed quantity and price arguments.
-- The function hashes jsonb_build_object(..., 'quantity', p_quantity, 'price', p_price, ...).
-- Keep quantity and price cases separate so each typed argument is varied independently.
-- This is a disposable PostgreSQL characterization; it does not change the function.
RESET ROLE;

DO $qa74_seed$
DECLARE
  v_action_id uuid;
  v_quantity_execution_id uuid := gen_random_uuid();
  v_quantity_offer_id uuid := gen_random_uuid();
  v_quantity_correlation_id uuid := gen_random_uuid();
  v_price_execution_id uuid := gen_random_uuid();
  v_price_offer_id uuid := gen_random_uuid();
  v_price_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"typed-numeric-scale"}'::jsonb;
  v_payload jsonb;
  v_hash text;
  v_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  -- Quantity-scale baseline: p_quantity = 2::numeric, p_price = 12::numeric.
  v_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Typed Numeric Quantity Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', v_actor_id,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_hash := md5(v_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_quantity_offer_id,
    'Typed Numeric Quantity Scale Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id, 2, 12, 'USD', '{}'::jsonb
  );

  v_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_quantity_execution_id,
    'objectType', 'Offer',
    'objectId', v_quantity_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_quantity_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_quantity_offer_id,
    v_quantity_correlation_id, 'fixture-typed-quantity-scale-completed',
    'COMPLETED', v_input, v_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-typed-quantity-scale-completed', v_action_id, v_actor_id,
    v_hash, v_quantity_execution_id, 'COMPLETED', v_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_quantity_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_quantity_offer_id, v_quantity_correlation_id, v_result, v_tenant_id
  );

  -- Price-scale baseline: p_quantity = 2::numeric, p_price = 12::numeric.
  v_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Typed Numeric Price Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', v_actor_id,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_hash := md5(v_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_price_offer_id,
    'Typed Numeric Price Scale Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id, 2, 12, 'USD', '{}'::jsonb
  );

  v_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_price_execution_id,
    'objectType', 'Offer',
    'objectId', v_price_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_price_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_price_offer_id,
    v_price_correlation_id, 'fixture-typed-price-scale-completed',
    'COMPLETED', v_input, v_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-typed-price-scale-completed', v_action_id, v_actor_id,
    v_hash, v_price_execution_id, 'COMPLETED', v_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_price_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_price_offer_id, v_price_correlation_id, v_result, v_tenant_id
  );
END
$qa74_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa74_assert$
DECLARE
  v_input jsonb := '{"case":"typed-numeric-scale"}'::jsonb;
  v_quantity_base jsonb;
  v_quantity_scaled jsonb;
  v_price_base jsonb;
  v_price_scaled jsonb;
  v_quantity_hash text;
  v_quantity_scaled_hash text;
  v_price_hash text;
  v_price_scaled_hash text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_actual jsonb;
  v_error text;
  v_count integer;
BEGIN
  v_quantity_base := jsonb_build_object(
    'input', v_input,
    'name', 'Typed Numeric Quantity Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_quantity_scaled := jsonb_build_object(
    'input', v_input,
    'name', 'Typed Numeric Quantity Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2.0::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  IF v_quantity_base IS DISTINCT FROM v_quantity_scaled THEN
    RAISE EXCEPTION 'Typed numeric quantity values 2 and 2.0 should compare equal as JSONB';
  END IF;
  IF v_quantity_base::text IS NOT DISTINCT FROM v_quantity_scaled::text THEN
    RAISE EXCEPTION 'Typed numeric quantity scale should remain visible in jsonb::text';
  END IF;
  v_quantity_hash := md5(v_quantity_base::text);
  v_quantity_scaled_hash := md5(v_quantity_scaled::text);
  IF v_quantity_hash IS NOT DISTINCT FROM v_quantity_scaled_hash THEN
    RAISE EXCEPTION 'Typed numeric quantity scale unexpectedly produced the same hash';
  END IF;

  v_price_base := jsonb_build_object(
    'input', v_input,
    'name', 'Typed Numeric Price Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_price_scaled := jsonb_build_object(
    'input', v_input,
    'name', 'Typed Numeric Price Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12.0::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  IF v_price_base IS DISTINCT FROM v_price_scaled THEN
    RAISE EXCEPTION 'Typed numeric price values 12 and 12.0 should compare equal as JSONB';
  END IF;
  IF v_price_base::text IS NOT DISTINCT FROM v_price_scaled::text THEN
    RAISE EXCEPTION 'Typed numeric price scale should remain visible in jsonb::text';
  END IF;
  v_price_hash := md5(v_price_base::text);
  v_price_scaled_hash := md5(v_price_scaled::text);
  IF v_price_hash IS NOT DISTINCT FROM v_price_scaled_hash THEN
    RAISE EXCEPTION 'Typed numeric price scale unexpectedly produced the same hash';
  END IF;

  -- Replay with only p_quantity changed from 2 to 2.0.
  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-typed-quantity-scale-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL OR v_stored_hash IS DISTINCT FROM v_quantity_hash THEN
    RAISE EXCEPTION 'Stored quantity-scale hash does not match the integer-scale request';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-typed-quantity-scale-completed'
    AND status = 'COMPLETED';

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_offer_id IS NULL OR v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'Quantity-scale fixture has an unexpected stored result';
  END IF;

  v_error := NULL;
  BEGIN
    v_actual := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-typed-quantity-scale-completed',
      v_input,
      'Typed Numeric Quantity Scale Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2.0::numeric,
      12::numeric,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Typed quantity-scale replay expected IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-typed-quantity-scale-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_quantity_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Quantity-scale replay changed or duplicated the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-typed-quantity-scale-completed'
    AND status = 'COMPLETED'
    AND input = v_input
    AND result = v_expected_result
    AND object_id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Quantity-scale replay changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Typed Numeric Quantity Scale Fixture Offer'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Quantity-scale replay changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Quantity-scale replay changed or duplicated the original success event';
  END IF;

  -- Replay with only p_price changed from 12 to 12.0.
  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-typed-price-scale-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL OR v_stored_hash IS DISTINCT FROM v_price_hash THEN
    RAISE EXCEPTION 'Stored price-scale hash does not match the integer-scale request';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-typed-price-scale-completed'
    AND status = 'COMPLETED';

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_offer_id IS NULL OR v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'Price-scale fixture has an unexpected stored result';
  END IF;

  v_error := NULL;
  BEGIN
    v_actual := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-typed-price-scale-completed',
      v_input,
      'Typed Numeric Price Scale Fixture Offer',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      2::numeric,
      12.0::numeric,
      'USD'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Typed price-scale replay expected IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-typed-price-scale-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_price_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Price-scale replay changed or duplicated the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-typed-price-scale-completed'
    AND status = 'COMPLETED'
    AND input = v_input
    AND result = v_expected_result
    AND object_id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Price-scale replay changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Typed Numeric Price Scale Fixture Offer'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Price-scale replay changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Price-scale replay changed or duplicated the original success event';
  END IF;
END
$qa74_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER typed numeric quantity and price scale characterization assertions passed' AS result;


-- OFFER-QA-75: characterize numeric scale inside nested p_attributes JSONB.
-- The effective CREATE_OFFER hash includes coalesce(p_attributes, '{}'::jsonb).
-- Keep the nested numeric value as the only changed business input.
-- This disposable PostgreSQL fixture documents current behavior; it does not alter the function.
RESET ROLE;

DO $qa75_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"nested-attributes-numeric-scale"}'::jsonb;
  v_attributes jsonb := '{"grade":"A","spec":{"weight":1}}'::jsonb;
  v_payload jsonb;
  v_hash text;
  v_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Nested Attributes Numeric Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', v_actor_id,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', coalesce(v_attributes, '{}'::jsonb),
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );
  v_hash := md5(v_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    v_offer_id,
    'Nested Attributes Numeric Scale Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    v_attributes
  );

  v_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-nested-attributes-numeric-scale-completed',
    'COMPLETED', v_input, v_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-nested-attributes-numeric-scale-completed',
    v_action_id, v_actor_id, v_hash, v_execution_id,
    'COMPLETED', v_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_result, v_tenant_id
  );
END
$qa75_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa75_assert$
DECLARE
  v_input jsonb := '{"case":"nested-attributes-numeric-scale"}'::jsonb;
  v_original_attributes jsonb := '{"grade":"A","spec":{"weight":1}}'::jsonb;
  v_scaled_attributes jsonb := '{"grade":"A","spec":{"weight":1.0}}'::jsonb;
  v_original_payload jsonb;
  v_scaled_payload jsonb;
  v_original_hash text;
  v_scaled_hash text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_actual jsonb;
  v_error text;
  v_count integer;
BEGIN
  IF v_original_attributes IS DISTINCT FROM v_scaled_attributes THEN
    RAISE EXCEPTION 'Nested JSONB numeric values 1 and 1.0 should compare equal';
  END IF;

  IF v_original_attributes::text IS NOT DISTINCT FROM v_scaled_attributes::text THEN
    RAISE EXCEPTION 'Nested JSONB numeric scale should remain visible in jsonb::text';
  END IF;

  v_original_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Nested Attributes Numeric Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', coalesce(v_original_attributes, '{}'::jsonb),
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  v_scaled_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Nested Attributes Numeric Scale Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', coalesce(v_scaled_attributes, '{}'::jsonb),
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  );

  IF v_original_payload IS DISTINCT FROM v_scaled_payload THEN
    RAISE EXCEPTION 'Effective payloads should remain JSONB-equal when nested numeric scale changes';
  END IF;

  IF v_original_payload::text IS NOT DISTINCT FROM v_scaled_payload::text THEN
    RAISE EXCEPTION 'Effective payload text unexpectedly normalized nested numeric scale';
  END IF;

  v_original_hash := md5(v_original_payload::text);
  v_scaled_hash := md5(v_scaled_payload::text);
  IF v_original_hash IS NOT DISTINCT FROM v_scaled_hash THEN
    RAISE EXCEPTION 'Nested numeric scale unexpectedly produced the same effective request hash';
  END IF;

  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-nested-attributes-numeric-scale-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL OR v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'Stored hash does not match the original nested-attributes request';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-nested-attributes-numeric-scale-completed'
    AND status = 'COMPLETED';

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  IF v_offer_id IS NULL OR v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'Nested-attributes fixture has an unexpected original result';
  END IF;

  v_error := NULL;
  BEGIN
    v_actual := public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-nested-attributes-numeric-scale-completed',
      p_input => v_input,
      p_name => 'Nested Attributes Numeric Scale Fixture Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2::numeric,
      p_price => 12::numeric,
      p_currency => 'USD',
      p_attributes => v_scaled_attributes
    );
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLERRM;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'Nested attributes numeric-scale replay expected IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-nested-attributes-numeric-scale-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Nested-attributes replay changed or duplicated the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-nested-attributes-numeric-scale-completed'
    AND status = 'COMPLETED'
    AND input = v_input
    AND result = v_expected_result
    AND object_id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Nested-attributes replay changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Nested Attributes Numeric Scale Fixture Offer'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = v_original_attributes;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Nested-attributes replay changed the original offer attributes';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Nested-attributes replay changed or duplicated the original success event';
  END IF;
END
$qa75_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER nested p_attributes numeric-scale hash characterization assertions passed' AS result;


-- OFFER-QA-76: characterize SQL NULL and empty-object equivalence for p_attributes.
-- Exercise both replay directions with independent idempotency keys. The function
-- hashes coalesce(p_attributes, '{}'::jsonb), and create_offer_v1 persists the
-- same normalized empty object. These are disposable CI fixtures only.
SET ROLE authenticated;

DO $qa76_assert$
DECLARE
  v_case record;
  v_input jsonb;
  v_name text;
  v_key text;
  v_payload_null jsonb;
  v_payload_empty jsonb;
  v_hash_null text;
  v_hash_empty text;
  v_result jsonb;
  v_retry jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_count integer;
BEGIN
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('null-to-empty', true),
      ('empty-to-null', false)
    ) AS cases(direction, first_is_null)
  LOOP
    v_input := jsonb_build_object(
      'case', 'attributes-sql-null-empty',
      'direction', v_case.direction
    );
    v_name := 'Attributes SQL NULL Empty ' || v_case.direction;
    v_key := 'fixture-attributes-sql-null-empty-' || v_case.direction;

    -- Mirror the complete effective hash payload in the same field contract
    -- as execute_create_offer_v1; only the SQL representation of attributes
    -- differs before COALESCE.
    v_payload_null := jsonb_build_object(
      'input', v_input,
      'name', v_name,
      'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1::numeric,
      'price', 10::numeric,
      'currency', 'USD',
      'conditions', NULL,
      'market', NULL,
      'geography', NULL,
      'attributes', coalesce(NULL::jsonb, '{}'::jsonb),
      'documentationStatus', NULL,
      'lifecycle', NULL,
      'offerType', NULL,
      'pricingModel', NULL
    );
    v_payload_empty := jsonb_build_object(
      'input', v_input,
      'name', v_name,
      'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1::numeric,
      'price', 10::numeric,
      'currency', 'USD',
      'conditions', NULL,
      'market', NULL,
      'geography', NULL,
      'attributes', coalesce('{}'::jsonb, '{}'::jsonb),
      'documentationStatus', NULL,
      'lifecycle', NULL,
      'offerType', NULL,
      'pricingModel', NULL
    );

    IF v_payload_null IS DISTINCT FROM v_payload_empty THEN
      RAISE EXCEPTION 'SQL NULL and empty attributes must produce equal effective JSONB payloads';
    END IF;
    IF v_payload_null::text IS DISTINCT FROM v_payload_empty::text THEN
      RAISE EXCEPTION 'SQL NULL and empty attributes must produce identical effective payload text';
    END IF;

    v_hash_null := md5(v_payload_null::text);
    v_hash_empty := md5(v_payload_empty::text);
    IF v_hash_null IS DISTINCT FROM v_hash_empty THEN
      RAISE EXCEPTION 'SQL NULL and empty attributes must produce identical effective request hashes';
    END IF;

    IF v_case.first_is_null THEN
      v_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => NULL
      );
      v_retry := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => '{}'::jsonb
      );
    ELSE
      v_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => '{}'::jsonb
      );
      v_retry := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => NULL
      );
    END IF;

    IF v_result->>'status' IS DISTINCT FROM 'succeeded' THEN
      RAISE EXCEPTION 'Initial % request did not succeed: %', v_case.direction, v_result;
    END IF;
    IF v_retry IS DISTINCT FROM v_result THEN
      RAISE EXCEPTION 'SQL NULL/empty attributes replay failed for direction %', v_case.direction;
    END IF;

    SELECT execution_id, request_hash, result
    INTO v_execution_id, v_stored_hash, v_stored_result
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED';

    IF v_execution_id IS NULL
       OR v_stored_hash IS DISTINCT FROM v_hash_null
       OR v_stored_result IS DISTINCT FROM v_result THEN
      RAISE EXCEPTION 'Stored idempotency row does not match the normalized % request', v_case.direction;
    END IF;

    SELECT object_id INTO v_offer_id
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_result;

    IF v_offer_id IS NULL THEN
      RAISE EXCEPTION 'Original % execution is missing or changed', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED'
      AND execution_id = v_execution_id
      AND request_hash = v_hash_null
      AND result = v_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged idempotency row for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_result
      AND object_id = v_offer_id;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged execution for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name
      AND quantity = 1
      AND price = 10
      AND currency = 'USD'
      AND attributes = '{}'::jsonb;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected one offer with normalized empty attributes for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_events
    WHERE execution_id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND event_type = 'ACTION_SUCCEEDED'
      AND object_type = 'Offer'
      AND object_id = v_offer_id
      AND payload = v_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged success event for %', v_case.direction;
    END IF;
  END LOOP;
END
$qa76_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER SQL NULL and empty p_attributes bidirectional replay assertions passed' AS result;


-- OFFER-QA-77: distinguish SQL NULL, JSONB null, and empty-object p_attributes.
-- COALESCE normalizes SQL NULL to {}, but JSONB null is a non-NULL JSON value.
-- Characterize both mismatching replay directions and an identical JSONB-null replay.
-- All fixtures are disposable CI data; do not change the function or migration here.
RESET ROLE;
SET ROLE authenticated;

DO $qa77_assert$
DECLARE
  v_case record;
  v_input jsonb;
  v_name text;
  v_key text;
  v_base_payload jsonb;
  v_first_payload jsonb;
  v_retry_payload jsonb;
  v_first_hash text;
  v_retry_hash text;
  v_first_result jsonb;
  v_retry_result jsonb;
  v_error text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_persisted_attributes jsonb;
  v_count integer;
BEGIN
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('sql-null-to-json-null', NULL::jsonb, 'null'::jsonb, 'IDEMPOTENCY_KEY_REUSE'::text),
      ('json-null-to-sql-null', 'null'::jsonb, NULL::jsonb, 'IDEMPOTENCY_KEY_REUSE'::text),
      ('empty-to-json-null', '{}'::jsonb, 'null'::jsonb, 'IDEMPOTENCY_KEY_REUSE'::text),
      ('json-null-identical-replay', 'null'::jsonb, 'null'::jsonb, NULL::text)
    ) AS cases(direction, first_attributes, retry_attributes, expected_error)
  LOOP
    v_input := jsonb_build_object(
      'case', 'attributes-json-null-distinction',
      'direction', v_case.direction
    );
    v_name := 'Attributes JSON null ' || v_case.direction;
    v_key := 'fixture-attributes-json-null-' || v_case.direction;

    -- Mirror the complete effective CREATE_OFFER hash payload. Only attributes
    -- vary between the first call and its replay.
    v_base_payload := jsonb_build_object(
      'input', v_input,
      'name', v_name,
      'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1::numeric,
      'price', 10::numeric,
      'currency', 'USD',
      'conditions', NULL,
      'market', NULL,
      'geography', NULL,
      'attributes', '{}'::jsonb,
      'documentationStatus', NULL,
      'lifecycle', NULL,
      'offerType', NULL,
      'pricingModel', NULL
    );
    v_first_payload := jsonb_set(
      v_base_payload,
      '{attributes}',
      coalesce(v_case.first_attributes, '{}'::jsonb)
    );
    v_retry_payload := jsonb_set(
      v_base_payload,
      '{attributes}',
      coalesce(v_case.retry_attributes, '{}'::jsonb)
    );
    v_first_hash := md5(v_first_payload::text);
    v_retry_hash := md5(v_retry_payload::text);

    IF v_case.expected_error IS NULL THEN
      IF v_first_payload IS DISTINCT FROM v_retry_payload
         OR v_first_payload::text IS DISTINCT FROM v_retry_payload::text
         OR v_first_hash IS DISTINCT FROM v_retry_hash THEN
        RAISE EXCEPTION 'Identical JSONB-null replay must produce the same effective payload and hash';
      END IF;
    ELSE
      IF v_first_payload IS NOT DISTINCT FROM v_retry_payload
         OR v_first_hash IS NOT DISTINCT FROM v_retry_hash THEN
        RAISE EXCEPTION 'Expected distinct effective payloads and hashes for %', v_case.direction;
      END IF;
    END IF;

    v_first_result := public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => v_key,
      p_input => v_input,
      p_name => v_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 1::numeric,
      p_price => 10::numeric,
      p_currency => 'USD',
      p_attributes => v_case.first_attributes
    );

    IF v_first_result->>'status' IS DISTINCT FROM 'succeeded' THEN
      RAISE EXCEPTION 'Initial % request did not succeed: %', v_case.direction, v_first_result;
    END IF;

    v_error := NULL;
    v_retry_result := NULL;
    BEGIN
      v_retry_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => v_case.retry_attributes
      );
    EXCEPTION WHEN OTHERS THEN
      v_error := SQLERRM;
    END;

    IF v_case.expected_error IS NULL THEN
      IF v_error IS NOT NULL OR v_retry_result IS DISTINCT FROM v_first_result THEN
        RAISE EXCEPTION 'Identical JSONB-null replay failed: error %, result %', v_error, v_retry_result;
      END IF;
    ELSIF v_error IS DISTINCT FROM v_case.expected_error THEN
      RAISE EXCEPTION 'Replay % expected %, got %',
        v_case.direction, v_case.expected_error, coalesce(v_error, '<no error>');
    END IF;

    SELECT execution_id, request_hash, result
    INTO v_execution_id, v_stored_hash, v_stored_result
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED';

    IF v_execution_id IS NULL
       OR v_stored_hash IS DISTINCT FROM v_first_hash
       OR v_stored_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'Stored idempotency row does not match the original % request', v_case.direction;
    END IF;

    SELECT object_id INTO v_offer_id
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_first_result;

    IF v_offer_id IS NULL THEN
      RAISE EXCEPTION 'Original % execution is missing or changed', v_case.direction;
    END IF;

    SELECT attributes INTO v_persisted_attributes
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name;

    IF NOT FOUND OR v_persisted_attributes IS DISTINCT FROM
       coalesce(v_case.first_attributes, '{}'::jsonb) THEN
      RAISE EXCEPTION 'Persisted attributes do not match the normalized original value for %', v_case.direction;
    END IF;

    IF v_persisted_attributes IS NULL THEN
      RAISE EXCEPTION 'offers.attributes unexpectedly contains SQL NULL for %', v_case.direction;
    END IF;

    IF v_case.first_attributes = 'null'::jsonb
       AND jsonb_typeof(v_persisted_attributes) IS DISTINCT FROM 'null' THEN
      RAISE EXCEPTION 'JSONB null must remain a JSONB null value for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED'
      AND execution_id = v_execution_id
      AND request_hash = v_first_hash
      AND result = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged idempotency row for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_first_result
      AND object_id = v_offer_id;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged execution for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name
      AND quantity = 1
      AND price = 10
      AND currency = 'USD'
      AND attributes = coalesce(v_case.first_attributes, '{}'::jsonb);
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one offer with original normalized attributes for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_events
    WHERE execution_id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND event_type = 'ACTION_SUCCEEDED'
      AND object_type = 'Offer'
      AND object_id = v_offer_id
      AND payload = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged success event for %', v_case.direction;
    END IF;
  END LOOP;
END
$qa77_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER SQL NULL, JSONB null, and empty-object p_attributes characterization assertions passed' AS result;


-- OFFER-QA-78: verify the p_attributes DEFAULT '{}'::jsonb argument contract.
-- Exercise both directions: omitted argument -> explicit {}, and explicit {} -> omitted argument.
-- The calls below intentionally omit p_attributes; all later optional parameters retain their SQL defaults.
-- These fixtures are disposable CI data only.
RESET ROLE;
SET ROLE authenticated;

DO $qa78_assert$
DECLARE
  v_case record;
  v_input jsonb;
  v_name text;
  v_key text;
  v_effective_payload jsonb;
  v_expected_hash text;
  v_first_result jsonb;
  v_retry_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_persisted_attributes jsonb;
  v_count integer;
BEGIN
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('default-to-explicit-empty', true),
      ('explicit-empty-to-default', false)
    ) AS cases(direction, first_uses_default)
  LOOP
    v_input := jsonb_build_object(
      'case', 'attributes-default-empty-replay',
      'direction', v_case.direction
    );
    v_name := 'Attributes Default Empty ' || v_case.direction;
    v_key := 'fixture-attributes-default-empty-' || v_case.direction;

    -- Match the complete effective hash payload from execute_create_offer_v1.
    -- The omitted p_attributes argument resolves to its declared '{}'::jsonb default.
    v_effective_payload := jsonb_build_object(
      'input', v_input,
      'name', v_name,
      'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1::numeric,
      'price', 10::numeric,
      'currency', 'USD',
      'conditions', NULL,
      'market', NULL,
      'geography', NULL,
      'attributes', '{}'::jsonb,
      'documentationStatus', NULL,
      'lifecycle', NULL,
      'offerType', NULL,
      'pricingModel', NULL
    );
    v_expected_hash := md5(v_effective_payload::text);

    IF v_case.first_uses_default THEN
      -- Intentionally omit p_attributes and every later optional argument.
      v_first_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD'
      );
      v_retry_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => '{}'::jsonb
      );
    ELSE
      v_first_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => '{}'::jsonb
      );
      -- Intentionally omit p_attributes and every later optional argument.
      v_retry_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD'
      );
    END IF;

    IF v_first_result->>'status' IS DISTINCT FROM 'succeeded' THEN
      RAISE EXCEPTION 'Initial % request did not succeed: %', v_case.direction, v_first_result;
    END IF;
    IF v_retry_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'Default/explicit-empty replay returned a different result for %: %',
        v_case.direction, v_retry_result;
    END IF;

    SELECT execution_id, request_hash, result
    INTO v_execution_id, v_stored_hash, v_stored_result
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED';

    IF v_execution_id IS NULL
       OR v_stored_hash IS DISTINCT FROM v_expected_hash
       OR v_stored_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'Stored idempotency row does not match the effective default payload for %',
        v_case.direction;
    END IF;

    SELECT object_id INTO v_offer_id
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_first_result;

    IF v_offer_id IS NULL THEN
      RAISE EXCEPTION 'Original execution is missing or changed for %', v_case.direction;
    END IF;

    SELECT attributes INTO v_persisted_attributes
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name;

    IF NOT FOUND OR v_persisted_attributes IS DISTINCT FROM '{}'::jsonb THEN
      RAISE EXCEPTION 'Default p_attributes must persist as an empty JSON object for %',
        v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED'
      AND execution_id = v_execution_id
      AND request_hash = v_expected_hash
      AND result = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged idempotency row for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_first_result
      AND object_id = v_offer_id;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged execution for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name
      AND quantity = 1
      AND price = 10
      AND currency = 'USD'
      AND attributes = '{}'::jsonb;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one offer with default empty attributes for %',
        v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_events
    WHERE execution_id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND event_type = 'ACTION_SUCCEEDED'
      AND object_type = 'Offer'
      AND object_id = v_offer_id
      AND payload = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged success event for %', v_case.direction;
    END IF;
  END LOOP;
END
$qa78_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER p_attributes default and explicit-empty bidirectional replay assertions passed' AS result;


-- OFFER-QA-79: verify NULL-defaulted optional business parameters.
-- Compare omitting all NULL-defaulted arguments with supplying explicit SQL NULLs,
-- in both directions. p_attributes stays explicitly '{}' to isolate these fields.
-- These fixtures are disposable CI data only.
RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa79_assert$
DECLARE
  v_case record;
  v_input jsonb;
  v_name text;
  v_key text;
  v_effective_payload jsonb;
  v_expected_hash text;
  v_first_result jsonb;
  v_retry_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_persisted_conditions text;
  v_persisted_market text;
  v_persisted_geography text;
  v_persisted_documentation_status text;
  v_persisted_lifecycle text;
  v_persisted_offer_type text;
  v_persisted_pricing_model text;
  v_persisted_attributes jsonb;
  v_count integer;
BEGIN
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('omitted-to-explicit-null', true),
      ('explicit-null-to-omitted', false)
    ) AS cases(direction, first_omits_null_defaults)
  LOOP
    v_input := jsonb_build_object(
      'case', 'null-defaulted-optional-parameters',
      'direction', v_case.direction
    );
    v_name := 'Optional NULL Defaults ' || v_case.direction;
    v_key := 'fixture-optional-null-defaults-' || v_case.direction;

    -- Match the complete effective request hash. Every optional text parameter
    -- under test resolves to SQL NULL in either call representation.
    v_effective_payload := jsonb_build_object(
      'input', v_input,
      'name', v_name,
      'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1::numeric,
      'price', 10::numeric,
      'currency', 'USD',
      'conditions', NULL,
      'market', NULL,
      'geography', NULL,
      'attributes', '{}'::jsonb,
      'documentationStatus', NULL,
      'lifecycle', NULL,
      'offerType', NULL,
      'pricingModel', NULL
    );
    v_expected_hash := md5(v_effective_payload::text);

    IF v_case.first_omits_null_defaults THEN
      -- Omit p_conditions, p_market, p_geography, p_documentation_status,
      -- p_lifecycle, p_offer_type and p_pricing_model. Keep attributes explicit.
      v_first_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => '{}'::jsonb
      );
      v_retry_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_conditions => NULL::text,
        p_market => NULL::text,
        p_geography => NULL::text,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL::text,
        p_lifecycle => NULL::text,
        p_offer_type => NULL::text,
        p_pricing_model => NULL::text
      );
    ELSE
      v_first_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_conditions => NULL::text,
        p_market => NULL::text,
        p_geography => NULL::text,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL::text,
        p_lifecycle => NULL::text,
        p_offer_type => NULL::text,
        p_pricing_model => NULL::text
      );
      -- Omit all seven NULL-defaulted parameters on the replay.
      v_retry_result := public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => v_input,
        p_name => v_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => 10::numeric,
        p_currency => 'USD',
        p_attributes => '{}'::jsonb
      );
    END IF;

    IF v_first_result->>'status' IS DISTINCT FROM 'succeeded' THEN
      RAISE EXCEPTION 'Initial % request did not succeed: %', v_case.direction, v_first_result;
    END IF;
    IF v_retry_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'Omitted/explicit-NULL replay returned a different result for %: %',
        v_case.direction, v_retry_result;
    END IF;

    SELECT execution_id, request_hash, result
    INTO v_execution_id, v_stored_hash, v_stored_result
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED';

    IF v_execution_id IS NULL
       OR v_stored_hash IS DISTINCT FROM v_expected_hash
       OR v_stored_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'Stored idempotency row does not match NULL-default payload for %',
        v_case.direction;
    END IF;

    SELECT object_id INTO v_offer_id
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_first_result;

    IF v_offer_id IS NULL THEN
      RAISE EXCEPTION 'Original execution is missing or changed for %', v_case.direction;
    END IF;

    SELECT conditions, market, geography, documentation_status,
           lifecycle, offer_type, pricing_model, attributes
    INTO v_persisted_conditions, v_persisted_market, v_persisted_geography,
         v_persisted_documentation_status, v_persisted_lifecycle,
         v_persisted_offer_type, v_persisted_pricing_model, v_persisted_attributes
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name;

    IF NOT FOUND
       OR v_persisted_conditions IS NOT NULL
       OR v_persisted_market IS NOT NULL
       OR v_persisted_geography IS NOT NULL
       OR v_persisted_documentation_status IS NOT NULL
       OR v_persisted_lifecycle IS NOT NULL
       OR v_persisted_offer_type IS NOT NULL
       OR v_persisted_pricing_model IS NOT NULL
       OR v_persisted_attributes IS DISTINCT FROM '{}'::jsonb THEN
      RAISE EXCEPTION 'Persisted optional fields do not match SQL NULL defaults for %',
        v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_key
      AND status = 'COMPLETED'
      AND execution_id = v_execution_id
      AND request_hash = v_expected_hash
      AND result = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged idempotency row for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND id = v_execution_id
      AND idempotency_key = v_key
      AND status = 'COMPLETED'
      AND input = v_input
      AND result = v_first_result
      AND object_id = v_offer_id;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged execution for %', v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_name
      AND quantity = 1
      AND price = 10
      AND currency = 'USD'
      AND conditions IS NULL
      AND market IS NULL
      AND geography IS NULL
      AND documentation_status IS NULL
      AND lifecycle IS NULL
      AND offer_type IS NULL
      AND pricing_model IS NULL
      AND attributes = '{}'::jsonb;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one offer with all NULL-defaulted fields for %',
        v_case.direction;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_events
    WHERE execution_id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND event_type = 'ACTION_SUCCEEDED'
      AND object_type = 'Offer'
      AND object_id = v_offer_id
      AND payload = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly one unchanged success event for %', v_case.direction;
    END IF;
  END LOOP;
END
$qa79_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER NULL-defaulted optional parameter bidirectional replay assertions passed' AS result;


-- OFFER-QA-80: every NULL-defaulted optional business parameter must independently
-- participate in the request hash for an existing COMPLETED key. Change one field
-- per replay and require IDEMPOTENCY_KEY_REUSE without mutating the original rows.
-- Values are synthetic; all fixtures are confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa80_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"completed-optional-field-hash-coverage"}'::jsonb;
  v_base_payload jsonb;
  v_original_hash text;
  v_execution_result jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'Published CREATE_OFFER fixture definition is missing';
  END IF;

  v_base_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Request Hash Optional Fields Completed Fixture Offer',
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
  );
  v_original_hash := md5(v_base_payload::text);

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, conditions, market, geography,
    documentation_status, lifecycle, offer_type, pricing_model, attributes
  )
  VALUES (
    v_offer_id,
    'Request Hash Optional Fields Completed Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    v_actor_id,
    2,
    12,
    'USD',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    '{}'::jsonb
  );

  v_execution_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, v_actor_id, 'Offer', v_offer_id,
    v_correlation_id, 'fixture-hash-optional-fields-completed', 'COMPLETED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-optional-fields-completed', v_action_id, v_actor_id,
    v_original_hash, v_execution_id, 'COMPLETED',
    v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_execution_result, v_tenant_id
  );
END
$qa80_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa80_assert$
DECLARE
  v_case record;
  v_error text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_base_payload jsonb;
  v_changed_payload jsonb;
  v_original_hash text;
  v_changed_hash text;
  v_changed_hashes text[] := ARRAY[]::text[];
  v_distinct_hashes integer;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_conditions text;
  v_market text;
  v_geography text;
  v_documentation_status text;
  v_lifecycle text;
  v_offer_type text;
  v_pricing_model text;
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', '{"case":"completed-optional-field-hash-coverage"}'::jsonb,
    'name', 'Request Hash Optional Fields Completed Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
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
  );
  v_original_hash := md5(v_base_payload::text);

  SELECT execution_id, request_hash, result
  INTO v_execution_id, v_stored_hash, v_stored_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-completed'
    AND status = 'COMPLETED';

  IF v_execution_id IS NULL
     OR v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'COMPLETED optional-field fixture was not seeded with the expected original hash';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-optional-fields-completed'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED optional-field fixture is missing its original offer';
  END IF;

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'COMPLETED optional-field fixture has an unexpected original result';
  END IF;

  -- Each changed value is isolated to one effective request-hash property.
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('p_conditions', 'conditions', 'FOB test'),
      ('p_market', 'market', 'EU'),
      ('p_geography', 'geography', 'Morocco'),
      ('p_documentation_status', 'documentationStatus', 'pending'),
      ('p_lifecycle', 'lifecycle', 'draft'),
      ('p_offer_type', 'offerType', 'supplier_offer'),
      ('p_pricing_model', 'pricingModel', 'fixed')
    ) AS cases(parameter_name, hash_key, changed_value)
  LOOP
    v_changed_payload := jsonb_set(
      v_base_payload,
      ARRAY[v_case.hash_key],
      to_jsonb(v_case.changed_value)
    );
    v_changed_hash := md5(v_changed_payload::text);
    v_changed_hashes := array_append(v_changed_hashes, v_changed_hash);

    IF v_changed_hash = v_original_hash THEN
      RAISE EXCEPTION 'Changing % did not change the independently calculated request hash',
        v_case.parameter_name;
    END IF;

    v_conditions := NULL;
    v_market := NULL;
    v_geography := NULL;
    v_documentation_status := NULL;
    v_lifecycle := NULL;
    v_offer_type := NULL;
    v_pricing_model := NULL;

    CASE v_case.parameter_name
      WHEN 'p_conditions' THEN v_conditions := v_case.changed_value;
      WHEN 'p_market' THEN v_market := v_case.changed_value;
      WHEN 'p_geography' THEN v_geography := v_case.changed_value;
      WHEN 'p_documentation_status' THEN v_documentation_status := v_case.changed_value;
      WHEN 'p_lifecycle' THEN v_lifecycle := v_case.changed_value;
      WHEN 'p_offer_type' THEN v_offer_type := v_case.changed_value;
      WHEN 'p_pricing_model' THEN v_pricing_model := v_case.changed_value;
      ELSE RAISE EXCEPTION 'Unexpected QA80 parameter %', v_case.parameter_name;
    END CASE;

    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => 'fixture-hash-optional-fields-completed',
        p_input => '{"case":"completed-optional-field-hash-coverage"}'::jsonb,
        p_name => 'Request Hash Optional Fields Completed Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => v_conditions,
        p_market => v_market,
        p_geography => v_geography,
        p_attributes => '{}'::jsonb,
        p_documentation_status => v_documentation_status,
        p_lifecycle => v_lifecycle,
        p_offer_type => v_offer_type,
        p_pricing_model => v_pricing_model
      );
    EXCEPTION WHEN OTHERS THEN
      v_error := SQLERRM;
    END;

    IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'Changed % must raise IDEMPOTENCY_KEY_REUSE; got %',
        v_case.parameter_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

  SELECT count(DISTINCT changed_hash)
  INTO v_distinct_hashes
  FROM unnest(v_changed_hashes) AS hashes(changed_hash);

  IF v_distinct_hashes <> 7 OR cardinality(v_changed_hashes) <> 7 THEN
    RAISE EXCEPTION 'Expected seven distinct changed-parameter hashes, found %',
      v_distinct_hashes;
  END IF;

  -- All seven rejected attempts must leave the original idempotency row intact.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA80 retries changed or duplicated the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA80 retries changed the original idempotency key/hash/result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-hash-optional-fields-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA80 retries created or removed an execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-optional-fields-completed'
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND result = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA80 retries changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Request Hash Optional Fields Completed Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND conditions IS NULL
    AND market IS NULL
    AND geography IS NULL
    AND documentation_status IS NULL
    AND lifecycle IS NULL
    AND offer_type IS NULL
    AND pricing_model IS NULL
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA80 retries changed the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_expected_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA80 retries changed or duplicated the original success event';
  END IF;
END
$qa80_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER all seven NULL-defaulted optional fields independently affect completed request hash assertions passed' AS result;


-- OFFER-QA-81: all seven NULL-defaulted optional business parameters must
-- retain request_hash precedence for existing FAILED and IN_PROGRESS keys.
-- Each of the 14 retries changes exactly one parameter. No offer or event
-- may be created, and both original status records must remain unchanged.
-- All fixtures are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa81_seed$
DECLARE
  v_action_id uuid;
  v_failed_execution_id uuid := gen_random_uuid();
  v_running_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"failed-running-optional-field-hash-coverage"}'::jsonb;
  v_base_payload jsonb;
  v_request_hash text;
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

  v_base_payload := jsonb_build_object(
    'input', v_input,
    'name', 'Request Hash Optional Fields FAILED IN_PROGRESS Fixture Offer',
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
  );
  v_request_hash := md5(v_base_payload::text);

  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_failed_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-optional-fields-failed', 'FAILED',
    v_input, v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-optional-fields-failed', v_action_id, v_actor_id,
    v_request_hash, v_failed_execution_id, 'FAILED',
    v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_running_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-optional-fields-in-progress', 'RUNNING',
    v_input, NULL, NULL, v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-optional-fields-in-progress', v_action_id, v_actor_id,
    v_request_hash, v_running_execution_id, 'IN_PROGRESS',
    NULL, NULL, v_tenant_id
  );
END
$qa81_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa81_assert$
DECLARE
  v_status_case record;
  v_case record;
  v_error text;
  v_failed_execution_id uuid;
  v_running_execution_id uuid;
  v_failed_result jsonb;
  v_expected_failed_result jsonb;
  v_base_payload jsonb;
  v_changed_payload jsonb;
  v_original_hash text;
  v_changed_hash text;
  v_changed_hashes text[];
  v_distinct_hashes integer;
  v_conditions text;
  v_market text;
  v_geography text;
  v_documentation_status text;
  v_lifecycle text;
  v_offer_type text;
  v_pricing_model text;
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', '{"case":"failed-running-optional-field-hash-coverage"}'::jsonb,
    'name', 'Request Hash Optional Fields FAILED IN_PROGRESS Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
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
  );
  v_original_hash := md5(v_base_payload::text);

  SELECT execution_id, result
  INTO v_failed_execution_id, v_failed_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-failed'
    AND status = 'FAILED';

  IF NOT FOUND OR v_failed_execution_id IS NULL OR v_failed_result IS NULL THEN
    RAISE EXCEPTION 'FAILED optional-field fixture was not seeded';
  END IF;

  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );
  IF v_failed_result IS DISTINCT FROM v_expected_failed_result THEN
    RAISE EXCEPTION 'FAILED optional-field fixture has an unexpected stored result';
  END IF;

  SELECT execution_id
  INTO v_running_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-in-progress'
    AND status = 'IN_PROGRESS'
    AND result IS NULL
    AND completed_at IS NULL;

  IF NOT FOUND OR v_running_execution_id IS NULL THEN
    RAISE EXCEPTION 'IN_PROGRESS optional-field fixture was not seeded';
  END IF;

  -- Both statuses must start with the same independently calculated base hash.
  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-hash-optional-fields-failed'
      AND request_hash = v_original_hash
      AND execution_id = v_failed_execution_id
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-hash-optional-fields-in-progress'
      AND request_hash = v_original_hash
      AND execution_id = v_running_execution_id
  ) THEN
    RAISE EXCEPTION 'FAILED/IN_PROGRESS fixtures do not contain the expected original hash';
  END IF;

  FOR v_status_case IN
    SELECT *
    FROM (VALUES
      ('FAILED'::text, 'fixture-hash-optional-fields-failed'::text, v_failed_execution_id),
      ('IN_PROGRESS'::text, 'fixture-hash-optional-fields-in-progress'::text, v_running_execution_id)
    ) AS statuses(status_name, idempotency_key, execution_id)
  LOOP
    v_changed_hashes := ARRAY[]::text[];

    FOR v_case IN
      SELECT *
      FROM (VALUES
        ('p_conditions', 'conditions', 'FOB test'),
        ('p_market', 'market', 'EU'),
        ('p_geography', 'geography', 'Morocco'),
        ('p_documentation_status', 'documentationStatus', 'pending'),
        ('p_lifecycle', 'lifecycle', 'draft'),
        ('p_offer_type', 'offerType', 'supplier_offer'),
        ('p_pricing_model', 'pricingModel', 'fixed')
      ) AS cases(parameter_name, hash_key, changed_value)
    LOOP
      v_changed_payload := jsonb_set(
        v_base_payload,
        ARRAY[v_case.hash_key],
        to_jsonb(v_case.changed_value)
      );
      v_changed_hash := md5(v_changed_payload::text);
      v_changed_hashes := array_append(v_changed_hashes, v_changed_hash);

      IF v_changed_hash = v_original_hash THEN
        RAISE EXCEPTION 'Changing % did not change the independently calculated hash for %',
          v_case.parameter_name, v_status_case.status_name;
      END IF;

      v_conditions := NULL;
      v_market := NULL;
      v_geography := NULL;
      v_documentation_status := NULL;
      v_lifecycle := NULL;
      v_offer_type := NULL;
      v_pricing_model := NULL;

      CASE v_case.parameter_name
        WHEN 'p_conditions' THEN v_conditions := v_case.changed_value;
        WHEN 'p_market' THEN v_market := v_case.changed_value;
        WHEN 'p_geography' THEN v_geography := v_case.changed_value;
        WHEN 'p_documentation_status' THEN v_documentation_status := v_case.changed_value;
        WHEN 'p_lifecycle' THEN v_lifecycle := v_case.changed_value;
        WHEN 'p_offer_type' THEN v_offer_type := v_case.changed_value;
        WHEN 'p_pricing_model' THEN v_pricing_model := v_case.changed_value;
        ELSE RAISE EXCEPTION 'Unexpected QA81 parameter %', v_case.parameter_name;
      END CASE;

      v_error := NULL;
      BEGIN
        PERFORM public.execute_create_offer_v1(
          p_tenant_id => '10000000-0000-4000-8000-000000000001',
          p_idempotency_key => v_status_case.idempotency_key,
          p_input => '{"case":"failed-running-optional-field-hash-coverage"}'::jsonb,
          p_name => 'Request Hash Optional Fields FAILED IN_PROGRESS Fixture Offer',
          p_demand_id => '50000000-0000-4000-8000-000000000001',
          p_product_master_id => '40000000-0000-4000-8000-000000000001',
          p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
          p_quantity => 2,
          p_price => 12,
          p_currency => 'USD',
          p_conditions => v_conditions,
          p_market => v_market,
          p_geography => v_geography,
          p_attributes => '{}'::jsonb,
          p_documentation_status => v_documentation_status,
          p_lifecycle => v_lifecycle,
          p_offer_type => v_offer_type,
          p_pricing_model => v_pricing_model
        );
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
      END;

      IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
        RAISE EXCEPTION '% changed % must raise IDEMPOTENCY_KEY_REUSE before status handling; got %',
          v_status_case.status_name, v_case.parameter_name, coalesce(v_error, '<no error>');
      END IF;
    END LOOP;

    SELECT count(DISTINCT changed_hash)
    INTO v_distinct_hashes
    FROM unnest(v_changed_hashes) AS hashes(changed_hash);

    IF cardinality(v_changed_hashes) <> 7 OR v_distinct_hashes <> 7 THEN
      RAISE EXCEPTION 'Expected seven distinct changed hashes for %, found %',
        v_status_case.status_name, v_distinct_hashes;
    END IF;
  END LOOP;

  -- Both original idempotency rows must remain exactly as seeded.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-hash-optional-fields-failed',
      'fixture-hash-optional-fields-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA81 retries changed or duplicated idempotency rows; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-failed'
    AND status = 'FAILED'
    AND execution_id = v_failed_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_failed_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA81 retries changed the original FAILED idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-optional-fields-in-progress'
    AND status = 'IN_PROGRESS'
    AND execution_id = v_running_execution_id
    AND request_hash = v_original_hash
    AND result IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA81 retries changed the original IN_PROGRESS idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-hash-optional-fields-failed',
      'fixture-hash-optional-fields-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA81 retries created or removed executions; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_failed_execution_id
    AND idempotency_key = 'fixture-hash-optional-fields-failed'
    AND status = 'FAILED'
    AND object_id IS NULL
    AND input = '{"case":"failed-running-optional-field-hash-coverage"}'::jsonb
    AND result = v_expected_failed_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA81 retries changed the original FAILED execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_running_execution_id
    AND idempotency_key = 'fixture-hash-optional-fields-in-progress'
    AND status = 'RUNNING'
    AND object_id IS NULL
    AND input = '{"case":"failed-running-optional-field-hash-coverage"}'::jsonb
    AND result IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA81 retries changed the original RUNNING execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Request Hash Optional Fields FAILED IN_PROGRESS Fixture Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA81 retries unexpectedly created an offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id IN (v_failed_execution_id, v_running_execution_id);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA81 retries unexpectedly created action events';
  END IF;
END
$qa81_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER all seven optional fields take hash precedence for FAILED and IN_PROGRESS keys (14 retries) assertions passed' AS result;
