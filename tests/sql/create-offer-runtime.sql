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

-- QA191: SECURITY DEFINER functions must schema-qualify relation references.
-- PostgreSQL implicitly searches the session temp schema before search_path schemas
-- for relations, even when a function pins search_path=public. Empty temp shadows
-- make any accidental unqualified table lookup or write fail in this disposable fixture.
CREATE TEMP TABLE dt_memberships (LIKE public.dt_memberships INCLUDING ALL);
CREATE TEMP TABLE profiles (LIKE public.profiles INCLUDING ALL);
CREATE TEMP TABLE product_masters (LIKE public.product_masters INCLUDING ALL);
CREATE TEMP TABLE demands (LIKE public.demands INCLUDING ALL);
CREATE TEMP TABLE action_definitions (LIKE public.action_definitions INCLUDING ALL);
CREATE TEMP TABLE idempotency_keys (LIKE public.idempotency_keys INCLUDING ALL);
CREATE TEMP TABLE action_executions (LIKE public.action_executions INCLUDING ALL);
CREATE TEMP TABLE offers (LIKE public.offers INCLUDING ALL);
CREATE TEMP TABLE action_events (LIKE public.action_events INCLUDING ALL);

DO $qa191_shadow_preflight$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'dt_memberships', 'profiles', 'product_masters', 'demands',
    'action_definitions', 'idempotency_keys', 'action_executions',
    'offers', 'action_events'
  ] LOOP
    IF to_regclass(v_table) IS DISTINCT FROM to_regclass(format('pg_temp.%I', v_table)) THEN
      RAISE EXCEPTION 'QA191 temp relation % is not first in relation lookup', v_table;
    END IF;
  END LOOP;
END
$qa191_shadow_preflight$;

DO $$
DECLARE
  first_result jsonb;
  retry_result jsonb;
  v_count integer;
  v_execution_id uuid;
  v_offer_id uuid;
  v_execution_status text;
  v_execution_object_id uuid;
  v_execution_result jsonb;
  v_idempotency_execution_id uuid;
  v_idempotency_status text;
  v_idempotency_result jsonb;
  v_event_payload jsonb;
  v_event_object_id uuid;
  v_event_object_type text;
  v_event_count integer;
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
  -- QA297: the real PostgreSQL RPC must return an object-shaped public result
  -- whose execution, idempotency, event, and offer records all agree.
  IF jsonb_typeof(first_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Expected CREATE_OFFER result to be a JSON object, got %', jsonb_typeof(first_result);
  END IF;
  IF NOT (first_result ?& ARRAY['status', 'executionId', 'objectType', 'objectId']) THEN
    RAISE EXCEPTION 'CREATE_OFFER result is missing a required public field: %', first_result;
  END IF;
  IF first_result->>'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'Expected public result status succeeded, got %', first_result;
  END IF;
  IF first_result->>'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'Expected public result objectType Offer, got %', first_result;
  END IF;
  IF jsonb_typeof(first_result->'executionId') IS DISTINCT FROM 'string'
     OR jsonb_typeof(first_result->'objectId') IS DISTINCT FROM 'string' THEN
    RAISE EXCEPTION 'CREATE_OFFER result identifiers must be JSON strings: %', first_result;
  END IF;
  IF first_result->>'executionId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     OR first_result->>'objectId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'CREATE_OFFER result identifiers must be UUID strings: %', first_result;
  END IF;

  v_execution_id := (first_result->>'executionId')::uuid;
  v_offer_id := (first_result->>'objectId')::uuid;

  SELECT status, object_id, result
  INTO v_execution_status, v_execution_object_id, v_execution_result
  FROM public.action_executions
  WHERE id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-idempotency-1';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CREATE_OFFER result executionId does not identify its persisted execution: %', v_execution_id;
  END IF;
  IF v_execution_status IS DISTINCT FROM 'COMPLETED'
     OR v_execution_object_id IS DISTINCT FROM v_offer_id
     OR v_execution_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'Persisted action execution does not match the public result: %', first_result;
  END IF;

  SELECT execution_id, status, result
  INTO v_idempotency_execution_id, v_idempotency_status, v_idempotency_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-idempotency-1';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CREATE_OFFER result has no persisted idempotency row';
  END IF;
  IF v_idempotency_execution_id IS DISTINCT FROM v_execution_id
     OR v_idempotency_status IS DISTINCT FROM 'COMPLETED'
     OR v_idempotency_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'Persisted idempotency result does not match the public result: %', first_result;
  END IF;

  SELECT count(*) INTO v_event_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED';
  IF v_event_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one matching ACTION_SUCCEEDED event, found %', v_event_count;
  END IF;

  SELECT payload, object_id, object_type
  INTO v_event_payload, v_event_object_id, v_event_object_type
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CREATE_OFFER result has no matching ACTION_SUCCEEDED event';
  END IF;
  IF v_event_payload IS DISTINCT FROM first_result
     OR v_event_object_id IS DISTINCT FROM v_offer_id
     OR v_event_object_type IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'Persisted success event does not match the public result: %', first_result;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'CREATE_OFFER result objectId does not identify exactly one matching offer, found %', v_count;
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
  IF jsonb_typeof(retry_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Identical retry must replay an object-shaped result, got %', jsonb_typeof(retry_result);
  END IF;
  IF retry_result IS DISTINCT FROM first_result THEN
    RAISE EXCEPTION 'Identical retry did not return the same result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-idempotency-1';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one persisted execution after replay, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-idempotency-1';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one persisted idempotency row after replay, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one persisted offer after replay, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one persisted success event after replay, found %', v_count;
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

  -- Empty market is distinct from NULL and must be rejected for the completed key.
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
      p_market => ''
    );
    RAISE EXCEPTION 'Expected empty market to differ from NULL and be rejected';
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

  -- Empty conditions is distinct from NULL and must be rejected for the completed key.
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
      p_conditions => ''
    );
    RAISE EXCEPTION 'Expected empty conditions to differ from NULL and be rejected';
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

  -- Empty geography is distinct from NULL and must be rejected for the completed key.
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
      p_geography => ''
    );
    RAISE EXCEPTION 'Expected empty geography to differ from NULL and be rejected';
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

-- The successful RPC above must have used public-qualified relations, not any
-- of the empty temporary shadows created for this regression.
DO $qa191_shadow_assert$
DECLARE
  v_table text;
  v_count bigint;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'dt_memberships', 'profiles', 'product_masters', 'demands',
    'action_definitions', 'idempotency_keys', 'action_executions',
    'offers', 'action_events'
  ] LOOP
    EXECUTE format('SELECT count(*) FROM pg_temp.%I', v_table) INTO v_count;
    IF v_count <> 0 THEN
      RAISE EXCEPTION 'QA191 unexpected rows written to temp shadow relation %: %', v_table, v_count;
    END IF;
  END LOOP;
END
$qa191_shadow_assert$;

DROP TABLE pg_temp.action_events, pg_temp.offers, pg_temp.action_executions,
  pg_temp.idempotency_keys, pg_temp.action_definitions, pg_temp.demands,
  pg_temp.product_masters, pg_temp.profiles, pg_temp.dt_memberships;

SELECT 'QA191 SECURITY DEFINER relation lookups and writes bypassed all temporary shadows and used schema-qualified public objects' AS result;


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


-- OFFER-QA-82: the remaining base request properties must retain hash
-- precedence for existing FAILED and IN_PROGRESS keys. Each of the eight
-- retries changes exactly one of p_input, p_name, p_demand_id or
-- p_product_master_id. All fixtures are synthetic and CI-only.
RESET ROLE;

DO $qa82_seed$
DECLARE
  v_action_id uuid;
  v_failed_execution_id uuid := gen_random_uuid();
  v_running_execution_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"failed-running-base-fields-hash-coverage"}'::jsonb;
  v_name text := 'Request Hash Base Fields FAILED IN_PROGRESS Fixture Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_base_payload jsonb;
  v_request_hash text;
  v_failed_result jsonb;
