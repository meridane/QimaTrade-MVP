\set ON_ERROR_STOP on

BEGIN;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa421_pre_persistence_rejection$
DECLARE
  v_tenant_id uuid := '10000000-0000-4000-8000-000000000001';
  v_before record;
  v_after record;
  v_message text;
BEGIN
  SELECT
    (SELECT count(*) FROM public.idempotency_keys) AS idempotency_count,
    (SELECT count(*) FROM public.action_executions) AS execution_count,
    (SELECT count(*) FROM public.offers) AS offer_count,
    (SELECT count(*) FROM public.action_events) AS event_count
  INTO v_before;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => 'qa421-provider-actor-mismatch',
      p_input => '{"case":"qa421-provider-actor-mismatch"}'::jsonb,
      p_name => 'QA421 Provider Actor Rejection',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000002',
      p_quantity => 2,
      p_price => 10,
      p_currency => 'USD'
    );
    RAISE EXCEPTION 'QA421 provider actor rejection sentinel';
  EXCEPTION WHEN OTHERS THEN
    v_message := SQLERRM;
    IF v_message IS DISTINCT FROM 'INVALID_PROVIDER_ACTOR' THEN
      RAISE EXCEPTION 'QA421 expected INVALID_PROVIDER_ACTOR, received %', v_message;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => 'qa421-invalid-quantity',
      p_input => '{"case":"qa421-invalid-quantity"}'::jsonb,
      p_name => 'QA421 Invalid Quantity',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 0,
      p_price => 10,
      p_currency => 'USD'
    );
    RAISE EXCEPTION 'QA421 quantity rejection sentinel';
  EXCEPTION WHEN OTHERS THEN
    v_message := SQLERRM;
    IF v_message IS DISTINCT FROM 'INVALID_QUANTITY' THEN
      RAISE EXCEPTION 'QA421 expected INVALID_QUANTITY, received %', v_message;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => v_tenant_id,
      p_idempotency_key => 'qa421-missing-demand',
      p_input => '{"case":"qa421-missing-demand"}'::jsonb,
      p_name => 'QA421 Missing Demand',
      p_demand_id => '50000000-0000-4000-8000-000000000099',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2,
      p_price => 10,
      p_currency => 'USD'
    );
    RAISE EXCEPTION 'QA421 demand rejection sentinel';
  EXCEPTION WHEN OTHERS THEN
    v_message := SQLERRM;
    IF v_message IS DISTINCT FROM 'DEMAND_NOT_FOUND' THEN
      RAISE EXCEPTION 'QA421 expected DEMAND_NOT_FOUND, received %', v_message;
    END IF;
  END;

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
    RAISE EXCEPTION 'QA421 rejected validation calls changed persistence counts (before: %, %, %, %; after: %, %, %, %)',
      v_before.idempotency_count, v_before.execution_count, v_before.offer_count, v_before.event_count,
      v_after.idempotency_count, v_after.execution_count, v_after.offer_count, v_after.event_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = v_tenant_id
      AND key IN ('qa421-provider-actor-mismatch', 'qa421-invalid-quantity', 'qa421-missing-demand')
  ) OR EXISTS (
    SELECT 1 FROM public.action_executions
    WHERE tenant_id = v_tenant_id
      AND idempotency_key IN ('qa421-provider-actor-mismatch', 'qa421-invalid-quantity', 'qa421-missing-demand')
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE name IN ('QA421 Provider Actor Rejection', 'QA421 Invalid Quantity', 'QA421 Missing Demand')
  ) OR EXISTS (
    SELECT 1
    FROM public.action_events e
    JOIN public.action_executions x ON x.id = e.execution_id
    WHERE x.tenant_id = v_tenant_id
      AND x.idempotency_key IN ('qa421-provider-actor-mismatch', 'qa421-invalid-quantity', 'qa421-missing-demand')
  ) THEN
    RAISE EXCEPTION 'QA421 rejected validation call left a key, execution, offer or event';
  END IF;

  RAISE NOTICE 'QA421 PASS: provider-actor, quantity and missing-demand validation failures leave all four persistence tables unchanged';
END
$qa421_pre_persistence_rejection$;

RESET ROLE;
COMMIT;

SELECT 'QA421 PASS: pre-persistence validation rejections leave no idempotency key, action execution, offer or action event' AS result;
