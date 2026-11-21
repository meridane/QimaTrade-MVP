\set ON_ERROR_STOP on

BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa422_currency_rejection_no_writes$
DECLARE
  v_case record;
  v_key text;
  v_error text;
  v_before record;
  v_after record;
BEGIN
  IF auth.uid() IS DISTINCT FROM '20000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA422 requires authenticated provider A';
  END IF;

  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  FOR v_case IN
    SELECT *
    FROM (VALUES
      ('unsupported', 'XYZ'::text, 'QA422 Unsupported Currency Offer'::text),
      ('null', NULL::text, 'QA422 NULL Currency Offer'::text),
      ('blank', '   '::text, 'QA422 Blank Currency Offer'::text),
      ('padded', ' USD '::text, 'QA422 Padded Currency Offer'::text),
      ('lowercase', 'usd'::text, 'QA422 Lowercase Currency Offer'::text)
    ) AS cases(case_key, currency_value, offer_name)
  LOOP
    v_key := 'fixture-qa422-currency-' || v_case.case_key;

    IF EXISTS (
      SELECT 1 FROM public.idempotency_keys
      WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
        AND key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.action_executions
      WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
        AND idempotency_key = v_key
    ) OR EXISTS (
      SELECT 1 FROM public.offers
      WHERE name = v_case.offer_name
    ) THEN
      RAISE EXCEPTION 'QA422 fixture data already exists for %', v_case.case_key;
    END IF;

    v_error := NULL;
    BEGIN
      PERFORM public.execute_create_offer_v1(
        p_tenant_id => '10000000-0000-4000-8000-000000000001',
        p_idempotency_key => v_key,
        p_input => jsonb_build_object('case', 'qa422_currency_rejection', 'variant', v_case.case_key),
        p_name => v_case.offer_name,
        p_demand_id => '50000000-0000-4000-8000-000000000001',
        p_product_master_id => '40000000-0000-4000-8000-000000000001',
        p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
        p_quantity => 2::numeric,
        p_price => 10::numeric,
        p_currency => v_case.currency_value
      );
      RAISE EXCEPTION 'QA422 expected INVALID_CURRENCY for %', v_case.case_key;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    END;

    IF v_error IS DISTINCT FROM 'INVALID_CURRENCY' THEN
      RAISE EXCEPTION 'QA422 % expected INVALID_CURRENCY, received %',
        v_case.case_key, coalesce(v_error, '<no error>');
    END IF;
  END LOOP;

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
    RAISE EXCEPTION 'QA422 invalid-currency calls changed persistence counts';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key LIKE 'fixture-qa422-currency-%'
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND idempotency_key LIKE 'fixture-qa422-currency-%'
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE name LIKE 'QA422 % Currency Offer'
  ) OR EXISTS (
    SELECT 1
    FROM public.action_events e
    JOIN public.action_executions x ON x.id = e.execution_id
    WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND x.idempotency_key LIKE 'fixture-qa422-currency-%'
  ) THEN
    RAISE EXCEPTION 'QA422 invalid-currency rejection left a key, execution, offer or event';
  END IF;

  RAISE NOTICE 'QA422 PASS: unsupported, NULL, blank, padded and lowercase currencies are rejected before all four persistence tables change';
END
$qa422_currency_rejection_no_writes$;

RESET ROLE;
COMMIT;