BEGIN
  -- Reuse the alternate published demand and active product already seeded
  -- by create-offer-runtime.sql. This fixture does not assert demand ownership
  -- or define the separate demandId/tenantId authorization contract.
  IF NOT EXISTS (
    SELECT 1 FROM public.demands
    WHERE id = '50000000-0000-4000-8000-000000000002'
      AND demand_status = 'published'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.product_masters
    WHERE id = '40000000-0000-4000-8000-000000000002'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'QA82 alternate demand/product fixtures are not valid';
  END IF;

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
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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
    gen_random_uuid(), 'fixture-hash-base-fields-failed', 'FAILED',
    v_input, v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-base-fields-failed', v_action_id, v_actor_id,
    v_request_hash, v_failed_execution_id, 'FAILED',
    v_failed_result, now(), v_tenant_id
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES (
    v_running_execution_id, v_action_id, 1, v_actor_id, 'Offer', NULL,
    gen_random_uuid(), 'fixture-hash-base-fields-in-progress', 'RUNNING',
    v_input, NULL, NULL, v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-base-fields-in-progress', v_action_id, v_actor_id,
    v_request_hash, v_running_execution_id, 'IN_PROGRESS',
    NULL, NULL, v_tenant_id
  );
END
$qa82_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa82_assert$
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
  v_input jsonb;
  v_name text;
  v_demand_id uuid;
  v_product_master_id uuid;
  v_base_input jsonb := '{"case":"failed-running-base-fields-hash-coverage"}'::jsonb;
  v_base_name text := 'Request Hash Base Fields FAILED IN_PROGRESS Fixture Offer';
  v_base_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_base_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', v_base_input,
    'name', v_base_name,
    'demandId', v_base_demand_id,
    'productMasterId', v_base_product_master_id,
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
    AND key = 'fixture-hash-base-fields-failed'
    AND status = 'FAILED';

  IF NOT FOUND OR v_failed_execution_id IS NULL OR v_failed_result IS NULL THEN
    RAISE EXCEPTION 'FAILED base-field fixture was not seeded';
  END IF;

  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', v_failed_execution_id,
    'error', jsonb_build_object('code', 'FIXTURE_FAILURE')
  );
  IF v_failed_result IS DISTINCT FROM v_expected_failed_result THEN
    RAISE EXCEPTION 'FAILED base-field fixture has an unexpected stored result';
  END IF;

  SELECT execution_id
  INTO v_running_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-base-fields-in-progress'
    AND status = 'IN_PROGRESS'
    AND result IS NULL
    AND completed_at IS NULL;

  IF NOT FOUND OR v_running_execution_id IS NULL THEN
    RAISE EXCEPTION 'IN_PROGRESS base-field fixture was not seeded';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-hash-base-fields-failed'
      AND request_hash = v_original_hash
      AND execution_id = v_failed_execution_id
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-hash-base-fields-in-progress'
      AND request_hash = v_original_hash
      AND execution_id = v_running_execution_id
  ) THEN
    RAISE EXCEPTION 'FAILED/IN_PROGRESS base-field fixtures do not contain the expected original hash';
  END IF;

  FOR v_status_case IN
    SELECT *
    FROM (VALUES
      ('FAILED'::text, 'fixture-hash-base-fields-failed'::text),
      ('IN_PROGRESS'::text, 'fixture-hash-base-fields-in-progress'::text)
    ) AS statuses(status_name, idempotency_key)
  LOOP
    v_changed_hashes := ARRAY[]::text[];

    FOR v_case IN
      SELECT *
      FROM (VALUES
        ('p_input', 'input', '{"case":"changed-base-input"}'::jsonb),
        ('p_name', 'name', '"Request Hash Base Fields Alternate Fixture Offer"'::jsonb),
        ('p_demand_id', 'demandId', '"50000000-0000-4000-8000-000000000002"'::jsonb),
        ('p_product_master_id', 'productMasterId', '"40000000-0000-4000-8000-000000000002"'::jsonb)
      ) AS cases(parameter_name, hash_key, changed_value)
    LOOP
      v_changed_payload := jsonb_set(
        v_base_payload,
        ARRAY[v_case.hash_key],
        v_case.changed_value
      );
      v_changed_hash := md5(v_changed_payload::text);
      v_changed_hashes := array_append(v_changed_hashes, v_changed_hash);

      IF v_changed_hash = v_original_hash THEN
        RAISE EXCEPTION 'Changing % did not change the independently calculated hash for %',
          v_case.parameter_name, v_status_case.status_name;
      END IF;

      v_input := v_base_input;
      v_name := v_base_name;
      v_demand_id := v_base_demand_id;
      v_product_master_id := v_base_product_master_id;

      CASE v_case.parameter_name
        WHEN 'p_input' THEN v_input := v_case.changed_value;
        WHEN 'p_name' THEN v_name := v_case.changed_value #>> '{}';
        WHEN 'p_demand_id' THEN v_demand_id := (v_case.changed_value #>> '{}')::uuid;
        WHEN 'p_product_master_id' THEN v_product_master_id := (v_case.changed_value #>> '{}')::uuid;
        ELSE RAISE EXCEPTION 'Unexpected QA82 parameter %', v_case.parameter_name;
      END CASE;

      v_error := NULL;
      BEGIN
        PERFORM public.execute_create_offer_v1(
          p_tenant_id => '10000000-0000-4000-8000-000000000001',
          p_idempotency_key => v_status_case.idempotency_key,
          p_input => v_input,
          p_name => v_name,
          p_demand_id => v_demand_id,
          p_product_master_id => v_product_master_id,
          p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
          p_quantity => 2,
          p_price => 12,
          p_currency => 'USD',
          p_conditions => NULL,
          p_market => NULL,
          p_geography => NULL,
          p_attributes => '{}'::jsonb,
          p_documentation_status => NULL,
          p_lifecycle => NULL,
          p_offer_type => NULL,
          p_pricing_model => NULL
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

    IF cardinality(v_changed_hashes) <> 4 OR v_distinct_hashes <> 4 THEN
      RAISE EXCEPTION 'Expected four distinct changed hashes for %, found %',
        v_status_case.status_name, v_distinct_hashes;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-hash-base-fields-failed',
      'fixture-hash-base-fields-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA82 retries changed or duplicated idempotency rows; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-base-fields-failed'
    AND status = 'FAILED'
    AND execution_id = v_failed_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_failed_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA82 retries changed the original FAILED idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-base-fields-in-progress'
    AND status = 'IN_PROGRESS'
    AND execution_id = v_running_execution_id
    AND request_hash = v_original_hash
    AND result IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA82 retries changed the original IN_PROGRESS idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-hash-base-fields-failed',
      'fixture-hash-base-fields-in-progress'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA82 retries created or removed executions; expected 2, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_failed_execution_id
    AND idempotency_key = 'fixture-hash-base-fields-failed'
    AND status = 'FAILED'
    AND object_id IS NULL
    AND input = v_base_input
    AND result = v_expected_failed_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA82 retries changed the original FAILED execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_running_execution_id
    AND idempotency_key = 'fixture-hash-base-fields-in-progress'
    AND status = 'RUNNING'
    AND object_id IS NULL
    AND input = v_base_input
    AND result IS NULL
    AND completed_at IS NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA82 retries changed the original RUNNING execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = v_base_name
    OR name = 'Request Hash Base Fields Alternate Fixture Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA82 retries unexpectedly created an offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id IN (v_failed_execution_id, v_running_execution_id);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA82 retries unexpectedly created action events';
  END IF;
END
$qa82_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER base request properties p_input, p_name, p_demand_id and p_product_master_id take hash precedence for FAILED and IN_PROGRESS keys (8 retries) assertions passed' AS result;


-- OFFER-QA-83: the remaining base request properties must independently
-- participate in the request hash for an existing COMPLETED key. Each replay
-- changes exactly one of p_input, p_name, p_demand_id or p_product_master_id.
-- The original offer, execution, result and success event must remain intact.
-- All fixtures are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa83_seed$
DECLARE
  v_action_id uuid;
  v_execution_id uuid := gen_random_uuid();
  v_offer_id uuid := gen_random_uuid();
  v_correlation_id uuid := gen_random_uuid();
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"completed-base-fields-hash-coverage"}'::jsonb;
  v_name text := 'Request Hash Base Fields Completed Fixture Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_base_payload jsonb;
  v_original_hash text;
  v_execution_result jsonb;
BEGIN
  -- Reuse the alternate published demand and active product from the common
  -- CREATE_OFFER seed. This does not assert demand ownership or authorization.
  IF NOT EXISTS (
    SELECT 1 FROM public.demands
    WHERE id = '50000000-0000-4000-8000-000000000002'
      AND demand_status = 'published'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.product_masters
    WHERE id = '40000000-0000-4000-8000-000000000002'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'QA83 alternate demand/product fixtures are not valid';
  END IF;

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
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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
    v_name,
    v_demand_id,
    v_product_master_id,
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
    v_correlation_id, 'fixture-hash-base-fields-completed', 'COMPLETED',
    v_input, v_execution_result, now(), v_tenant_id
  );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES (
    'fixture-hash-base-fields-completed', v_action_id, v_actor_id,
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
$qa83_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa83_assert$
DECLARE
  v_case record;
  v_error text;
  v_execution_id uuid;
  v_offer_id uuid;
  v_stored_hash text;
  v_stored_result jsonb;
  v_expected_result jsonb;
  v_base_payload jsonb;
  v_changed_payload jsonb;
  v_original_hash text;
  v_changed_hash text;
  v_changed_hashes text[] := ARRAY[]::text[];
  v_distinct_hashes integer;
  v_input jsonb;
  v_name text;
  v_demand_id uuid;
  v_product_master_id uuid;
  v_base_input jsonb := '{"case":"completed-base-fields-hash-coverage"}'::jsonb;
  v_base_name text := 'Request Hash Base Fields Completed Fixture Offer';
  v_base_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_base_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', v_base_input,
    'name', v_base_name,
    'demandId', v_base_demand_id,
    'productMasterId', v_base_product_master_id,
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
    AND key = 'fixture-hash-base-fields-completed'
    AND status = 'COMPLETED';

  IF NOT FOUND OR v_execution_id IS NULL OR v_stored_hash IS DISTINCT FROM v_original_hash THEN
    RAISE EXCEPTION 'COMPLETED base-field fixture was not seeded with the expected original hash';
  END IF;

  SELECT object_id INTO v_offer_id
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-base-fields-completed'
    AND status = 'COMPLETED';

  IF v_offer_id IS NULL THEN
    RAISE EXCEPTION 'COMPLETED base-field fixture is missing its original offer';
  END IF;

  v_expected_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );
  IF v_stored_result IS DISTINCT FROM v_expected_result THEN
    RAISE EXCEPTION 'COMPLETED base-field fixture has an unexpected original result';
  END IF;

  -- Change exactly one base request property in each independent replay.
  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('p_input', 'input', '{"case":"changed-completed-base-input"}'::jsonb),
      ('p_name', 'name', '"Request Hash Base Fields Completed Alternate Fixture Offer"'::jsonb),
      ('p_demand_id', 'demandId', '"50000000-0000-4000-8000-000000000002"'::jsonb),
      ('p_product_master_id', 'productMasterId', '"40000000-0000-4000-8000-000000000002"'::jsonb)
    ) AS cases(parameter_name, hash_key, changed_value)
  LOOP
    v_changed_payload := jsonb_set(
      v_base_payload,
      ARRAY[v_case.hash_key],
      v_case.changed_value
    );
    v_changed_hash := md5(v_changed_payload::text);
    v_changed_hashes := array_append(v_changed_hashes, v_changed_hash);

    IF v_changed_hash = v_original_hash THEN
      RAISE EXCEPTION 'Changing % did not change the independently calculated hash',
        v_case.parameter_name;
    END IF;

    v_input := v_base_input;
    v_name := v_base_name;
    v_demand_id := v_base_demand_id;
    v_product_master_id := v_base_product_master_id;

    CASE v_case.parameter_name
      WHEN 'p_input' THEN v_input := v_case.changed_value;
      WHEN 'p_name' THEN v_name := v_case.changed_value #>> '{}';
      WHEN 'p_demand_id' THEN v_demand_id := (v_case.changed_value #>> '{}')::uuid;
      WHEN 'p_product_master_id' THEN v_product_master_id := (v_case.changed_value #>> '{}')::uuid;
      ELSE RAISE EXCEPTION 'Unexpected QA83 parameter %', v_case.parameter_name;
    END CASE;

    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => 'fixture-hash-base-fields-completed',
        p_input => v_input,
        p_name => v_name,
        p_demand_id => v_demand_id,
        p_product_master_id => v_product_master_id,
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
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

  IF cardinality(v_changed_hashes) <> 4 OR v_distinct_hashes <> 4 THEN
    RAISE EXCEPTION 'Expected four distinct changed-parameter hashes, found %',
      v_distinct_hashes;
  END IF;

  -- The original idempotency row and terminal result must remain unchanged.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-base-fields-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA83 retries changed or duplicated the original idempotency row';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-hash-base-fields-completed'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_original_hash
    AND result = v_expected_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA83 retries changed the original idempotency key/hash/result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-hash-base-fields-completed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA83 retries created or removed an execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-hash-base-fields-completed'
    AND status = 'COMPLETED'
    AND object_id = v_offer_id
    AND input = v_base_input
    AND result = v_expected_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA83 retries changed the original execution';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = v_base_name
    AND demand_id = v_base_demand_id
    AND product_master_id = v_base_product_master_id
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
    RAISE EXCEPTION 'QA83 retries changed the original offer';
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
    RAISE EXCEPTION 'QA83 retries changed or duplicated the original success event';
  END IF;
END
$qa83_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER base request properties p_input, p_name, p_demand_id and p_product_master_id independently affect completed request hash assertions passed' AS result;


-- OFFER-QA-84: provider actor identity is validated before idempotency hash/status
-- handling for existing COMPLETED, FAILED and IN_PROGRESS keys. The caller
-- remains authenticated as provider A while passing provider B's actor_id.
-- All records are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa84_seed$
DECLARE
  v_action_id uuid;
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_other_actor_id uuid := '30000000-0000-4000-8000-000000000002';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"provider-identity-validation-order"}'::jsonb;
  v_name text := 'Provider Identity Order Completed Fixture Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_base_payload jsonb;
  v_request_hash text;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := clock_timestamp();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000001'
      AND actor_id = v_actor_id
  ) OR NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000002'
      AND actor_id = v_other_actor_id
  ) THEN
    RAISE EXCEPTION 'QA84 requires both synthetic provider profiles';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key IN (
        'fixture-provider-identity-completed',
        'fixture-provider-identity-failed',
        'fixture-provider-identity-in-progress'
      )
  ) THEN
    RAISE EXCEPTION 'QA84 idempotency fixture keys already exist';
  END IF;

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
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, conditions, market, geography,
    documentation_status, lifecycle, offer_type, pricing_model, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000084',
    v_name,
    v_demand_id,
    v_product_master_id,
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

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000084'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000084'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000085'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000084',
      v_action_id, 1, v_actor_id, 'Offer',
      '71000000-0000-4000-8000-000000000084',
      '72000000-0000-4000-8000-000000000084',
      'fixture-provider-identity-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000085',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000085',
      'fixture-provider-identity-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000086',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000086',
      'fixture-provider-identity-in-progress', 'RUNNING',
      v_input, NULL, NULL, v_tenant_id
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-provider-identity-completed', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000084',
      'COMPLETED', v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-provider-identity-failed', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000085',
      'FAILED', v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-provider-identity-in-progress', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000086',
      'IN_PROGRESS', NULL, NULL, v_tenant_id
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000084',
    v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer',
    '71000000-0000-4000-8000-000000000084',
    '72000000-0000-4000-8000-000000000084',
    v_completed_result,
    v_tenant_id
  );
END
$qa84_seed$;

-- Keep the JWT bound to provider A. Supplying provider B's actor id must fail
-- at INVALID_PROVIDER_ACTOR before a different request hash or stored status
-- can be observed by the idempotency branch.
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa84_assert$
DECLARE
  v_case record;
  v_error text;
  v_base_payload jsonb;
  v_other_actor_payload jsonb;
  v_original_hash text;
  v_other_actor_hash text;
  v_expected_completed_result jsonb;
  v_expected_failed_result jsonb;
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', '{"case":"provider-identity-validation-order"}'::jsonb,
    'name', 'Provider Identity Order Completed Fixture Offer',
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
  v_other_actor_payload := jsonb_set(
    v_base_payload,
    ARRAY['providerActorId'],
    to_jsonb('30000000-0000-4000-8000-000000000002'::uuid)
  );
  v_other_actor_hash := md5(v_other_actor_payload::text);

  IF v_other_actor_hash = v_original_hash THEN
    RAISE EXCEPTION 'Changing providerActorId did not change the independently calculated request hash';
  END IF;

  v_expected_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000084'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000084'::uuid
  );
  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000085'::uuid,
    'error', 'fixture failure'
  );

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-provider-identity-completed'),
      ('FAILED', 'fixture-provider-identity-failed'),
      ('IN_PROGRESS', 'fixture-provider-identity-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"provider-identity-validation-order"}'::jsonb,
        p_name => 'Provider Identity Order Completed Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000002',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA84 expected INVALID_PROVIDER_ACTOR for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'INVALID_PROVIDER_ACTOR' THEN
      RAISE EXCEPTION 'Provider identity validation must precede hash/status handling for %; got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-provider-identity-completed',
      'fixture-provider-identity-failed',
      'fixture-provider-identity-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA84 retries changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-provider-identity-completed'
        AND status = 'COMPLETED'
        AND execution_id = '70000000-0000-4000-8000-000000000084'
        AND result = v_expected_completed_result
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-provider-identity-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000085'
        AND result = v_expected_failed_result
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-provider-identity-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000086'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA84 retries changed original idempotency status, actor, hash or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = '{"case":"provider-identity-validation-order"}'::jsonb
    AND (
      (id = '70000000-0000-4000-8000-000000000084'
        AND idempotency_key = 'fixture-provider-identity-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000084'
        AND result = v_expected_completed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000085'
        AND idempotency_key = 'fixture-provider-identity-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result = v_expected_failed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000086'
        AND idempotency_key = 'fixture-provider-identity-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA84 retries changed original execution status, actor, object or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000084'
    AND name = 'Provider Identity Order Completed Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA84 retries changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000084'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000084'
    AND payload = v_expected_completed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA84 retries changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000084',
    '70000000-0000-4000-8000-000000000085',
    '70000000-0000-4000-8000-000000000086'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA84 retries unexpectedly created or removed action events';
  END IF;
END
$qa84_assert$;

RESET ROLE;
SELECT 'CREATE_OFFER provider actor identity validation precedes idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (3 retries) assertions passed' AS result;


-- OFFER-QA-85: tenant membership is checked before provider identity, hash,
-- and stored idempotency status. User B belongs only to tenant B and attempts
-- to address three existing keys owned by tenant A. Provider actor B matches
-- the JWT so this isolates the tenant membership guard.
-- All fixtures are synthetic and confined to the disposable PostgreSQL CI DB.
RESET ROLE;

DO $qa85_seed$
DECLARE
  v_action_id uuid;
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_other_actor_id uuid := '30000000-0000-4000-8000-000000000002';
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_other_tenant_id uuid := '10000000-0000-4000-8000-000000000002';
  v_input jsonb := '{"case":"tenant-membership-validation-order"}'::jsonb;
  v_name text := 'Tenant Membership Validation Order Fixture Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_base_payload jsonb;
  v_request_hash text;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := clock_timestamp();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000001'
      AND actor_id = v_actor_id
  ) OR NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000002'
      AND actor_id = v_other_actor_id
  ) THEN
    RAISE EXCEPTION 'QA85 requires both synthetic provider profiles';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = v_other_tenant_id
      AND user_id = '20000000-0000-4000-8000-000000000002'
  ) OR EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = v_tenant_id
      AND user_id = '20000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'QA85 requires user B to belong to tenant B only, not tenant A';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key IN (
        'fixture-tenant-membership-completed',
        'fixture-tenant-membership-failed',
        'fixture-tenant-membership-in-progress'
      )
  ) THEN
    RAISE EXCEPTION 'QA85 idempotency fixture keys already exist';
  END IF;

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
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000087'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000085'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000088'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, conditions, market, geography,
    documentation_status, lifecycle, offer_type, pricing_model, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000085',
    v_name,
    v_demand_id,
    v_product_master_id,
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

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000087',
      v_action_id, 1, v_actor_id, 'Offer',
      '71000000-0000-4000-8000-000000000085',
      '72000000-0000-4000-8000-000000000087',
      'fixture-tenant-membership-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000088',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000088',
      'fixture-tenant-membership-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000089',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000089',
      'fixture-tenant-membership-in-progress', 'RUNNING',
      v_input, NULL, NULL, v_tenant_id
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-tenant-membership-completed', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000087',
      'COMPLETED', v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-tenant-membership-failed', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000088',
      'FAILED', v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-tenant-membership-in-progress', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000089',
      'IN_PROGRESS', NULL, NULL, v_tenant_id
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000087',
    v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer',
    '71000000-0000-4000-8000-000000000085',
    '72000000-0000-4000-8000-000000000087',
    v_completed_result,
    v_tenant_id
  );
