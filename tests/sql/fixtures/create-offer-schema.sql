-- Disposable PostgreSQL fixture for CREATE_OFFER runtime tests.
-- This is deliberately isolated from Supabase production. It models the live
-- columns/constraints used by the two RPCs and seeds synthetic records only.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

CREATE TABLE public.dt_tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.dt_memberships (
  tenant_id uuid NOT NULL REFERENCES public.dt_tenants(id),
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'member',
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  actor_id uuid,
  auth_user_id uuid UNIQUE,
  context_fields jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.product_masters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  canonical_name text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  classification_status text NOT NULL DEFAULT 'review',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.demands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  demand_status text,
  quantity numeric,
  budget numeric,
  currency text,
  scope text,
  requester_actor_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  lifecycle text,
  documentation_status text,
  offer_type text,
  quantity numeric,
  price numeric,
  currency text,
  pricing_model text,
  conditions text,
  market text,
  geography text,
  version integer NOT NULL DEFAULT 1,
  provider_actor_id uuid,
  product_id uuid,
  service_id uuid,
  capability_id uuid,
  business_object_id uuid,
  demand_id uuid REFERENCES public.demands(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  product_master_id uuid REFERENCES public.product_masters(id),
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb
);
ALTER TABLE public.offers ADD CONSTRAINT fixture_force_rollback CHECK (name <> 'Fixture rollback failure');

CREATE TABLE public.action_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_key text NOT NULL,
  name text NOT NULL,
  version integer NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'draft',
  object_type text NOT NULL,
  actor_type text NOT NULL,
  context_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.action_executions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id uuid NOT NULL REFERENCES public.action_definitions(id),
  action_version integer NOT NULL,
  actor_id uuid NOT NULL,
  object_type text NOT NULL,
  object_id uuid,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL,
  status text NOT NULL CHECK (status IN ('PENDING','RUNNING','COMPLETED','FAILED','BLOCKED')),
  input jsonb NOT NULL DEFAULT '{}'::jsonb,
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  tenant_id uuid NOT NULL REFERENCES public.dt_tenants(id)
);
CREATE TABLE public.idempotency_keys (
  key text NOT NULL,
  action_id uuid NOT NULL REFERENCES public.action_definitions(id),
  actor_id uuid NOT NULL,
  request_hash text NOT NULL,
  execution_id uuid NOT NULL REFERENCES public.action_executions(id),
  status text NOT NULL CHECK (status IN ('IN_PROGRESS','COMPLETED','FAILED')),
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  tenant_id uuid NOT NULL REFERENCES public.dt_tenants(id),
  UNIQUE (tenant_id, key)
);
CREATE TABLE public.action_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  execution_id uuid NOT NULL REFERENCES public.action_executions(id),
  action_id uuid NOT NULL REFERENCES public.action_definitions(id),
  action_version integer NOT NULL,
  event_type text NOT NULL,
  actor_id uuid NOT NULL,
  object_type text NOT NULL,
  object_id uuid,
  correlation_id uuid NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  tenant_id uuid NOT NULL REFERENCES public.dt_tenants(id)
);

-- Low-level function mirrors the live signature and core insert contract.
CREATE OR REPLACE FUNCTION public.create_offer_v1(
  p_name text, p_demand_id uuid, p_product_master_id uuid,
  p_provider_actor_id uuid, p_quantity numeric, p_price numeric,
  p_currency text, p_conditions text, p_market text, p_geography text,
  p_attributes jsonb, p_documentation_status text, p_lifecycle text,
  p_offer_type text, p_pricing_model text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_id uuid; v_actor_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'UNAUTHENTICATED'; END IF;
  SELECT actor_id INTO v_actor_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'PROFILE_ACTOR_NOT_FOUND'; END IF;
  IF p_provider_actor_id IS NULL OR p_provider_actor_id <> v_actor_id THEN RAISE EXCEPTION 'INVALID_PROVIDER_ACTOR'; END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
  IF p_price IS NULL OR p_price < 0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;
  IF nullif(trim(p_currency), '') IS NULL THEN RAISE EXCEPTION 'INVALID_CURRENCY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.product_masters WHERE id=p_product_master_id) THEN RAISE EXCEPTION 'PRODUCT_MASTER_NOT_FOUND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.demands WHERE id=p_demand_id) THEN RAISE EXCEPTION 'DEMAND_NOT_FOUND'; END IF;
  -- Test-only delay widens the overlap window for the concurrent first-insert test.
  PERFORM pg_sleep(0.5);
  INSERT INTO public.offers(name,demand_id,product_master_id,provider_actor_id,quantity,price,currency,conditions,market,geography,attributes,documentation_status,lifecycle,offer_type,pricing_model)
  VALUES(p_name,p_demand_id,p_product_master_id,v_actor_id,p_quantity,p_price,p_currency,p_conditions,p_market,p_geography,coalesce(p_attributes,'{}'::jsonb),p_documentation_status,p_lifecycle,p_offer_type,p_pricing_model)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT USAGE ON SCHEMA public, auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_offer_v1(text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text) TO authenticated;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

INSERT INTO public.dt_tenants(id,name) VALUES
 ('10000000-0000-4000-8000-000000000001','Fixture Tenant A'),
 ('10000000-0000-4000-8000-000000000002','Fixture Tenant B');
INSERT INTO public.dt_memberships(tenant_id,user_id) VALUES
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002');
INSERT INTO public.profiles(id,name,actor_id,auth_user_id) VALUES
 ('30000000-0000-4000-8000-000000000001','Fixture Provider A','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001'),
 ('30000000-0000-4000-8000-000000000002','Fixture Provider B','30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002');
INSERT INTO public.product_masters(id,code,name,canonical_name,status) VALUES
 ('40000000-0000-4000-8000-000000000001','FIXTURE-1','Fixture Product','Fixture Product','active'),
 ('40000000-0000-4000-8000-000000000099','INACTIVE-1','Inactive Fixture','Inactive Fixture','draft');
INSERT INTO public.demands(id,name,demand_status,requester_actor_id) VALUES
 ('50000000-0000-4000-8000-000000000001','Fixture Demand','published','30000000-0000-4000-8000-000000000002');
INSERT INTO public.action_definitions(id,action_key,name,version,status,object_type,actor_type,context_type) VALUES
 ('60000000-0000-4000-8000-000000000001','CREATE_OFFER','Create Offer',1,'published','Offer','Actor','Tenant');
