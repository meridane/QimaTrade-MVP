-- Align CREATE_OFFER execution statuses with the CHECK constraints deployed in Supabase.
-- This migration only replaces the function body; it does not rewrite existing rows.
-- Public result.status remains "succeeded" for compatibility with the application contract.

CREATE OR REPLACE FUNCTION public.execute_create_offer_v1(
  p_tenant_id uuid,
  p_idempotency_key text,
  p_input jsonb,
  p_name text,
  p_demand_id uuid,
  p_product_master_id uuid,
  p_provider_actor_id uuid,
  p_quantity numeric,
  p_price numeric,
  p_currency text,
  p_conditions text DEFAULT NULL::text,
  p_market text DEFAULT NULL::text,
  p_geography text DEFAULT NULL::text,
  p_attributes jsonb DEFAULT '{}'::jsonb,
  p_documentation_status text DEFAULT NULL::text,
  p_lifecycle text DEFAULT NULL::text,
  p_offer_type text DEFAULT NULL::text,
  p_pricing_model text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_actor_id uuid;
  v_action_id uuid;
  v_execution_id uuid;
  v_offer_id uuid;
  v_existing record;
  v_hash text;
  v_result jsonb;
  v_correlation_id uuid;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'UNAUTHENTICATED'; END IF;
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'TENANT_REQUIRED'; END IF;
  IF nullif(trim(p_idempotency_key), '') IS NULL THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REQUIRED'; END IF;
  IF p_input IS NULL THEN RAISE EXCEPTION 'ACTION_INPUT_REQUIRED'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.dt_memberships
    WHERE tenant_id = p_tenant_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'TENANT_ACCESS_DENIED';
  END IF;

  SELECT actor_id INTO v_actor_id
  FROM public.profiles
  WHERE auth_user_id = v_user_id
  LIMIT 1;

  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'PROFILE_ACTOR_NOT_FOUND'; END IF;
  IF p_provider_actor_id IS DISTINCT FROM v_actor_id THEN RAISE EXCEPTION 'INVALID_PROVIDER_ACTOR'; END IF;
  -- PostgreSQL numeric can represent NaN and Infinity; ordinary <= / < checks do not reject all of them.
  IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'INVALID_QUANTITY';
  END IF;
  IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;
  IF nullif(trim(p_currency), '') IS NULL THEN RAISE EXCEPTION 'INVALID_CURRENCY'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.product_masters
    WHERE id = p_product_master_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'PRODUCT_MASTER_NOT_FOUND';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.demands WHERE id = p_demand_id) THEN
    RAISE EXCEPTION 'DEMAND_NOT_FOUND';
  END IF;

  SELECT id INTO v_action_id
  FROM public.action_definitions
  WHERE action_key = 'CREATE_OFFER' AND version = 1 AND status = 'published'
  LIMIT 1;

  IF v_action_id IS NULL THEN RAISE EXCEPTION 'ACTION_NOT_PUBLISHED'; END IF;

  -- Hash the complete effective request, not only the caller-supplied p_input.
  -- Reusing one idempotency key with different business parameters must be rejected.
  v_hash := md5(jsonb_build_object(
    'input', p_input,
    'name', p_name,
    'demandId', p_demand_id,
    'productMasterId', p_product_master_id,
    'providerActorId', p_provider_actor_id,
    'quantity', p_quantity,
    'price', p_price,
    'currency', p_currency,
    'conditions', p_conditions,
    'market', p_market,
    'geography', p_geography,
    'attributes', coalesce(p_attributes, '{}'::jsonb),
    'documentationStatus', p_documentation_status,
    'lifecycle', p_lifecycle,
    'offerType', p_offer_type,
    'pricingModel', p_pricing_model
  )::text);

  -- Serialize all attempts for the same tenant/key, including the first insert.
  -- SELECT ... FOR UPDATE alone cannot lock a row that does not exist yet.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_tenant_id::text || ':' || p_idempotency_key, 0)
  );

  SELECT * INTO v_existing
  FROM public.idempotency_keys
  WHERE tenant_id = p_tenant_id AND key = p_idempotency_key
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.request_hash <> v_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';
    END IF;

    IF v_existing.status IN ('COMPLETED', 'FAILED') THEN
      RETURN coalesce(
        v_existing.result,
        jsonb_build_object('status', lower(v_existing.status), 'executionId', v_existing.execution_id)
      );
    END IF;

    RAISE EXCEPTION 'ACTION_ALREADY_RUNNING';
  END IF;

  v_correlation_id := gen_random_uuid();

  INSERT INTO public.action_executions(
    action_id, action_version, actor_id, object_type, object_id,
    correlation_id, idempotency_key, status, input, tenant_id
  )
  VALUES (
    v_action_id, 1, v_actor_id, 'Offer', NULL,
    v_correlation_id, p_idempotency_key, 'RUNNING', p_input, p_tenant_id
  )
  RETURNING id INTO v_execution_id;

  INSERT INTO public.idempotency_keys(
    key, action_id, actor_id, request_hash, execution_id,
    status, result, tenant_id
  )
  VALUES (
    p_idempotency_key, v_action_id, v_actor_id, v_hash, v_execution_id,
    'IN_PROGRESS', NULL, p_tenant_id
  );

  v_offer_id := public.create_offer_v1(
    p_name, p_demand_id, p_product_master_id, p_provider_actor_id,
    p_quantity, p_price, p_currency, p_conditions, p_market, p_geography,
    p_attributes, p_documentation_status, p_lifecycle, p_offer_type, p_pricing_model
  );

  v_result := jsonb_build_object(
    'status', 'succeeded',
    'executionId', v_execution_id,
    'objectType', 'Offer',
    'objectId', v_offer_id
  );

  UPDATE public.action_executions
  SET object_id = v_offer_id,
      status = 'COMPLETED',
      result = v_result,
      completed_at = now()
  WHERE id = v_execution_id;

  UPDATE public.idempotency_keys
  SET status = 'COMPLETED',
      result = v_result,
      completed_at = now()
  WHERE tenant_id = p_tenant_id AND key = p_idempotency_key;

  INSERT INTO public.action_events(
    execution_id, action_id, action_version, event_type, actor_id,
    object_type, object_id, correlation_id, payload, tenant_id
  )
  VALUES (
    v_execution_id, v_action_id, 1, 'ACTION_SUCCEEDED', v_actor_id,
    'Offer', v_offer_id, v_correlation_id, v_result, p_tenant_id
  );

  RETURN v_result;
END;
$function$;