END
$qa85_seed$;

-- User B's JWT and provider actor are consistent, but user B is not a member
-- of tenant A. The tenant membership guard must fire before actor/hash/status.
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SET ROLE authenticated;

DO $qa85_assert$
DECLARE
  v_case record;
  v_error text;
  v_base_payload jsonb;
  v_other_actor_payload jsonb;
  v_original_hash text;
  v_other_actor_hash text;
  v_expected_completed_result jsonb;
  v_expected_failed_result jsonb;
  v_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = '10000000-0000-4000-8000-000000000002'
      AND user_id = '20000000-0000-4000-8000-000000000002'
  ) OR EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND user_id = '20000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'QA85 caller membership fixture is not isolated to tenant B';
  END IF;

  v_base_payload := jsonb_build_object(
    'input', '{"case":"tenant-membership-validation-order"}'::jsonb,
    'name', 'Tenant Membership Validation Order Fixture Offer',
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
  v_other_actor_payload := jsonb_set(
    v_base_payload,
    ARRAY['providerActorId'],
    to_jsonb('30000000-0000-4000-8000-000000000002'::uuid)
  );
  v_other_actor_hash := md5(v_other_actor_payload::text);

  IF v_other_actor_hash = v_original_hash THEN
    RAISE EXCEPTION 'QA85 provider actor variation did not change the independently calculated request hash';
  END IF;

  v_expected_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000087'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000085'::uuid
  );
  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000088'::uuid,
    'error', 'fixture failure'
  );

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-tenant-membership-completed'),
      ('FAILED', 'fixture-tenant-membership-failed'),
      ('IN_PROGRESS', 'fixture-tenant-membership-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"tenant-membership-validation-order"}'::jsonb,
        p_name => 'Tenant Membership Validation Order Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000002',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA85 expected TENANT_ACCESS_DENIED for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'TENANT_ACCESS_DENIED' THEN
      RAISE EXCEPTION 'Tenant membership validation must precede provider identity/hash/status handling for %; got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-tenant-membership-completed',
      'fixture-tenant-membership-failed',
      'fixture-tenant-membership-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA85 retries changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-tenant-membership-completed'
        AND status = 'COMPLETED'
        AND execution_id = '70000000-0000-4000-8000-000000000087'
        AND result = v_expected_completed_result
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-tenant-membership-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000088'
        AND result = v_expected_failed_result
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-tenant-membership-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000089'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA85 retries changed original idempotency status, actor, hash or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = '{"case":"tenant-membership-validation-order"}'::jsonb
    AND (
      (id = '70000000-0000-4000-8000-000000000087'
        AND idempotency_key = 'fixture-tenant-membership-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000085'
        AND result = v_expected_completed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000088'
        AND idempotency_key = 'fixture-tenant-membership-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result = v_expected_failed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000089'
        AND idempotency_key = 'fixture-tenant-membership-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA85 retries changed original execution status, actor, object or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000085'
    AND name = 'Tenant Membership Validation Order Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA85 retries changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000087'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000085'
    AND payload = v_expected_completed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA85 retries changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000087',
    '70000000-0000-4000-8000-000000000088',
    '70000000-0000-4000-8000-000000000089'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA85 retries unexpectedly created or removed action events';
  END IF;
END
$qa85_assert$;

RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SELECT 'CREATE_OFFER tenant membership validation precedes provider identity/hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (3 cross-tenant retries) assertions passed' AS result;


-- OFFER-QA-86: product-active and demand-existence preconditions must run
-- before the idempotency hash/status branch for COMPLETED, FAILED and
-- IN_PROGRESS keys. The inactive product and missing demand are synthetic
-- references in the disposable PostgreSQL CI database only.
RESET ROLE;

DO $qa86_seed$
DECLARE
  v_action_id uuid;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_inactive_product_id uuid := '40000000-0000-4000-8000-000000000099';
  v_missing_demand_id uuid := '50000000-0000-4000-8000-000000000099';
  v_input jsonb := '{"case":"product-demand-precondition-order"}'::jsonb;
  v_name text := 'Product Demand Precondition Order Fixture Offer';
  v_base_payload jsonb;
  v_request_hash text;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := clock_timestamp();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000001'
      AND actor_id = v_actor_id
  ) OR NOT EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = v_tenant_id
      AND user_id = '20000000-0000-4000-8000-000000000001'
  ) THEN
    RAISE EXCEPTION 'QA86 requires provider A profile and tenant A membership';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.product_masters
    WHERE id = v_inactive_product_id
      AND status = 'draft'
  ) THEN
    RAISE EXCEPTION 'QA86 requires the existing inactive draft product fixture';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.demands
    WHERE id = v_missing_demand_id
  ) THEN
    RAISE EXCEPTION 'QA86 missing-demand fixture identifier unexpectedly exists';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key IN (
        'fixture-precondition-order-completed',
        'fixture-precondition-order-failed',
        'fixture-precondition-order-in-progress'
      )
  ) THEN
    RAISE EXCEPTION 'QA86 idempotency fixture keys already exist';
  END IF;

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
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000090'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000086'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000091'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, conditions, market, geography,
    documentation_status, lifecycle, offer_type, pricing_model, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000086',
    v_name,
    v_demand_id,
    v_product_master_id,
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

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000090',
      v_action_id, 1, v_actor_id, 'Offer',
      '71000000-0000-4000-8000-000000000086',
      '72000000-0000-4000-8000-000000000090',
      'fixture-precondition-order-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000091',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000091',
      'fixture-precondition-order-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000092',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000092',
      'fixture-precondition-order-in-progress', 'RUNNING',
      v_input, NULL, NULL, v_tenant_id
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-precondition-order-completed', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000090',
      'COMPLETED', v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-precondition-order-failed', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000091',
      'FAILED', v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-precondition-order-in-progress', v_action_id, v_actor_id,
      v_request_hash, '70000000-0000-4000-8000-000000000092',
      'IN_PROGRESS', NULL, NULL, v_tenant_id
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000090',
    v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer',
    '71000000-0000-4000-8000-000000000086',
    '72000000-0000-4000-8000-000000000090',
    v_completed_result,
    v_tenant_id
  );
END
$qa86_seed$;

-- Keep tenant A's JWT and provider actor consistent. Each invalid reference
-- changes the effective request hash, but its precondition must fail first.
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa86_assert$
DECLARE
  v_case record;
  v_error text;
  v_base_payload jsonb;
  v_inactive_product_payload jsonb;
  v_missing_demand_payload jsonb;
  v_original_hash text;
  v_inactive_product_hash text;
  v_missing_demand_hash text;
  v_expected_completed_result jsonb;
  v_expected_failed_result jsonb;
  v_count integer;
