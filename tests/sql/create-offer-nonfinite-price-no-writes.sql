\set ON_ERROR_STOP on

BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa424_nonfinite_price_no_writes$
DECLARE
  v_case record;
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_key text;
  v_before record;
  v_after record;
  v_error text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA424 requires authenticated provider A';
  END IF;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('nan-price'::text, 'NaN'::numeric, 'QA424 NaN Price Rejection Offer'::text),
      ('negative-infinity-price'::text, '-Infinity'::numeric, 'QA424 Negative Infinity Price Rejection Offer'::text)
    ) AS cases(case_key, price_value, offer_name)
  LOOP
    v_key := 'fixture-qa424-' || v_case.case_key;

    IF EXISTS (
      SELECT 1 FROM public.idempotency_keys
      WHERE tenant_id = v_tenant_id AND key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.action_executions
      WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.offers WHERE name = v_case.offer_name
    ) THEN
      RAISE EXCEPTION 'QA424 fixture data already exists for %', v_case.case_key;
    END IF;

    SELECT
      (SELECT count(*)::integer FROM public.idempotency_keys) AS idempotency_count,
      (SELECT count(*)::integer FROM public.action_executions) AS execution_count,
      (SELECT count(*)::integer FROM public.offers) AS offer_count,
      (SELECT count(*)::integer FROM public.action_events) AS event_count
    INTO v_before;

    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => v_tenant_id,
        p_idempotency_key => v_key,
        p_input => jsonb_build_object('case', 'qa424_nonfinite_price', 'value', v_case.case_key),
        p_name => v_case.offer_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 1::numeric,
        p_price => v_case.price_value,
        p_currency => 'USD'
      );
      RAISE EXCEPTION 'QA424 expected INVALID_PRICE for %', v_case.case_key;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'INVALID_PRICE' THEN
      RAISE EXCEPTION 'QA424 % expected INVALID_PRICE, received %',
        v_case.case_key, coalesce(v_error, '<no error>');
    END IF;

    SELECT
      (SELECT count(*)::integer FROM public.idempotency_keys) AS idempotency_count,
      (SELECT count(*)::integer FROM public.action_executions) AS execution_count,
      (SELECT count(*)::integer FROM public.offers) AS offer_count,
      (SELECT count(*)::integer FROM public.action_events) AS event_count
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
      RAISE EXCEPTION 'QA424 % changed one or more persistence table counts', v_case.case_key;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.idempotency_keys
      WHERE tenant_id = v_tenant_id AND key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.action_executions
      WHERE tenant_id = v_tenant_id AND idempotency_key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.offers WHERE name = v_case.offer_name
    ) OR EXISTS (
      SELECT 1
      FROM public.action_events e
      JOIN public.action_executions x ON x.id = e.execution_id
      WHERE x.tenant_id = v_tenant_id
        AND x.idempotency_key = v_key
    ) THEN
      RAISE EXCEPTION 'QA424 % left a key, execution, offer or event sentinel', v_case.case_key;
    END IF;
  END LOOP;

  RAISE NOTICE 'QA424 PASS: NaN and negative Infinity prices are rejected as INVALID_PRICE without writes to idempotency_keys, action_executions, offers or action_events';
END
$qa424_nonfinite_price_no_writes$;

RESET ROLE;
COMMIT;
