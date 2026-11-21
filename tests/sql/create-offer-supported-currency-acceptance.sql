\set ON_ERROR_STOP on

BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa423_supported_currency_acceptance$
DECLARE
  v_case record;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text;
  v_input jsonb;
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
  v_execution_result jsonb;
  v_execution_object_id uuid;
  v_stored_currency text;
  v_event_payload jsonb;
  v_event_object_id uuid;
  v_event_object_type text;
  v_after_first record;
  v_after_replay record;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA423 requires authenticated provider A';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('USD'::text, 'QA423 USD Supported Currency Offer'::text),
      ('EUR'::text, 'QA423 EUR Supported Currency Offer'::text),
      ('KRW'::text, 'QA423 KRW Supported Currency Offer'::text),
      ('MAD'::text, 'QA423 MAD Supported Currency Offer'::text),
      ('CNY'::text, 'QA423 CNY Supported Currency Offer'::text)
    ) AS cases(currency_code, offer_name)
  LOOP
    v_key := 'fixture-qa423-supported-currency-' || lower(v_case.currency_code);
    v_input := jsonb_build_object(
      'case', 'qa423_supported_currency_acceptance',
      'currency', v_case.currency_code
    );

    IF EXISTS (
      SELECT 1 FROM public.idempotency_keys
      WHERE tenant_id = v_tenant_id AND key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.action_executions
      WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.offers WHERE name = v_case.offer_name
    ) THEN
      RAISE EXCEPTION 'QA423 fixture data already exists for currency %', v_case.currency_code;
    END IF;

    v_first_result := public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => v_input,
      p_name => v_case.offer_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2::numeric,
      p_price => 10::numeric,
      p_currency => v_case.currency_code,
      p_conditions => NULL::text,
      p_market => 'fixture-market-stable',
      p_geography => NULL::text,
      p_attributes => '{}'::jsonb,
      p_documentation_status => NULL::text,
      p_lifecycle => NULL::text,
      p_offer_type => 'fixture-offer-type-stable',
      p_pricing_model => 'fixture-pricing-model-stable'
    );

    IF jsonb_typeof(v_first_result) IS DISTINCT FROM 'object'
       OR v_first_result->>'status' IS DISTINCT FROM 'succeeded'
       OR v_first_result->>'objectType' IS DISTINCT FROM 'Offer'
       OR nullif(v_first_result->>'executionId', '') IS NULL
       OR nullif(v_first_result->>'objectId', '') IS NULL THEN
      RAISE EXCEPTION 'QA423 % did not return a complete success result: %',
        v_case.currency_code, coalesce(v_first_result::text, '<SQL NULL>');
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
      RAISE EXCEPTION 'QA423 % initial idempotency record does not match the success result',
        v_case.currency_code;
    END IF;

    SELECT status, result, object_id
    INTO v_execution_status, v_execution_result, v_execution_object_id
    FROM public.action_executions
    WHERE tenant_id = v_tenant_id
      AND idempotency_key = v_key
      AND id = v_execution_id;
    IF NOT FOUND
       OR v_execution_status IS DISTINCT FROM 'COMPLETED'
       OR v_execution_result IS DISTINCT FROM v_first_result
       OR v_execution_object_id IS DISTINCT FROM v_offer_id THEN
      RAISE EXCEPTION 'QA423 % initial action execution does not match the success result',
        v_case.currency_code;
    END IF;

    SELECT currency INTO v_stored_currency
    FROM public.offers
    WHERE id = v_offer_id AND name = v_case.offer_name;
    IF NOT FOUND OR v_stored_currency IS DISTINCT FROM v_case.currency_code THEN
      RAISE EXCEPTION 'QA423 % was not persisted with its exact currency code; received %',
        v_case.currency_code, coalesce(v_stored_currency, '<missing>');
    END IF;

    SELECT payload, object_id, object_type
    INTO v_event_payload, v_event_object_id, v_event_object_type
    FROM public.action_events
    WHERE tenant_id = v_tenant_id
      AND execution_id = v_execution_id
      AND event_type = 'ACTION_SUCCEEDED';
    IF NOT FOUND
       OR v_event_payload IS DISTINCT FROM v_first_result
       OR v_event_object_id IS DISTINCT FROM v_offer_id
       OR v_event_object_type IS DISTINCT FROM 'Offer' THEN
      RAISE EXCEPTION 'QA423 % success event does not match the persisted offer result',
        v_case.currency_code;
    END IF;

    SELECT
      (SELECT count(*)::integer FROM public.idempotency_keys WHERE tenant_id = v_tenant_id AND key = v_key) AS idempotency_count,
      (SELECT count(*)::integer FROM public.action_executions WHERE tenant_id = v_tenant_id AND idempotency_key = v_key) AS execution_count,
      (SELECT count(*)::integer FROM public.offers WHERE id = v_offer_id) AS offer_count,
      (SELECT count(*)::integer FROM public.action_events WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED') AS event_count
    INTO v_after_first;
    IF ROW(
      v_after_first.idempotency_count,
      v_after_first.execution_count,
      v_after_first.offer_count,
      v_after_first.event_count
    ) IS DISTINCT FROM ROW(1, 1, 1, 1) THEN
      RAISE EXCEPTION 'QA423 % did not create exactly one idempotency row, execution, offer and success event',
        v_case.currency_code;
    END IF;

    v_replay_result := public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => v_key,
      p_input => v_input,
      p_name => v_case.offer_name,
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2::numeric,
      p_price => 10::numeric,
      p_currency => v_case.currency_code,
      p_conditions => NULL::text,
      p_market => 'fixture-market-stable',
      p_geography => NULL::text,
      p_attributes => '{}'::jsonb,
      p_documentation_status => NULL::text,
      p_lifecycle => NULL::text,
      p_offer_type => 'fixture-offer-type-stable',
      p_pricing_model => 'fixture-pricing-model-stable'
    );

    IF v_replay_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'QA423 % exact replay did not return the original JSON result',
        v_case.currency_code;
    END IF;

    SELECT request_hash INTO v_replay_hash
    FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id AND key = v_key;
    IF NOT FOUND OR v_replay_hash IS DISTINCT FROM v_original_hash THEN
      RAISE EXCEPTION 'QA423 % exact replay changed the original request hash',
        v_case.currency_code;
    END IF;

    SELECT
      (SELECT count(*)::integer FROM public.idempotency_keys WHERE tenant_id = v_tenant_id AND key = v_key) AS idempotency_count,
      (SELECT count(*)::integer FROM public.action_executions WHERE tenant_id = v_tenant_id AND idempotency_key = v_key) AS execution_count,
      (SELECT count(*)::integer FROM public.offers WHERE id = v_offer_id) AS offer_count,
      (SELECT count(*)::integer FROM public.action_events WHERE tenant_id = v_tenant_id AND execution_id = v_execution_id AND event_type = 'ACTION_SUCCEEDED') AS event_count
    INTO v_after_replay;
    IF ROW(
      v_after_replay.idempotency_count,
      v_after_replay.execution_count,
      v_after_replay.offer_count,
      v_after_replay.event_count
    ) IS DISTINCT FROM ROW(
      v_after_first.idempotency_count,
      v_after_first.execution_count,
      v_after_first.offer_count,
      v_after_first.event_count
    ) THEN
      RAISE EXCEPTION 'QA423 % exact replay created duplicate persisted rows',
        v_case.currency_code;
    END IF;
  END LOOP;

  RAISE NOTICE 'QA423 PASS: USD, EUR, KRW, MAD and CNY are accepted, persisted exactly and replayed without duplicate rows';
END
$qa423_supported_currency_acceptance$;

RESET ROLE;
COMMIT;