BEGIN
  v_base_payload := jsonb_build_object(
    'input', '{"case":"product-demand-precondition-order"}'::jsonb,
    'name', 'Product Demand Precondition Order Fixture Offer',
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

  v_inactive_product_payload := jsonb_set(
    v_base_payload,
    ARRAY['productMasterId'],
    to_jsonb('40000000-0000-4000-8000-000000000099'::uuid)
  );
  v_inactive_product_hash := md5(v_inactive_product_payload::text);

  v_missing_demand_payload := jsonb_set(
    v_base_payload,
    ARRAY['demandId'],
    to_jsonb('50000000-0000-4000-8000-000000000099'::uuid)
  );
  v_missing_demand_hash := md5(v_missing_demand_payload::text);

  IF v_inactive_product_hash = v_original_hash THEN
    RAISE EXCEPTION 'QA86 inactive product variation did not change the independently calculated request hash';
  END IF;
  IF v_missing_demand_hash = v_original_hash THEN
    RAISE EXCEPTION 'QA86 missing demand variation did not change the independently calculated request hash';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.product_masters
    WHERE id = '40000000-0000-4000-8000-000000000099'
      AND status = 'draft'
  ) OR EXISTS (
    SELECT 1 FROM public.demands
    WHERE id = '50000000-0000-4000-8000-000000000099'
  ) THEN
    RAISE EXCEPTION 'QA86 invalid reference fixtures are not in the expected state';
  END IF;

  v_expected_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000090'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000086'::uuid
  );
  v_expected_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000091'::uuid,
    'error', 'fixture failure'
  );

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-precondition-order-completed'),
      ('FAILED', 'fixture-precondition-order-failed'),
      ('IN_PROGRESS', 'fixture-precondition-order-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"product-demand-precondition-order"}'::jsonb,
        p_name => 'Product Demand Precondition Order Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000099',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA86 expected PRODUCT_MASTER_NOT_FOUND for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'PRODUCT_MASTER_NOT_FOUND' THEN
      RAISE EXCEPTION 'Product active-state validation must precede hash/status handling for %; got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;

    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"product-demand-precondition-order"}'::jsonb,
        p_name => 'Product Demand Precondition Order Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000099',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA86 expected DEMAND_NOT_FOUND for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'DEMAND_NOT_FOUND' THEN
      RAISE EXCEPTION 'Demand existence validation must precede hash/status handling for %; got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-precondition-order-completed',
      'fixture-precondition-order-failed',
      'fixture-precondition-order-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA86 retries changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-precondition-order-completed'
        AND status = 'COMPLETED'
        AND execution_id = '70000000-0000-4000-8000-000000000090'
        AND result = v_expected_completed_result
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-precondition-order-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000091'
        AND result = v_expected_failed_result
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-precondition-order-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000092'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA86 retries changed original idempotency status, actor, hash or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = '{"case":"product-demand-precondition-order"}'::jsonb
    AND (
      (id = '70000000-0000-4000-8000-000000000090'
        AND idempotency_key = 'fixture-precondition-order-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000086'
        AND result = v_expected_completed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000091'
        AND idempotency_key = 'fixture-precondition-order-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result = v_expected_failed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000092'
        AND idempotency_key = 'fixture-precondition-order-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA86 retries changed original execution status, actor, object or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000086'
    AND name = 'Product Demand Precondition Order Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA86 retries changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000090'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000086'
    AND payload = v_expected_completed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA86 retries changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000090',
    '70000000-0000-4000-8000-000000000091',
    '70000000-0000-4000-8000-000000000092'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA86 retries unexpectedly created or removed action events';
  END IF;
END
$qa86_assert$;

RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SELECT 'CREATE_OFFER product-active and demand-existence preconditions precede idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (6 retries) assertions passed' AS result;


-- OFFER-QA-87: the published action definition is a precondition to
-- idempotency lookup. The temporary status change is transactional and runs
-- only in the disposable PostgreSQL integration database.
BEGIN;

DO $qa87_seed$
DECLARE
  v_action_id uuid;
  v_request_hash text;
  v_input jsonb := '{"case":"action-publication-precondition-order"}'::jsonb;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := now();
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL THEN
    RAISE EXCEPTION 'QA87 requires exactly one published CREATE_OFFER v1 definition';
  END IF;

  IF (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA87 expected exactly one published CREATE_OFFER v1 definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Action Publication Precondition Order Fixture Offer',
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

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000093'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000087'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000094'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000087',
    'Action Publication Precondition Order Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2, 12, 'USD', '{}'::jsonb
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000093',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', '71000000-0000-4000-8000-000000000087',
      '72000000-0000-4000-8000-000000000093',
      'fixture-action-publication-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000094',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000094',
      'fixture-action-publication-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000095',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000095',
      'fixture-action-publication-in-progress', 'RUNNING',
      v_input, NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-action-publication-completed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000093',
      'COMPLETED', v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-action-publication-failed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000094',
      'FAILED', v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-action-publication-in-progress', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000095',
      'IN_PROGRESS', NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000093',
    v_action_id, 1, 'ACTION_SUCCEEDED',
    '30000000-0000-4000-8000-000000000001',
    'Offer', '71000000-0000-4000-8000-000000000087',
    '72000000-0000-4000-8000-000000000093',
    v_completed_result,
    '10000000-0000-4000-8000-000000000001'
  );
END
$qa87_seed$;

-- No published v1 definition remains visible to the SECURITY DEFINER function.
DO $qa87_unpublish$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.action_definitions
  SET status = 'draft', updated_at = now()
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA87 expected to temporarily unpublish exactly one CREATE_OFFER v1 definition; updated %', v_rows;
  END IF;
END
$qa87_unpublish$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa87_assert$
DECLARE
  v_case record;
  v_error text;
  v_count integer;
  v_action_id uuid;
  v_original_hash text;
  v_input jsonb := '{"case":"action-publication-precondition-order"}'::jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'draft';

  IF v_action_id IS NULL OR (
    SELECT count(*) FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER' AND version = 1 AND status = 'draft'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA87 expected exactly one temporarily unpublished CREATE_OFFER v1 definition';
  END IF;

  v_original_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Action Publication Precondition Order Fixture Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2, 'price', 12, 'currency', 'USD',
    'conditions', NULL, 'market', NULL, 'geography', NULL,
    'attributes', '{}'::jsonb, 'documentationStatus', NULL,
    'lifecycle', NULL, 'offerType', NULL, 'pricingModel', NULL
  )::text);

  IF EXISTS (
    SELECT 1 FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) THEN
    RAISE EXCEPTION 'QA87 fixture still has a published CREATE_OFFER v1 definition';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-action-publication-completed'),
      ('FAILED', 'fixture-action-publication-failed'),
      ('IN_PROGRESS', 'fixture-action-publication-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      -- Exact same effective parameters as the stored request: if action
      -- publication were checked after idempotency, this would replay the
      -- completed/failed result or report ACTION_ALREADY_RUNNING instead.
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"action-publication-precondition-order"}'::jsonb,
        p_name => 'Action Publication Precondition Order Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2,
        p_price => 12,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA87 expected ACTION_NOT_PUBLISHED for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'ACTION_NOT_PUBLISHED' THEN
      RAISE EXCEPTION 'Published-action validation must precede idempotency hash/status handling for %; got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-action-publication-completed',
      'fixture-action-publication-failed',
      'fixture-action-publication-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA87 retries changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-action-publication-completed'
      AND action_id = v_action_id
      AND actor_id = '30000000-0000-4000-8000-000000000001'
      AND request_hash = v_original_hash
      AND request_hash = md5(jsonb_build_object(
        'input', '{"case":"action-publication-precondition-order"}'::jsonb,
        'name', 'Action Publication Precondition Order Fixture Offer',
        'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
        'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
        'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
        'quantity', 2, 'price', 12, 'currency', 'USD',
        'conditions', NULL, 'market', NULL, 'geography', NULL,
        'attributes', '{}'::jsonb, 'documentationStatus', NULL,
        'lifecycle', NULL, 'offerType', NULL, 'pricingModel', NULL
      )::text)
      AND status = 'COMPLETED'
      AND execution_id = '70000000-0000-4000-8000-000000000093'
      AND result = jsonb_build_object(
        'status', 'succeeded',
        'executionId', '70000000-0000-4000-8000-000000000093'::uuid,
        'objectType', 'Offer',
        'objectId', '71000000-0000-4000-8000-000000000087'::uuid
      )
      AND completed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'QA87 changed the original COMPLETED idempotency result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-action-publication-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000094'
        AND result = jsonb_build_object(
          'status', 'failed',
          'executionId', '70000000-0000-4000-8000-000000000094'::uuid,
          'error', 'fixture failure'
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-action-publication-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000095'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA87 changed the original FAILED or IN_PROGRESS idempotency result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND action_version = 1
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = v_input
    AND (
      (id = '70000000-0000-4000-8000-000000000093'
        AND idempotency_key = 'fixture-action-publication-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000087'
        AND result->>'status' = 'succeeded'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000094'
        AND idempotency_key = 'fixture-action-publication-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result->>'status' = 'failed'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000095'
        AND idempotency_key = 'fixture-action-publication-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA87 retries changed original execution state';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000087'
    AND name = 'Action Publication Precondition Order Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA87 retries changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000093'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000087'
    AND payload->>'status' = 'succeeded';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA87 retries changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000093',
    '70000000-0000-4000-8000-000000000094',
    '70000000-0000-4000-8000-000000000095'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA87 retries unexpectedly created or removed action events';
  END IF;
END
$qa87_assert$;

RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

-- Restore the published action definition before any following integration
-- tests. If an assertion above fails, the enclosing transaction rolls back.
DO $qa87_restore$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.action_definitions
  SET status = 'published', updated_at = now()
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'draft';

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA87 expected to restore exactly one published CREATE_OFFER v1 definition; updated %', v_rows;
  END IF;

  IF (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA87 failed to restore exactly one published CREATE_OFFER v1 definition';
  END IF;
END
$qa87_restore$;

COMMIT;

SELECT 'CREATE_OFFER published-action precondition precedes idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (3 retries); fixture status restored' AS result;


-- OFFER-QA-88: quantity, price and currency validation must precede
-- idempotency hash/status handling for existing COMPLETED, FAILED and
-- IN_PROGRESS keys. All fixtures live only in the disposable CI database.
BEGIN;

DO $qa88_seed$
DECLARE
  v_action_id uuid;
  v_request_hash text;
  v_input jsonb := '{"case":"numeric-currency-validation-precedence"}'::jsonb;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := now();
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL OR (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA88 requires exactly one published CREATE_OFFER v1 definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Numeric Currency Validation Precedence Fixture Offer',
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000096'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000088'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000097'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000088',
    'Numeric Currency Validation Precedence Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2, 12, 'USD', '{}'::jsonb
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000096',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', '71000000-0000-4000-8000-000000000088',
      '72000000-0000-4000-8000-000000000096',
      'fixture-numeric-validation-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000097',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000097',
      'fixture-numeric-validation-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000098',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000098',
      'fixture-numeric-validation-in-progress', 'RUNNING',
      v_input, NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-numeric-validation-completed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000096',
      'COMPLETED', v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-numeric-validation-failed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000097',
      'FAILED', v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-numeric-validation-in-progress', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000098',
      'IN_PROGRESS', NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000096',
    v_action_id, 1, 'ACTION_SUCCEEDED',
    '30000000-0000-4000-8000-000000000001',
    'Offer', '71000000-0000-4000-8000-000000000088',
    '72000000-0000-4000-8000-000000000096',
    v_completed_result,
    '10000000-0000-4000-8000-000000000001'
  );
END
$qa88_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa88_assert$
DECLARE
  v_case record;
  v_validation record;
  v_error text;
  v_count integer;
  v_action_id uuid;
  v_original_hash text;
  v_input jsonb := '{"case":"numeric-currency-validation-precedence"}'::jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  v_original_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Numeric Currency Validation Precedence Fixture Offer',
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
  )::text);

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-numeric-validation-completed'),
      ('FAILED', 'fixture-numeric-validation-failed'),
      ('IN_PROGRESS', 'fixture-numeric-validation-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    FOR v_validation IN
      SELECT *
      FROM (VALUES
        ('quantity', 'INVALID_QUANTITY'),
        ('price', 'INVALID_PRICE'),
        ('currency', 'INVALID_CURRENCY')
      ) AS validations(field_name, expected_error)
    LOOP
      v_error := NULL;
      BEGIN
        -- Change exactly one validated argument. The other business fields,
        -- actor, tenant, demand and active product remain valid and unchanged.
        PERFORM public.execute_create_offer_v1(
          p_tenant_id => '10000000-0000-4000-8000-000000000001',
          p_idempotency_key => v_case.idempotency_key,
          p_input => '{"case":"numeric-currency-validation-precedence"}'::jsonb,
          p_name => 'Numeric Currency Validation Precedence Fixture Offer',
          p_demand_id => '50000000-0000-4000-8000-000000000001',
          p_product_master_id => '40000000-0000-4000-8000-000000000001',
          p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
          p_quantity => CASE
            WHEN v_validation.field_name = 'quantity' THEN 'NaN'::numeric
            ELSE 2::numeric
          END,
          p_price => CASE
            WHEN v_validation.field_name = 'price' THEN 'Infinity'::numeric
            ELSE 12::numeric
          END,
          p_currency => CASE
            WHEN v_validation.field_name = 'currency' THEN 'XYZ'
            ELSE 'USD'
          END,
          p_conditions => NULL,
          p_market => NULL,
          p_geography => NULL,
          p_attributes => '{}'::jsonb,
          p_documentation_status => NULL,
          p_lifecycle => NULL,
          p_offer_type => NULL,
          p_pricing_model => NULL
        );
        RAISE EXCEPTION 'QA88 expected % for % key and % variation',
          v_validation.expected_error, v_case.status_name, v_validation.field_name;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
      END;

      IF v_error IS DISTINCT FROM v_validation.expected_error THEN
        RAISE EXCEPTION 'Numeric/currency validation must precede hash/status handling for % key (%); expected %, got %',
          v_case.status_name, v_validation.field_name,
          v_validation.expected_error, coalesce(v_error, '<no error>');
      END IF;
    END LOOP;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-numeric-validation-completed',
      'fixture-numeric-validation-failed',
      'fixture-numeric-validation-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA88 retries changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-numeric-validation-completed'
        AND status = 'COMPLETED'
        AND execution_id = '70000000-0000-4000-8000-000000000096'
        AND result = jsonb_build_object(
          'status', 'succeeded',
          'executionId', '70000000-0000-4000-8000-000000000096'::uuid,
          'objectType', 'Offer',
          'objectId', '71000000-0000-4000-8000-000000000088'::uuid
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-numeric-validation-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000097'
        AND result = jsonb_build_object(
          'status', 'failed',
          'executionId', '70000000-0000-4000-8000-000000000097'::uuid,
          'error', 'fixture failure'
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-numeric-validation-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000098'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA88 retries changed original idempotency hash, status, execution or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND action_version = 1
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = v_input
    AND (
      (id = '70000000-0000-4000-8000-000000000096'
        AND idempotency_key = 'fixture-numeric-validation-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000088'
        AND result->>'status' = 'succeeded'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000097'
        AND idempotency_key = 'fixture-numeric-validation-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result->>'status' = 'failed'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000098'
        AND idempotency_key = 'fixture-numeric-validation-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA88 retries changed original execution status, actor, object or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000088'
    AND name = 'Numeric Currency Validation Precedence Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA88 retries changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000096'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000088'
    AND payload = jsonb_build_object(
      'status', 'succeeded',
      'executionId', '70000000-0000-4000-8000-000000000096'::uuid,
      'objectType', 'Offer',
      'objectId', '71000000-0000-4000-8000-000000000088'::uuid
    );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA88 retries changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000096',
    '70000000-0000-4000-8000-000000000097',
    '70000000-0000-4000-8000-000000000098'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA88 retries unexpectedly created or removed action events';
  END IF;
END
$qa88_assert$;

RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

COMMIT;

SELECT 'CREATE_OFFER quantity, price and currency validations precede idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (9 retries) assertions passed' AS result;

-- OFFER-QA-89: NULL p_input must be rejected before idempotency hash/status handling
-- Existing COMPLETED, FAILED and IN_PROGRESS fixtures use the same valid
-- request. Each replay changes only p_input to SQL NULL. All data is confined
-- to the disposable PostgreSQL integration database.
BEGIN;

DO $qa89_seed$
DECLARE
  v_action_id uuid;
  v_request_hash text;
  v_input jsonb := '{"case":"action-input-required-precedence"}'::jsonb;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := now();
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL OR (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA89 requires exactly one published CREATE_OFFER v1 definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Action Input Required Precedence Fixture Offer',
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000099'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000089'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000100'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000089',
    'Action Input Required Precedence Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2, 12, 'USD', '{}'::jsonb
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000099',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', '71000000-0000-4000-8000-000000000089',
      '72000000-0000-4000-8000-000000000099',
      'fixture-action-input-required-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000100',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000100',
      'fixture-action-input-required-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000101',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000101',
      'fixture-action-input-required-in-progress', 'RUNNING',
      v_input, NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-action-input-required-completed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000099',
      'COMPLETED', v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-action-input-required-failed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000100',
      'FAILED', v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-action-input-required-in-progress', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000101',
      'IN_PROGRESS', NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000099',
    v_action_id, 1, 'ACTION_SUCCEEDED',
    '30000000-0000-4000-8000-000000000001',
    'Offer', '71000000-0000-4000-8000-000000000089',
    '72000000-0000-4000-8000-000000000099',
    v_completed_result,
    '10000000-0000-4000-8000-000000000001'
  );
END
$qa89_seed$;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa89_assert$
DECLARE
  v_case record;
  v_error text;
  v_count integer;
  v_action_id uuid;
  v_original_hash text;
  v_input jsonb := '{"case":"action-input-required-precedence"}'::jsonb;
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  v_original_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Action Input Required Precedence Fixture Offer',
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
  )::text);

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-action-input-required-completed'),
      ('FAILED', 'fixture-action-input-required-failed'),
      ('IN_PROGRESS', 'fixture-action-input-required-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      -- Keep every other argument valid and identical to the stored request.
      -- SQL NULL input must be rejected before hash or status lookup.
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => NULL::jsonb,
        p_name => 'Action Input Required Precedence Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2::numeric,
        p_price => 12::numeric,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA89 expected ACTION_INPUT_REQUIRED for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'ACTION_INPUT_REQUIRED' THEN
      RAISE EXCEPTION 'p_input SQL NULL must precede hash/status handling for % key; expected ACTION_INPUT_REQUIRED, got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-action-input-required-completed',
      'fixture-action-input-required-failed',
      'fixture-action-input-required-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA89 retries changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-action-input-required-completed'
        AND status = 'COMPLETED'
        AND execution_id = '70000000-0000-4000-8000-000000000099'
        AND result = jsonb_build_object(
          'status', 'succeeded',
          'executionId', '70000000-0000-4000-8000-000000000099'::uuid,
          'objectType', 'Offer',
          'objectId', '71000000-0000-4000-8000-000000000089'::uuid
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-action-input-required-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000100'
        AND result = jsonb_build_object(
          'status', 'failed',
          'executionId', '70000000-0000-4000-8000-000000000100'::uuid,
          'error', 'fixture failure'
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-action-input-required-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000101'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA89 retries changed original idempotency hash, status, execution or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND action_version = 1
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = v_input
    AND (
      (id = '70000000-0000-4000-8000-000000000099'
        AND idempotency_key = 'fixture-action-input-required-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000089'
        AND result->>'status' = 'succeeded'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000100'
        AND idempotency_key = 'fixture-action-input-required-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result->>'status' = 'failed'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000101'
        AND idempotency_key = 'fixture-action-input-required-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA89 retries changed original execution status, actor, object or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000089'
    AND name = 'Action Input Required Precedence Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA89 retries changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000099'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000089'
    AND payload = jsonb_build_object(
      'status', 'succeeded',
      'executionId', '70000000-0000-4000-8000-000000000099'::uuid,
      'objectType', 'Offer',
      'objectId', '71000000-0000-4000-8000-000000000089'::uuid
    );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA89 retries changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000099',
    '70000000-0000-4000-8000-000000000100',
    '70000000-0000-4000-8000-000000000101'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA89 retries unexpectedly created or removed action events';
  END IF;
END
$qa89_assert$;

RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

COMMIT;

SELECT 'CREATE_OFFER SQL NULL p_input validation precedes idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (3 retries) assertions passed' AS result;


-- OFFER-QA-90: authentication must precede tenant and idempotency lookups.
BEGIN;

DO $qa90_seed$
DECLARE
  v_action_id uuid;
  v_request_hash text;
  v_input jsonb := '{"case":"unauthenticated-precedence"}'::jsonb;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := now();
BEGIN
  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL OR (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA90 requires exactly one published CREATE_OFFER v1 definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Unauthenticated Precedence Fixture Offer',
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000109'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000099'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000110'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000099',
    'Unauthenticated Precedence Fixture Offer',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2, 12, 'USD', '{}'::jsonb
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000109',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', '71000000-0000-4000-8000-000000000099',
      '72000000-0000-4000-8000-000000000109',
      'fixture-unauthenticated-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000110',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000110',
      'fixture-unauthenticated-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      '70000000-0000-4000-8000-000000000111',
      v_action_id, 1, '30000000-0000-4000-8000-000000000001',
      'Offer', NULL,
      '72000000-0000-4000-8000-000000000111',
      'fixture-unauthenticated-in-progress', 'RUNNING',
      v_input, NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-unauthenticated-completed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000109',
      'COMPLETED', v_completed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-unauthenticated-failed', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000110',
      'FAILED', v_failed_result, v_terminal_at,
      '10000000-0000-4000-8000-000000000001'
    ),
    (
      'fixture-unauthenticated-in-progress', v_action_id,
      '30000000-0000-4000-8000-000000000001', v_request_hash,
      '70000000-0000-4000-8000-000000000111',
      'IN_PROGRESS', NULL, NULL,
      '10000000-0000-4000-8000-000000000001'
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000109',
    v_action_id, 1, 'ACTION_SUCCEEDED',
    '30000000-0000-4000-8000-000000000001',
    'Offer', '71000000-0000-4000-8000-000000000099',
    '72000000-0000-4000-8000-000000000109',
    v_completed_result,
    '10000000-0000-4000-8000-000000000001'
  );
END
$qa90_seed$;

-- The empty JWT subject makes auth.uid() return SQL NULL in this fixture.
SET request.jwt.claim.sub = '';
SET ROLE authenticated;

DO $qa90_assert$
DECLARE
  v_case record;
  v_error text;
BEGIN
  IF auth.uid() IS NOT NULL THEN
    RAISE EXCEPTION 'QA90 fixture must have a NULL auth.uid() before replay';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-unauthenticated-completed'),
      ('FAILED', 'fixture-unauthenticated-failed'),
      ('IN_PROGRESS', 'fixture-unauthenticated-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      -- All business arguments are valid; only the JWT subject is absent.
      -- Authentication must fail before tenant access or status/result lookup.
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"unauthenticated-precedence"}'::jsonb,
        p_name => 'Unauthenticated Precedence Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2::numeric,
        p_price => 12::numeric,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA90 expected UNAUTHENTICATED for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'UNAUTHENTICATED' THEN
      RAISE EXCEPTION 'Authentication must precede idempotency result handling for % key; expected UNAUTHENTICATED, got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;
END
$qa90_assert$;

RESET ROLE;
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

DO $qa90_integrity$
DECLARE
  v_action_id uuid;
  v_input jsonb := '{"case":"unauthenticated-precedence"}'::jsonb;
  v_original_hash text;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA90 must restore the original authenticated JWT subject after negative tests';
  END IF;

  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  v_original_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Unauthenticated Precedence Fixture Offer',
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
  )::text);

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-unauthenticated-completed',
      'fixture-unauthenticated-failed',
      'fixture-unauthenticated-in-progress'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA90 unauthenticated replays changed or duplicated idempotency rows; expected 3, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND request_hash = v_original_hash
    AND (
      (key = 'fixture-unauthenticated-completed'
        AND status = 'COMPLETED'
        AND execution_id = '70000000-0000-4000-8000-000000000109'
        AND result = jsonb_build_object(
          'status', 'succeeded',
          'executionId', '70000000-0000-4000-8000-000000000109'::uuid,
          'objectType', 'Offer',
          'objectId', '71000000-0000-4000-8000-000000000099'::uuid
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-unauthenticated-failed'
        AND status = 'FAILED'
        AND execution_id = '70000000-0000-4000-8000-000000000110'
        AND result = jsonb_build_object(
          'status', 'failed',
          'executionId', '70000000-0000-4000-8000-000000000110'::uuid,
          'error', 'fixture failure'
        )
        AND completed_at IS NOT NULL)
      OR
      (key = 'fixture-unauthenticated-in-progress'
        AND status = 'IN_PROGRESS'
        AND execution_id = '70000000-0000-4000-8000-000000000111'
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA90 unauthenticated replays changed original key hash, status, execution or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND action_id = v_action_id
    AND action_version = 1
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND input = v_input
    AND (
      (id = '70000000-0000-4000-8000-000000000109'
        AND idempotency_key = 'fixture-unauthenticated-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000099'
        AND result->>'status' = 'succeeded'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000110'
        AND idempotency_key = 'fixture-unauthenticated-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result->>'status' = 'failed'
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000111'
        AND idempotency_key = 'fixture-unauthenticated-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA90 unauthenticated replays changed original execution status, actor, object or result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000099'
    AND name = 'Unauthenticated Precedence Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA90 unauthenticated replays changed or duplicated the original offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000109'
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = '71000000-0000-4000-8000-000000000099'
    AND payload = jsonb_build_object(
      'status', 'succeeded',
      'executionId', '70000000-0000-4000-8000-000000000109'::uuid,
      'objectType', 'Offer',
      'objectId', '71000000-0000-4000-8000-000000000099'::uuid
    );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA90 unauthenticated replays changed or duplicated the original success event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000109',
    '70000000-0000-4000-8000-000000000110',
    '70000000-0000-4000-8000-000000000111'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA90 unauthenticated replays unexpectedly created or removed action events';
  END IF;
END
$qa90_integrity$;

COMMIT;

SELECT 'CREATE_OFFER authentication validation precedes tenant and idempotency result handling for COMPLETED, FAILED and IN_PROGRESS keys (3 retries); JWT subject restored; original records unchanged' AS result;

-- OFFER-QA-91: tenant and idempotency-key requirements must reject before writes.
BEGIN;

CREATE TEMP TABLE qa91_baseline ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
  (SELECT count(*) FROM public.action_executions) AS execution_count,
  (SELECT count(*) FROM public.offers) AS offer_count,
  (SELECT count(*) FROM public.action_events) AS event_count;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa91_assert$
DECLARE
  v_case record;
  v_error text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA91 requires the authenticated fixture user before testing required tenant/key arguments';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('null tenant', NULL::uuid, 'fixture-qa91-null-tenant'::text, 'TENANT_REQUIRED'::text),
      ('null key', '10000000-0000-4000-8000-000000000001'::uuid, NULL::text, 'IDEMPOTENCY_KEY_REQUIRED'::text),
      ('empty key', '10000000-0000-4000-8000-000000000001'::uuid, ''::text, 'IDEMPOTENCY_KEY_REQUIRED'::text),
      ('whitespace key', '10000000-0000-4000-8000-000000000001'::uuid, '   '::text, 'IDEMPOTENCY_KEY_REQUIRED'::text)
    ) AS cases(case_name, tenant_id, idempotency_key, expected_error)
  LOOP
    v_error := NULL;
    BEGIN
      -- All later arguments are valid. Only the required tenant/key argument varies.
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => v_case.tenant_id,
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"qa91-required-tenant-key-preconditions"}'::jsonb,
        p_name => 'QA91 Required Tenant Key Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2::numeric,
        p_price => 12::numeric,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA91 expected % for % case', v_case.expected_error, v_case.case_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM v_case.expected_error THEN
      RAISE EXCEPTION 'Required tenant/key precondition mismatch for %: expected %, got %',
        v_case.case_name, v_case.expected_error, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;
END
$qa91_assert$;

RESET ROLE;

DO $qa91_integrity$
DECLARE
  v_before record;
  v_after record;
BEGIN
  SELECT * INTO v_before FROM pg_temp.qa91_baseline;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(
    v_after.idempotency_count,
    v_after.execution_count,
    v_after.offer_count,
    v_after.event_count
  ) IS DISTINCT FROM ROW(
    v_before.idempotency_count,
    v_before.execution_count,
    v_before.offer_count,
    v_before.event_count
  ) THEN
    RAISE EXCEPTION
      'QA91 invalid tenant/key arguments created or removed rows (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.idempotency_keys
    WHERE key = 'fixture-qa91-null-tenant'
  ) OR EXISTS (
    SELECT 1
    FROM public.action_executions
    WHERE idempotency_key = 'fixture-qa91-null-tenant'
  ) THEN
    RAISE EXCEPTION 'QA91 null-tenant call unexpectedly created a keyed execution or idempotency row';
  END IF;
END
$qa91_integrity$;

COMMIT;

SELECT 'CREATE_OFFER null tenant and null/empty/whitespace idempotency-key preconditions rejected before writes (4 cases); row counts unchanged' AS result;

-- OFFER-QA-92: a profile without an actor must be rejected before idempotency handling.
-- Keep the profile row and tenant membership; only actor_id is temporarily NULL.
-- All mutations are confined to this disposable PostgreSQL CI transaction.
BEGIN;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

DO $qa92_seed$
DECLARE
  v_action_id uuid;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_user_id uuid := '20000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"profile-actor-not-found-precedence"}'::jsonb;
  v_name text := 'Profile Actor Missing Precedence Fixture Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_request_hash text;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := clock_timestamp();
  v_rows integer;
BEGIN
  SELECT count(*) INTO v_rows
  FROM public.profiles
  WHERE auth_user_id = v_user_id
    AND actor_id = v_actor_id;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA92 requires exactly one provider A profile with its original actor_id';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = v_tenant_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'QA92 requires the original tenant A membership to remain present';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key IN (
        'fixture-profile-actor-completed',
        'fixture-profile-actor-failed',
        'fixture-profile-actor-in-progress'
      )
  ) THEN
    RAISE EXCEPTION 'QA92 idempotency fixture keys already exist';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE id IN (
      '70000000-0000-4000-8000-000000000112',
      '70000000-0000-4000-8000-000000000113',
      '70000000-0000-4000-8000-000000000114'
    )
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE id = '71000000-0000-4000-8000-000000000100'
  ) THEN
    RAISE EXCEPTION 'QA92 fixture execution or offer IDs already exist';
  END IF;

  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL OR (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA92 requires exactly one published CREATE_OFFER v1 definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000112'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000100'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000113'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, conditions, market, geography,
    documentation_status, lifecycle, offer_type, pricing_model, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000100',
    v_name, v_demand_id, v_product_master_id, v_actor_id,
    2, 12, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{}'::jsonb
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000112',
      v_action_id, 1, v_actor_id, 'Offer',
      '71000000-0000-4000-8000-000000000100',
      '72000000-0000-4000-8000-000000000112',
      'fixture-profile-actor-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000113',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000113',
      'fixture-profile-actor-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000114',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000114',
      'fixture-profile-actor-in-progress', 'RUNNING',
      v_input, NULL, NULL, v_tenant_id
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-profile-actor-completed', v_action_id, v_actor_id, v_request_hash,
      '70000000-0000-4000-8000-000000000112',
      'COMPLETED', v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-profile-actor-failed', v_action_id, v_actor_id, v_request_hash,
      '70000000-0000-4000-8000-000000000113',
      'FAILED', v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-profile-actor-in-progress', v_action_id, v_actor_id, v_request_hash,
      '70000000-0000-4000-8000-000000000114',
      'IN_PROGRESS', NULL, NULL, v_tenant_id
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000112',
    v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', '71000000-0000-4000-8000-000000000100',
    '72000000-0000-4000-8000-000000000112',
    v_completed_result, v_tenant_id
  );

  UPDATE public.profiles
  SET actor_id = NULL
  WHERE auth_user_id = v_user_id
    AND actor_id = v_actor_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA92 expected to null actor_id on exactly one provider A profile, updated % rows', v_rows;
  END IF;
END
$qa92_seed$;

CREATE TEMP TABLE qa92_baseline ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
  (SELECT count(*) FROM public.action_executions) AS execution_count,
  (SELECT count(*) FROM public.offers) AS offer_count,
  (SELECT count(*) FROM public.action_events) AS event_count;

SET ROLE authenticated;

DO $qa92_assert$
DECLARE
  v_case record;
  v_error text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA92 requires authenticated provider A before testing a missing profile actor';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
      AND actor_id IS NULL
  ) THEN
    RAISE EXCEPTION 'QA92 must retain provider A profile row while actor_id is NULL';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-profile-actor-completed'),
      ('FAILED', 'fixture-profile-actor-failed'),
      ('IN_PROGRESS', 'fixture-profile-actor-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      -- All arguments, including provider_actor_id, remain valid.
      -- The profile row exists; only its actor_id is temporarily absent.
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"profile-actor-not-found-precedence"}'::jsonb,
        p_name => 'Profile Actor Missing Precedence Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2::numeric,
        p_price => 12::numeric,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA92 expected PROFILE_ACTOR_NOT_FOUND for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'PROFILE_ACTOR_NOT_FOUND' THEN
      RAISE EXCEPTION 'Profile actor precondition mismatch for % key: expected PROFILE_ACTOR_NOT_FOUND, got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;
END
$qa92_assert$;

RESET ROLE;

DO $qa92_restore$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.profiles
  SET actor_id = '30000000-0000-4000-8000-000000000001'
  WHERE auth_user_id = '20000000-0000-4000-8000-000000000001'
    AND actor_id IS NULL;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA92 expected to restore exactly one provider A profile actor_id, restored % rows', v_rows;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000001'
      AND actor_id = '30000000-0000-4000-8000-000000000001'
  ) THEN
    RAISE EXCEPTION 'QA92 failed to restore the original provider A profile actor_id';
  END IF;
END
$qa92_restore$;

DO $qa92_integrity$
DECLARE
  v_action_id uuid;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_request_hash text;
  v_input jsonb := '{"case":"profile-actor-not-found-precedence"}'::jsonb;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz;
  v_before record;
  v_after record;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA92 must preserve the authenticated provider A JWT subject';
  END IF;

  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Profile Actor Missing Precedence Fixture Offer',
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000112'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000100'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000113'::uuid,
    'error', 'fixture failure'
  );

  SELECT * INTO v_before FROM pg_temp.qa92_baseline;
  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count)
     IS DISTINCT FROM
     ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count) THEN
    RAISE EXCEPTION 'QA92 profile actor replays created or removed rows (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key IN (
      'fixture-profile-actor-completed',
      'fixture-profile-actor-failed',
      'fixture-profile-actor-in-progress'
    )
    AND action_id = v_action_id
    AND actor_id = v_actor_id
    AND request_hash = v_request_hash;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA92 expected all three original idempotency keys and hashes to remain unchanged, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key = 'fixture-profile-actor-completed'
      AND execution_id = '70000000-0000-4000-8000-000000000112'
      AND status = 'COMPLETED'
      AND result = v_completed_result
      AND completed_at IS NOT NULL
      AND completed_at = (SELECT completed_at FROM public.action_executions WHERE id = '70000000-0000-4000-8000-000000000112' AND tenant_id = v_tenant_id)
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key = 'fixture-profile-actor-failed'
      AND execution_id = '70000000-0000-4000-8000-000000000113'
      AND status = 'FAILED'
      AND result = v_failed_result
      AND completed_at IS NOT NULL
      AND completed_at = (SELECT completed_at FROM public.action_executions WHERE id = '70000000-0000-4000-8000-000000000113' AND tenant_id = v_tenant_id)
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key = 'fixture-profile-actor-in-progress'
      AND execution_id = '70000000-0000-4000-8000-000000000114'
      AND status = 'IN_PROGRESS'
      AND result IS NULL
      AND completed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'QA92 original idempotency status, execution, result or timestamp changed';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND actor_id = v_actor_id
    AND input = v_input
    AND (
      (id = '70000000-0000-4000-8000-000000000112'
        AND idempotency_key = 'fixture-profile-actor-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000100'
        AND result = v_completed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000113'
        AND idempotency_key = 'fixture-profile-actor-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result = v_failed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000114'
        AND idempotency_key = 'fixture-profile-actor-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA92 original action executions, status or results changed';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000100'
    AND name = 'Profile Actor Missing Precedence Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = v_actor_id
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA92 original offer changed or duplicated';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000112'
    AND tenant_id = v_tenant_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = v_actor_id
    AND object_id = '71000000-0000-4000-8000-000000000100'
    AND payload = v_completed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA92 original ACTION_SUCCEEDED event changed or duplicated';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000112',
    '70000000-0000-4000-8000-000000000113',
    '70000000-0000-4000-8000-000000000114'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA92 profile actor replays unexpectedly created or removed action events';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE auth_user_id = '20000000-0000-4000-8000-000000000001'
      AND actor_id = v_actor_id
  ) THEN
    RAISE EXCEPTION 'QA92 provider A profile actor_id was not restored';
  END IF;
END
$qa92_integrity$;

COMMIT;

SELECT 'CREATE_OFFER missing profile actor validation precedes idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (3 retries); profile actor_id restored; original records unchanged' AS result;


-- OFFER-QA-93: an absent profile row must be rejected before idempotency handling.
-- Remove the profile row only after backing it up in this disposable PostgreSQL CI transaction.
-- The fixture schema has no inbound FK or user trigger on profiles; runtime guards recheck both.
BEGIN;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

CREATE TEMP TABLE qa93_profile_backup ON COMMIT DROP AS
SELECT * FROM public.profiles
WHERE auth_user_id = '20000000-0000-4000-8000-000000000001';

DO $qa93_seed$
DECLARE
  v_action_id uuid;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_user_id uuid := '20000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_input jsonb := '{"case":"profile-row-absent-precedence"}'::jsonb;
  v_name text := 'Profile Row Absent Precedence Fixture Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_request_hash text;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz := clock_timestamp();
  v_rows integer;
BEGIN
  SELECT count(*) INTO v_rows
  FROM public.profiles
  WHERE auth_user_id = v_user_id
    AND actor_id = v_actor_id;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA93 requires exactly one provider A profile with its original actor_id';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = v_tenant_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'QA93 requires the original tenant A membership to remain present';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key IN (
        'fixture-profile-row-absent-completed',
        'fixture-profile-row-absent-failed',
        'fixture-profile-row-absent-in-progress'
      )
  ) THEN
    RAISE EXCEPTION 'QA93 idempotency fixture keys already exist';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE id IN (
      '70000000-0000-4000-8000-000000000193',
      '70000000-0000-4000-8000-000000000194',
      '70000000-0000-4000-8000-000000000195'
    )
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE id = '71000000-0000-4000-8000-000000000193'
  ) THEN
    RAISE EXCEPTION 'QA93 fixture execution or offer IDs already exist';
  END IF;

  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  IF v_action_id IS NULL OR (
    SELECT count(*)
    FROM public.action_definitions
    WHERE action_key = 'CREATE_OFFER'
      AND version = 1
      AND status = 'published'
  ) <> 1 THEN
    RAISE EXCEPTION 'QA93 requires exactly one published CREATE_OFFER v1 definition';
  END IF;

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000193'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000193'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000194'::uuid,
    'error', 'fixture failure'
  );

  INSERT INTO public.offers(
    id, name, demand_id, product_master_id, provider_actor_id,
    quantity, price, currency, conditions, market, geography,
    documentation_status, lifecycle, offer_type, pricing_model, attributes
  )
  VALUES (
    '71000000-0000-4000-8000-000000000193',
    v_name, v_demand_id, v_product_master_id, v_actor_id,
    2, 12, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{}'::jsonb
  );

  INSERT INTO public.action_executions(
    id, action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, result, completed_at, tenant_id
  )
  VALUES
    (
      '70000000-0000-4000-8000-000000000193',
      v_action_id, 1, v_actor_id, 'Offer',
      '71000000-0000-4000-8000-000000000193',
      '72000000-0000-4000-8000-000000000193',
      'fixture-profile-row-absent-completed', 'COMPLETED',
      v_input, v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000194',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000194',
      'fixture-profile-row-absent-failed', 'FAILED',
      v_input, v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      '70000000-0000-4000-8000-000000000195',
      v_action_id, 1, v_actor_id, 'Offer', NULL,
      '72000000-0000-4000-8000-000000000195',
      'fixture-profile-row-absent-in-progress', 'RUNNING',
      v_input, NULL, NULL, v_tenant_id
    );

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, completed_at, tenant_id
  )
  VALUES
    (
      'fixture-profile-row-absent-completed', v_action_id, v_actor_id, v_request_hash,
      '70000000-0000-4000-8000-000000000193',
      'COMPLETED', v_completed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-profile-row-absent-failed', v_action_id, v_actor_id, v_request_hash,
      '70000000-0000-4000-8000-000000000194',
      'FAILED', v_failed_result, v_terminal_at, v_tenant_id
    ),
    (
      'fixture-profile-row-absent-in-progress', v_action_id, v_actor_id, v_request_hash,
      '70000000-0000-4000-8000-000000000195',
      'IN_PROGRESS', NULL, NULL, v_tenant_id
    );

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    '70000000-0000-4000-8000-000000000193',
    v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', '71000000-0000-4000-8000-000000000193',
    '72000000-0000-4000-8000-000000000193',
    v_completed_result, v_tenant_id
  );

  SELECT count(*) INTO v_rows
  FROM pg_temp.qa93_profile_backup
  WHERE auth_user_id = v_user_id
    AND actor_id = v_actor_id;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA93 expected an exact backup of the original provider A profile row';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE contype = 'f'
      AND confrelid = 'public.profiles'::regclass
  ) THEN
    RAISE EXCEPTION 'QA93 refuses to delete a profile while inbound foreign keys exist';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'QA93 refuses to delete a profile while user-defined triggers exist';
  END IF;

  DELETE FROM public.profiles
  WHERE auth_user_id = v_user_id
    AND actor_id = v_actor_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA93 expected to delete exactly one provider A profile row, deleted % rows', v_rows;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.profiles WHERE auth_user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'QA93 provider A profile row still exists after the isolated delete';
  END IF;
