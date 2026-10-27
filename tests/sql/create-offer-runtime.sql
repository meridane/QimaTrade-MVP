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
  FROM public.action_events
  WHERE payload->>'objectId' IS NOT NULL
    AND payload->>'objectId' = 'fixture-rollback';
  IF v_count <> 0 THEN RAISE EXCEPTION 'Rollback left an orphan event'; END IF;

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
