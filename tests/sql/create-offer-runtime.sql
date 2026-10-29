\set ON_ERROR_STOP on
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
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
SELECT 'CREATE_OFFER integration assertions passed' AS result;