END
$qa93_seed$;

CREATE TEMP TABLE qa93_baseline ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
  (SELECT count(*) FROM public.action_executions) AS execution_count,
  (SELECT count(*) FROM public.offers) AS offer_count,
  (SELECT count(*) FROM public.action_events) AS event_count;

SET ROLE authenticated;

DO $qa93_assert$
DECLARE
  v_case record;
  v_error text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA93 requires authenticated provider A before testing a missing profile row';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('COMPLETED', 'fixture-profile-row-absent-completed'),
      ('FAILED', 'fixture-profile-row-absent-failed'),
      ('IN_PROGRESS', 'fixture-profile-row-absent-in-progress')
    ) AS cases(status_name, idempotency_key)
  LOOP
    v_error := NULL;
    BEGIN
      -- All arguments, including provider_actor_id, remain valid.
      -- The profile row is absent; all other call arguments remain valid.
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_case.idempotency_key,
        p_input => '{"case":"profile-row-absent-precedence"}'::jsonb,
        p_name => 'Profile Row Absent Precedence Fixture Offer',
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2::numeric,
        p_price => 12::numeric,
        p_currency => 'USD',
        p_conditions => NULL,
        p_market => NULL,
        p_geography => NULL,
        p_attributes => '{}'::jsonb,
        p_documentation_status => NULL,
        p_lifecycle => NULL,
        p_offer_type => NULL,
        p_pricing_model => NULL
      );
      RAISE EXCEPTION 'QA93 expected PROFILE_ACTOR_NOT_FOUND for % key', v_case.status_name;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'PROFILE_ACTOR_NOT_FOUND' THEN
      RAISE EXCEPTION 'Missing profile row precondition mismatch for % key: expected PROFILE_ACTOR_NOT_FOUND, got %',
        v_case.status_name, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;
END
$qa93_assert$;

RESET ROLE;

DO $qa93_restore$
DECLARE
  v_rows integer;
BEGIN
  INSERT INTO public.profiles (
    id, name, actor_id, auth_user_id, context_fields,
    status, version, created_at, updated_at
  )
  SELECT
    id, name, actor_id, auth_user_id, context_fields,
    status, version, created_at, updated_at
  FROM pg_temp.qa93_profile_backup;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'QA93 expected to restore exactly one complete provider A profile row, restored % rows', v_rows;
  END IF;

  IF (
    SELECT count(*)
    FROM public.profiles p
    JOIN pg_temp.qa93_profile_backup b ON b.id = p.id
    WHERE to_jsonb(p) IS NOT DISTINCT FROM to_jsonb(b)
  ) <> 1 THEN
    RAISE EXCEPTION 'QA93 restored provider A profile row differs from the complete backup';
  END IF;
END
$qa93_restore$;

DO $qa93_integrity$
DECLARE
  v_action_id uuid;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_request_hash text;
  v_input jsonb := '{"case":"profile-row-absent-precedence"}'::jsonb;
  v_completed_result jsonb;
  v_failed_result jsonb;
  v_terminal_at timestamptz;
  v_before record;
  v_after record;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA93 must preserve the authenticated provider A JWT subject';
  END IF;

  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER'
    AND version = 1
    AND status = 'published';

  v_request_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'Profile Row Absent Precedence Fixture Offer',
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
  )::text);

  v_completed_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', '70000000-0000-4000-8000-000000000193'::uuid,
    'objectType', 'Offer',
    'objectId', '71000000-0000-4000-8000-000000000193'::uuid
  );
  v_failed_result := jsonb_build_object(
    'status', 'failed',
    'executionId', '70000000-0000-4000-8000-000000000194'::uuid,
    'error', 'fixture failure'
  );

  SELECT * INTO v_before FROM pg_temp.qa93_baseline;
  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count)
     IS DISTINCT FROM
     ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count) THEN
    RAISE EXCEPTION 'QA93 missing profile row replays created or removed rows (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key IN (
      'fixture-profile-row-absent-completed',
      'fixture-profile-row-absent-failed',
      'fixture-profile-row-absent-in-progress'
    )
    AND action_id = v_action_id
    AND actor_id = v_actor_id
    AND request_hash = v_request_hash;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA93 expected all three original idempotency keys and hashes to remain unchanged, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key = 'fixture-profile-row-absent-completed'
      AND execution_id = '70000000-0000-4000-8000-000000000193'
      AND status = 'COMPLETED'
      AND result = v_completed_result
      AND completed_at IS NOT NULL
      AND completed_at = (SELECT completed_at FROM public.action_executions WHERE id = '70000000-0000-4000-8000-000000000193' AND tenant_id = v_tenant_id)
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key = 'fixture-profile-row-absent-failed'
      AND execution_id = '70000000-0000-4000-8000-000000000194'
      AND status = 'FAILED'
      AND result = v_failed_result
      AND completed_at IS NOT NULL
      AND completed_at = (SELECT completed_at FROM public.action_executions WHERE id = '70000000-0000-4000-8000-000000000194' AND tenant_id = v_tenant_id)
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key = 'fixture-profile-row-absent-in-progress'
      AND execution_id = '70000000-0000-4000-8000-000000000195'
      AND status = 'IN_PROGRESS'
      AND result IS NULL
      AND completed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'QA93 original idempotency status, execution, result or timestamp changed';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND actor_id = v_actor_id
    AND input = v_input
    AND (
      (id = '70000000-0000-4000-8000-000000000193'
        AND idempotency_key = 'fixture-profile-row-absent-completed'
        AND status = 'COMPLETED'
        AND object_id = '71000000-0000-4000-8000-000000000193'
        AND result = v_completed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000194'
        AND idempotency_key = 'fixture-profile-row-absent-failed'
        AND status = 'FAILED'
        AND object_id IS NULL
        AND result = v_failed_result
        AND completed_at IS NOT NULL)
      OR
      (id = '70000000-0000-4000-8000-000000000195'
        AND idempotency_key = 'fixture-profile-row-absent-in-progress'
        AND status = 'RUNNING'
        AND object_id IS NULL
        AND result IS NULL
        AND completed_at IS NULL)
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA93 original action executions, status or results changed';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = '71000000-0000-4000-8000-000000000193'
    AND name = 'Profile Row Absent Precedence Fixture Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = v_actor_id
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA93 original offer changed or duplicated';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = '70000000-0000-4000-8000-000000000193'
    AND tenant_id = v_tenant_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = v_actor_id
    AND object_id = '71000000-0000-4000-8000-000000000193'
    AND payload = v_completed_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA93 original ACTION_SUCCEEDED event changed or duplicated';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id IN (
    '70000000-0000-4000-8000-000000000193',
    '70000000-0000-4000-8000-000000000194',
    '70000000-0000-4000-8000-000000000195'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA93 missing profile row replays unexpectedly created or removed action events';
  END IF;

  IF (
    SELECT count(*)
    FROM public.profiles p
    JOIN pg_temp.qa93_profile_backup b ON b.id = p.id
    WHERE p.auth_user_id = '20000000-0000-4000-8000-000000000001'
      AND to_jsonb(p) IS NOT DISTINCT FROM to_jsonb(b)
  ) <> 1 THEN
    RAISE EXCEPTION 'QA93 provider A profile row was not restored exactly';
  END IF;
END
$qa93_integrity$;

COMMIT;

SELECT 'CREATE_OFFER missing profile row validation precedes idempotency hash/status handling for COMPLETED, FAILED and IN_PROGRESS keys (3 retries); profile row restored; original records unchanged' AS result;


-- OFFER-QA-94: prove that a constraint failure after the runtime has inserted
-- its execution and idempotency row rolls back every write from the function.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa94_atomicity$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa94-atomic-rollback-null-name';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_column text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA94 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) THEN
    RAISE EXCEPTION 'QA94 atomic rollback fixture key already exists';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa94-atomic-rollback-null-name"}'::jsonb,
      p_name => NULL::text,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA94 expected offers.name NOT NULL violation (SQLSTATE 23502)';
  EXCEPTION
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_column = COLUMN_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23502'
     OR v_table IS DISTINCT FROM 'offers'
     OR v_column IS DISTINCT FROM 'name' THEN
    RAISE EXCEPTION 'QA94 expected offers.name SQLSTATE 23502, received state %, table %, column %',
      v_sqlstate, v_table, v_column;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(
    v_before.idempotency_count,
    v_before.execution_count,
    v_before.offer_count,
    v_before.event_count
  ) IS DISTINCT FROM ROW(
    v_after.idempotency_count,
    v_after.execution_count,
    v_after.offer_count,
    v_after.event_count
  ) THEN
    RAISE EXCEPTION 'QA94 failed call left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) THEN
    RAISE EXCEPTION 'QA94 failed call left an idempotency key or action execution';
  END IF;
END
$qa94_atomicity$;

COMMIT;

SELECT 'CREATE_OFFER constraint failure on offers.name (SQLSTATE 23502) rolls back idempotency key, execution, offer and event writes' AS result;



-- OFFER-QA-95: prove that a CHECK constraint failure after the runtime has
-- inserted its execution and idempotency row rolls back every write.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa95_atomicity$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa95-atomic-rollback-check-name';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA95 requires authenticated provider A';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.offers'::regclass
      AND conname = 'fixture_force_rollback'
      AND contype = 'c'
      AND convalidated
      AND position('Fixture rollback failure' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA95 requires the validated fixture_force_rollback CHECK constraint on public.offers';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) THEN
    RAISE EXCEPTION 'QA95 atomic rollback fixture key already exists';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa95-atomic-rollback-check-name"}'::jsonb,
      p_name => 'Fixture rollback failure',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA95 expected offers.fixture_force_rollback CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'offers'
     OR v_constraint IS DISTINCT FROM 'fixture_force_rollback' THEN
    RAISE EXCEPTION 'QA95 expected offers.fixture_force_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(
    v_before.idempotency_count,
    v_before.execution_count,
    v_before.offer_count,
    v_before.event_count
  ) IS DISTINCT FROM ROW(
    v_after.idempotency_count,
    v_after.execution_count,
    v_after.offer_count,
    v_after.event_count
  ) THEN
    RAISE EXCEPTION 'QA95 failed call left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'Fixture rollback failure'
  ) THEN
    RAISE EXCEPTION 'QA95 failed call left an idempotency key, action execution or offer';
  END IF;
END
$qa95_atomicity$;

COMMIT;

SELECT 'CREATE_OFFER CHECK failure on offers.fixture_force_rollback (SQLSTATE 23514) rolls back idempotency key, execution, offer and event writes' AS result;


-- OFFER-QA-96: prove that a failure in the final ACTION_SUCCEEDED event
-- insert rolls back the already-created offer and completed execution state.
-- The NOT VALID constraint skips historical rows but rejects this new event.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

DO $qa96_constraint_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa96_force_event_rollback'
  ) THEN
    RAISE EXCEPTION 'QA96 temporary event constraint already exists';
  END IF;
END
$qa96_constraint_guard$;

ALTER TABLE public.action_events
  ADD CONSTRAINT qa96_force_event_rollback
  CHECK (event_type <> 'ACTION_SUCCEEDED') NOT VALID;

SET LOCAL ROLE authenticated;

DO $qa96_atomicity$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa96-atomic-rollback-action-event';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA96 requires authenticated provider A';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa96_force_event_rollback'
      AND contype = 'c'
      AND NOT convalidated
      AND position('ACTION_SUCCEEDED' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA96 requires the NOT VALID action_events CHECK constraint';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA96 Event Rollback Sentinel Offer'
  ) THEN
    RAISE EXCEPTION 'QA96 atomic rollback fixture data already exists';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa96-atomic-rollback-action-event"}'::jsonb,
      p_name => 'QA96 Event Rollback Sentinel Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA96 expected action_events.qa96_force_event_rollback CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'action_events'
     OR v_constraint IS DISTINCT FROM 'qa96_force_event_rollback' THEN
    RAISE EXCEPTION 'QA96 expected action_events.qa96_force_event_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(
    v_before.idempotency_count,
    v_before.execution_count,
    v_before.offer_count,
    v_before.event_count
  ) IS DISTINCT FROM ROW(
    v_after.idempotency_count,
    v_after.execution_count,
    v_after.offer_count,
    v_after.event_count
  ) THEN
    RAISE EXCEPTION 'QA96 final event failure left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA96 Event Rollback Sentinel Offer'
  ) THEN
    RAISE EXCEPTION 'QA96 final event failure left an idempotency key, execution or offer';
  END IF;
END
$qa96_atomicity$;

RESET ROLE;
ALTER TABLE public.action_events
  DROP CONSTRAINT qa96_force_event_rollback;

DO $qa96_constraint_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa96_force_event_rollback'
  ) THEN
    RAISE EXCEPTION 'QA96 temporary action_events constraint was not removed';
  END IF;
END
$qa96_constraint_cleanup$;

COMMIT;

SELECT 'CREATE_OFFER final ACTION_SUCCEEDED event failure on action_events (SQLSTATE 23514) rolls back idempotency key, execution, offer and event writes; temporary NOT VALID constraint removed' AS result;


-- OFFER-QA-97: a late event failure must roll back completely, after which
-- the same idempotency key and identical effective payload can succeed once.
-- A subsequent identical replay must return the persisted result without
-- creating another execution, offer or ACTION_SUCCEEDED event.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

DO $qa97_constraint_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa97_force_event_rollback'
  ) THEN
    RAISE EXCEPTION 'QA97 temporary event constraint already exists';
  END IF;
END
$qa97_constraint_guard$;

ALTER TABLE public.action_events
  ADD CONSTRAINT qa97_force_event_rollback
  CHECK (event_type <> 'ACTION_SUCCEEDED') NOT VALID;

SET LOCAL ROLE authenticated;

DO $qa97_failed_attempt$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa97-retry-after-late-rollback';
  v_name text := 'QA97 Retry After Late Rollback Offer';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA97 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA97 retry fixture data already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa97_force_event_rollback'
      AND contype = 'c'
      AND NOT convalidated
      AND position('ACTION_SUCCEEDED' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA97 requires the NOT VALID action_events CHECK constraint';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa97-retry-after-late-rollback"}'::jsonb,
      p_name => v_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA97 expected the final ACTION_SUCCEEDED event CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'action_events'
     OR v_constraint IS DISTINCT FROM 'qa97_force_event_rollback' THEN
    RAISE EXCEPTION 'QA97 expected action_events.qa97_force_event_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count)
     IS DISTINCT FROM
     ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count) THEN
    RAISE EXCEPTION 'QA97 failed attempt left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA97 failed attempt left an idempotency key, execution or offer';
  END IF;
END
$qa97_failed_attempt$;

RESET ROLE;
ALTER TABLE public.action_events
  DROP CONSTRAINT qa97_force_event_rollback;

DO $qa97_constraint_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa97_force_event_rollback'
  ) THEN
    RAISE EXCEPTION 'QA97 temporary action_events constraint was not removed';
  END IF;
END
$qa97_constraint_cleanup$;

SET LOCAL ROLE authenticated;

DO $qa97_retry_and_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa97-retry-after-late-rollback';
  v_name text := 'QA97 Retry After Late Rollback Offer';
  v_first_result jsonb;
  v_replay_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_before record;
  v_after_success record;
  v_after_replay record;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA97 retry requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_events'::regclass
      AND conname = 'qa97_force_event_rollback'
  ) THEN
    RAISE EXCEPTION 'QA97 retry must run after the temporary event constraint is removed';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  v_first_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => '{"case":"qa97-retry-after-late-rollback"}'::jsonb,
    p_name => v_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD'
  );

  IF v_first_result IS NULL
     OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_first_result->>'executionId', '') IS NULL
     OR nullif(v_first_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA97 retry after rollback did not return a complete succeeded result: %',
      coalesce(v_first_result::text, '<SQL NULL>');
  END IF;

  v_execution_id := (v_first_result->>'executionId')::uuid;
  v_offer_id := (v_first_result->>'objectId')::uuid;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after_success;

  IF ROW(
    v_after_success.idempotency_count,
    v_after_success.execution_count,
    v_after_success.offer_count,
    v_after_success.event_count
  ) IS DISTINCT FROM ROW(
    v_before.idempotency_count + 1,
    v_before.execution_count + 1,
    v_before.offer_count + 1,
    v_before.event_count + 1
  ) THEN
    RAISE EXCEPTION 'QA97 successful retry must add exactly one key, execution, offer and event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 expected exactly one COMPLETED idempotency key with the returned result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND id = v_execution_id
    AND idempotency_key = v_key
    AND actor_id = v_actor_id
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 expected exactly one COMPLETED action execution matching the returned result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = v_name
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = v_actor_id
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 expected exactly one offer matching the successful retry result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = v_tenant_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = v_actor_id
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 expected exactly one ACTION_SUCCEEDED event matching the successful retry result, found %', v_count;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => '{"case":"qa97-retry-after-late-rollback"}'::jsonb,
    p_name => v_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD'
  );

  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA97 identical replay must return the exact persisted result; first %, replay %',
      v_first_result, v_replay_result;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after_replay;

  IF ROW(
    v_after_replay.idempotency_count,
    v_after_replay.execution_count,
    v_after_replay.offer_count,
    v_after_replay.event_count
  ) IS DISTINCT FROM ROW(
    v_after_success.idempotency_count,
    v_after_success.execution_count,
    v_after_success.offer_count,
    v_after_success.event_count
  ) THEN
    RAISE EXCEPTION 'QA97 identical replay created or removed rows';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 idempotency key was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND idempotency_key = v_key
    AND id = v_execution_id
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 action execution was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id AND name = v_name;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 offer was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA97 ACTION_SUCCEEDED event was not unique after replay';
  END IF;
END
$qa97_retry_and_replay$;

COMMIT;

SELECT 'CREATE_OFFER late event failure rolls back fully; same key and identical payload then succeed once; identical replay returns the persisted result without duplicates' AS result;


-- OFFER-QA-98: a failed final idempotency completion update must roll back
-- the execution and offer that were created earlier in the same function call.
BEGIN;

DO $qa98_constraint_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa98_force_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA98 temporary idempotency constraint already exists';
  END IF;
END
$qa98_constraint_guard$;

ALTER TABLE public.idempotency_keys
  ADD CONSTRAINT qa98_force_completion_rollback
  CHECK (status <> 'COMPLETED') NOT VALID;

SET LOCAL ROLE authenticated;

DO $qa98_completion_failure$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa98-idempotency-completion-rollback';
  v_name text := 'QA98 Idempotency Completion Rollback Offer';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA98 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1
    FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA98 fixture data already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa98_force_completion_rollback'
      AND contype = 'c'
      AND NOT convalidated
      AND position('COMPLETED' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA98 requires the NOT VALID idempotency_keys completion CHECK constraint';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa98-idempotency-completion-rollback"}'::jsonb,
      p_name => v_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => v_actor_id,
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA98 expected the idempotency_keys completion CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'idempotency_keys'
     OR v_constraint IS DISTINCT FROM 'qa98_force_completion_rollback' THEN
    RAISE EXCEPTION 'QA98 expected idempotency_keys.qa98_force_completion_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count)
     IS DISTINCT FROM
     ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count) THEN
    RAISE EXCEPTION 'QA98 failed completion update left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) OR EXISTS (
    SELECT 1
    FROM public.action_events e
    JOIN public.action_executions x
      ON x.id = e.execution_id
     AND x.tenant_id = e.tenant_id
    WHERE x.tenant_id = v_tenant_id
      AND x.idempotency_key = v_key
  ) THEN
    RAISE EXCEPTION 'QA98 failed completion update left an idempotency key, execution, offer or event';
  END IF;
END
$qa98_completion_failure$;

RESET ROLE;
ALTER TABLE public.idempotency_keys
  DROP CONSTRAINT qa98_force_completion_rollback;

DO $qa98_constraint_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa98_force_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA98 temporary idempotency_keys constraint was not removed';
  END IF;
END
$qa98_constraint_cleanup$;

COMMIT;

SELECT 'CREATE_OFFER idempotency_keys COMPLETED update failure (SQLSTATE 23514) rolls back key, execution, offer and event writes' AS result;

-- OFFER-QA-99: a failed action execution completion update must roll back
-- the key, offer and event writes performed earlier in the same call.
BEGIN;

DO $qa99_constraint_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa99_force_execution_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA99 temporary action_executions constraint already exists';
  END IF;
END
$qa99_constraint_guard$;

ALTER TABLE public.action_executions
  ADD CONSTRAINT qa99_force_execution_completion_rollback
  CHECK (status <> 'COMPLETED') NOT VALID;

SET LOCAL ROLE authenticated;

DO $qa99_execution_failure$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa99-action-execution-completion-rollback';
  v_name text := 'QA99 Action Execution Completion Rollback Offer';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA99 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1
    FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA99 fixture data already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa99_force_execution_completion_rollback'
      AND contype = 'c'
      AND NOT convalidated
      AND position('COMPLETED' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA99 requires the NOT VALID action_executions completion CHECK constraint';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa99-action-execution-completion-rollback"}'::jsonb,
      p_name => v_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => v_actor_id,
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA99 expected the action_executions completion CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'action_executions'
     OR v_constraint IS DISTINCT FROM 'qa99_force_execution_completion_rollback' THEN
    RAISE EXCEPTION 'QA99 expected action_executions.qa99_force_execution_completion_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count)
     IS DISTINCT FROM
     ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count) THEN
    RAISE EXCEPTION 'QA99 failed execution completion update left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) OR EXISTS (
    SELECT 1
    FROM public.action_events e
    JOIN public.action_executions x
      ON x.id = e.execution_id
     AND x.tenant_id = e.tenant_id
    WHERE x.tenant_id = v_tenant_id
      AND x.idempotency_key = v_key
  ) THEN
    RAISE EXCEPTION 'QA99 failed execution completion update left an idempotency key, execution, offer or event';
  END IF;
END
$qa99_execution_failure$;

RESET ROLE;
ALTER TABLE public.action_executions
  DROP CONSTRAINT qa99_force_execution_completion_rollback;

DO $qa99_constraint_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa99_force_execution_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA99 temporary action_executions constraint was not removed';
  END IF;
END
$qa99_constraint_cleanup$;

COMMIT;

SELECT 'CREATE_OFFER action_executions COMPLETED update failure (SQLSTATE 23514) rolls back key, execution, offer and event writes' AS result;


-- OFFER-QA-100: an execution completion failure must roll back completely, after which
-- the same idempotency key and identical effective payload can succeed once.
-- A subsequent identical replay must return the persisted result without
-- creating another execution, offer or ACTION_SUCCEEDED event.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

DO $qa100_constraint_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa100_force_execution_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA100 temporary execution constraint already exists';
  END IF;
END
$qa100_constraint_guard$;

ALTER TABLE public.action_executions
  ADD CONSTRAINT qa100_force_execution_completion_rollback
  CHECK (status <> 'COMPLETED') NOT VALID;

SET LOCAL ROLE authenticated;

DO $qa100_failed_attempt$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa100-retry-after-execution-completion-rollback';
  v_name text := 'QA100 Retry After Execution Completion Rollback Offer';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA100 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA100 retry fixture data already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa100_force_execution_completion_rollback'
      AND contype = 'c'
      AND NOT convalidated
      AND position('COMPLETED' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA100 requires the NOT VALID action_executions CHECK constraint';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa100-retry-after-execution-completion-rollback"}'::jsonb,
      p_name => v_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA100 expected the action_executions COMPLETED CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'action_executions'
     OR v_constraint IS DISTINCT FROM 'qa100_force_execution_completion_rollback' THEN
    RAISE EXCEPTION 'QA100 expected action_executions.qa100_force_execution_completion_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count)
     IS DISTINCT FROM
     ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count) THEN
    RAISE EXCEPTION 'QA100 failed attempt left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA100 failed attempt left an idempotency key, execution or offer';
  END IF;
END
$qa100_failed_attempt$;

RESET ROLE;
ALTER TABLE public.action_executions
  DROP CONSTRAINT qa100_force_execution_completion_rollback;

DO $qa100_constraint_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa100_force_execution_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA100 temporary action_executions constraint was not removed';
  END IF;
END
$qa100_constraint_cleanup$;

SET LOCAL ROLE authenticated;

DO $qa100_retry_and_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa100-retry-after-execution-completion-rollback';
  v_name text := 'QA100 Retry After Execution Completion Rollback Offer';
  v_first_result jsonb;
  v_replay_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_before record;
  v_after_success record;
  v_after_replay record;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA100 retry requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.action_executions'::regclass
      AND conname = 'qa100_force_execution_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA100 retry must run after the temporary execution constraint is removed';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  v_first_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => '{"case":"qa100-retry-after-execution-completion-rollback"}'::jsonb,
    p_name => v_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD'
  );

  IF v_first_result IS NULL
     OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_first_result->>'executionId', '') IS NULL
     OR nullif(v_first_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA100 retry after rollback did not return a complete succeeded result: %',
      coalesce(v_first_result::text, '<SQL NULL>');
  END IF;

  v_execution_id := (v_first_result->>'executionId')::uuid;
  v_offer_id := (v_first_result->>'objectId')::uuid;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after_success;

  IF ROW(
    v_after_success.idempotency_count,
    v_after_success.execution_count,
    v_after_success.offer_count,
    v_after_success.event_count
  ) IS DISTINCT FROM ROW(
    v_before.idempotency_count + 1,
    v_before.execution_count + 1,
    v_before.offer_count + 1,
    v_before.event_count + 1
  ) THEN
    RAISE EXCEPTION 'QA100 successful retry must add exactly one key, execution, offer and event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 expected exactly one COMPLETED idempotency key with the returned result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND id = v_execution_id
    AND idempotency_key = v_key
    AND actor_id = v_actor_id
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 expected exactly one COMPLETED action execution matching the returned result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = v_name
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = v_actor_id
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 expected exactly one offer matching the successful retry result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = v_tenant_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = v_actor_id
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 expected exactly one ACTION_SUCCEEDED event matching the successful retry result, found %', v_count;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => '{"case":"qa100-retry-after-execution-completion-rollback"}'::jsonb,
    p_name => v_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD'
  );

  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA100 identical replay must return the exact persisted result; first %, replay %',
      v_first_result, v_replay_result;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after_replay;

  IF ROW(
    v_after_replay.idempotency_count,
    v_after_replay.execution_count,
    v_after_replay.offer_count,
    v_after_replay.event_count
  ) IS DISTINCT FROM ROW(
    v_after_success.idempotency_count,
    v_after_success.execution_count,
    v_after_success.offer_count,
    v_after_success.event_count
  ) THEN
    RAISE EXCEPTION 'QA100 identical replay created or removed rows';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 idempotency key was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND idempotency_key = v_key
    AND id = v_execution_id
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 action execution was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id AND name = v_name;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 offer was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA100 ACTION_SUCCEEDED event was not unique after replay';
  END IF;
END
$qa100_retry_and_replay$;

COMMIT;

SELECT 'CREATE_OFFER execution completion failure rolls back fully; same key and identical payload then succeed once; identical replay returns the persisted result without duplicates' AS result;




-- OFFER-QA-101: an idempotency completion failure must roll back the offer and
-- execution too; after removing the temporary constraint, the same key/payload
-- must succeed once and an identical replay must not create duplicates.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';

DO $qa101_constraint_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa101_force_idempotency_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA101 temporary idempotency constraint already exists';
  END IF;
END
$qa101_constraint_guard$;

ALTER TABLE public.idempotency_keys
  ADD CONSTRAINT qa101_force_idempotency_completion_rollback
  CHECK (status <> 'COMPLETED') NOT VALID;

SET LOCAL ROLE authenticated;

DO $qa101_failed_attempt$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa101-retry-after-idempotency-completion-rollback';
  v_name text := 'QA101 Retry After Idempotency Completion Rollback Offer';
  v_before record;
  v_after record;
  v_sqlstate text;
  v_table text;
  v_constraint text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA101 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA101 retry fixture data already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa101_force_idempotency_completion_rollback'
      AND contype = 'c'
      AND NOT convalidated
      AND position('COMPLETED' IN pg_get_constraintdef(oid)) > 0
  ) THEN
    RAISE EXCEPTION 'QA101 requires the NOT VALID idempotency_keys CHECK constraint';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => '{"case":"qa101-retry-after-idempotency-completion-rollback"}'::jsonb,
      p_name => v_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD'
    );

    RAISE EXCEPTION 'QA101 expected the idempotency_keys COMPLETED CHECK violation (SQLSTATE 23514)';
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS
        v_sqlstate = RETURNED_SQLSTATE,
        v_table = TABLE_NAME,
        v_constraint = CONSTRAINT_NAME;
  END;

  IF v_sqlstate IS DISTINCT FROM '23514'
     OR v_table IS DISTINCT FROM 'idempotency_keys'
     OR v_constraint IS DISTINCT FROM 'qa101_force_idempotency_completion_rollback' THEN
    RAISE EXCEPTION 'QA101 expected idempotency_keys.qa101_force_idempotency_completion_rollback SQLSTATE 23514, received state %, table %, constraint %',
      v_sqlstate, v_table, v_constraint;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after;

  IF ROW(v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count)
     IS DISTINCT FROM
     ROW(v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count) THEN
    RAISE EXCEPTION 'QA101 failed idempotency completion update left partial writes (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA101 failed attempt left an idempotency key, execution or offer';
  END IF;
END
$qa101_failed_attempt$;

RESET ROLE;
ALTER TABLE public.idempotency_keys
  DROP CONSTRAINT qa101_force_idempotency_completion_rollback;

DO $qa101_constraint_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa101_force_idempotency_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA101 temporary idempotency_keys constraint was not removed';
  END IF;
END
$qa101_constraint_cleanup$;

SET LOCAL ROLE authenticated;

DO $qa101_retry_and_replay$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa101-retry-after-idempotency-completion-rollback';
  v_name text := 'QA101 Retry After Idempotency Completion Rollback Offer';
  v_first_result jsonb;
  v_replay_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_before record;
  v_after_success record;
  v_after_replay record;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA101 retry requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.idempotency_keys'::regclass
      AND conname = 'qa101_force_idempotency_completion_rollback'
  ) THEN
    RAISE EXCEPTION 'QA101 retry must run after the temporary idempotency constraint is removed';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  v_first_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => '{"case":"qa101-retry-after-idempotency-completion-rollback"}'::jsonb,
    p_name => v_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD'
  );

  IF v_first_result IS NULL
     OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_first_result->>'executionId', '') IS NULL
     OR nullif(v_first_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA101 retry after rollback did not return a complete succeeded result: %',
      coalesce(v_first_result::text, '<SQL NULL>');
  END IF;

  v_execution_id := (v_first_result->>'executionId')::uuid;
  v_offer_id := (v_first_result->>'objectId')::uuid;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after_success;

  IF ROW(
    v_after_success.idempotency_count,
    v_after_success.execution_count,
    v_after_success.offer_count,
    v_after_success.event_count
  ) IS DISTINCT FROM ROW(
    v_before.idempotency_count + 1,
    v_before.execution_count + 1,
    v_before.offer_count + 1,
    v_before.event_count + 1
  ) THEN
    RAISE EXCEPTION 'QA101 successful retry must add exactly one key, execution, offer and event';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 expected exactly one COMPLETED idempotency key with the returned result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND id = v_execution_id
    AND idempotency_key = v_key
    AND actor_id = v_actor_id
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 expected exactly one COMPLETED action execution matching the returned result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = v_name
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = v_actor_id
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 expected exactly one offer matching the successful retry result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = v_tenant_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = v_actor_id
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 expected exactly one ACTION_SUCCEEDED event matching the successful retry result, found %', v_count;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => '{"case":"qa101-retry-after-idempotency-completion-rollback"}'::jsonb,
    p_name => v_name,
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD'
  );

  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA101 identical replay must return the exact persisted result; first %, replay %',
      v_first_result, v_replay_result;
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_after_replay;

  IF ROW(
    v_after_replay.idempotency_count,
    v_after_replay.execution_count,
    v_after_replay.offer_count,
    v_after_replay.event_count
  ) IS DISTINCT FROM ROW(
    v_after_success.idempotency_count,
    v_after_success.execution_count,
    v_after_success.offer_count,
    v_after_success.event_count
  ) THEN
    RAISE EXCEPTION 'QA101 identical replay created or removed rows';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 idempotency key was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND idempotency_key = v_key
    AND id = v_execution_id
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 action execution was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id AND name = v_name;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 offer was not unique after replay';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA101 ACTION_SUCCEEDED event was not unique after replay';
  END IF;
END
$qa101_retry_and_replay$;

COMMIT;

SELECT 'CREATE_OFFER idempotency completion failure rolls back fully; same key and identical payload then succeed once; identical replay returns the persisted result without duplicates' AS result;


-- OFFER-QA-286: empty optional business strings must replay exactly once;
-- changing one of those values to SQL/JSON NULL with the same key must be rejected.
-- This runs only against the disposable PostgreSQL integration fixture.
BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa286$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_actor_id uuid := '30000000-0000-4000-8000-000000000001';
  v_key text := 'fixture-qa286-empty-optional-strings-replay';
  v_name text := 'QA286 Empty Optional Strings Replay Offer';
  v_demand_id uuid := '50000000-0000-4000-8000-000000000001';
  v_product_master_id uuid := '40000000-0000-4000-8000-000000000001';
  v_input jsonb := '{
    "case":"qa286-empty-optional-strings-replay",
    "conditions":"",
    "market":"",
    "geography":"",
    "documentationStatus":""
  }'::jsonb;
  v_changed_input jsonb;
  v_expected_hash text;
  v_first_result jsonb;
  v_replay_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_error text;
  v_count integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA286 requires authenticated provider A';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
  ) OR EXISTS (
    SELECT 1 FROM public.offers WHERE name = v_name
  ) THEN
    RAISE EXCEPTION 'QA286 fixture data already exists';
  END IF;

  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', v_name,
    'demandId', v_demand_id,
    'productMasterId', v_product_master_id,
    'providerActorId', v_actor_id,
    'quantity', 2::numeric,
    'price', 12::numeric,
    'currency', 'USD',
    'conditions', '',
    'market', '',
    'geography', '',
    'attributes', '{}'::jsonb,
    'documentationStatus', '',
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  v_first_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_name,
    p_demand_id => v_demand_id,
    p_product_master_id => v_product_master_id,
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD',
    p_conditions => '',
    p_market => '',
    p_geography => '',
    p_attributes => '{}'::jsonb,
    p_documentation_status => ''
  );

  IF v_first_result IS NULL
     OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_first_result->>'executionId', '') IS NULL
     OR nullif(v_first_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA286 initial empty-string request did not return a complete success result: %',
      coalesce(v_first_result::text, '<SQL NULL>');
  END IF;

  v_execution_id := (v_first_result->>'executionId')::uuid;
  v_offer_id := (v_first_result->>'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id
    AND key = v_key
    AND status = 'COMPLETED'
    AND request_hash = v_expected_hash
    AND execution_id = v_execution_id
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected exactly one completed idempotency row with the exact empty-string hash, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id
    AND id = v_execution_id
    AND idempotency_key = v_key
    AND actor_id = v_actor_id
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND input = v_input
    AND result = v_first_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected exactly one completed execution preserving the input and result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = v_name
    AND demand_id = v_demand_id
    AND product_master_id = v_product_master_id
    AND provider_actor_id = v_actor_id
    AND quantity = 2
    AND price = 12
    AND currency = 'USD'
    AND conditions = ''
    AND market = ''
    AND geography = ''
    AND documentation_status = ''
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected exactly one offer preserving all four empty optional strings, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = v_actor_id
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_first_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected exactly one ACTION_SUCCEEDED event, found %', v_count;
  END IF;

  -- An exact replay of the four empty strings must return the persisted result.
  v_replay_result := public.execute_create_offer_v1(
    p_tenant_id => v_tenant_id,
    p_idempotency_key => v_key,
    p_input => v_input,
    p_name => v_name,
    p_demand_id => v_demand_id,
    p_product_master_id => v_product_master_id,
    p_provider_actor_id => v_actor_id,
    p_quantity => 2,
    p_price => 12,
    p_currency => 'USD',
    p_conditions => '',
    p_market => '',
    p_geography => '',
    p_attributes => '{}'::jsonb,
    p_documentation_status => ''
  );

  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA286 identical empty-string replay did not return the exact persisted result';
  END IF;

  -- Change one optional field from empty text to SQL NULL and its JSON input
  -- value to JSON null. The same idempotency key must not replay the old result.
  v_changed_input := jsonb_set(v_input, '{conditions}', 'null'::jsonb);
  v_error := NULL;
  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => v_changed_input,
      p_name => v_name,
      p_demand_id => v_demand_id,
      p_product_master_id => v_product_master_id,
      p_provider_actor_id => v_actor_id,
      p_quantity => 2,
      p_price => 12,
      p_currency => 'USD',
      p_conditions => NULL,
      p_market => '',
      p_geography => '',
      p_attributes => '{}'::jsonb,
      p_documentation_status => ''
    );
    RAISE EXCEPTION 'QA286 expected changing conditions from empty text to NULL to be rejected';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
  END;

  IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN
    RAISE EXCEPTION 'QA286 changed empty-to-NULL request must raise IDEMPOTENCY_KEY_REUSE; got %',
      coalesce(v_error, '<no error>');
  END IF;

  -- Neither the exact replay nor the rejected changed request may add rows.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = v_tenant_id AND key = v_key;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected one idempotency row after replay and rejection, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = v_tenant_id AND idempotency_key = v_key;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected one execution after replay and rejection, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id AND name = v_name;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected one offer after replay and rejection, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = v_tenant_id
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA286 expected one success event after replay and rejection, found %', v_count;
  END IF;

  RAISE NOTICE 'QA286 four empty optional strings succeeded and exactly replayed once; changing conditions to NULL with the same key raised IDEMPOTENCY_KEY_REUSE without duplicates';
END
$qa286$;

COMMIT;

SELECT 'QA286 exact replay of four empty optional strings returns one persisted result; changing conditions to NULL with the same key is rejected without duplicate rows' AS result;
