\set ON_ERROR_STOP on

-- This regression applies the existing offers INSERT policy only inside a
-- transaction on the disposable CI database, then rolls every change back.
DO $qa330_environment_guard$
BEGIN
  IF current_database() <> 'qima_test' THEN
    RAISE EXCEPTION 'QA330 requires the disposable qima_test database; refusing database %', current_database();
  END IF;

  IF current_setting('application_name', true) IS DISTINCT FROM 'qima-ci-legacy-offer-rls' THEN
    RAISE EXCEPTION 'QA330 must run only from the dedicated CI regression step';
  END IF;
END
$qa330_environment_guard$;

BEGIN;

ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
GRANT INSERT ON public.offers TO authenticated;

-- Reuse the repository's existing policy migration; this is a disposable,
-- transaction-scoped CI application, not a production migration.
\ir ../../supabase/migrations/20260829130000_fix_offers_insert_rls_actor_lookup.sql

DO $qa330_policy_preflight$
DECLARE
  v_rls_enabled boolean;
BEGIN
  SELECT c.relrowsecurity
  INTO v_rls_enabled
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'offers';

  IF NOT COALESCE(v_rls_enabled, false) THEN
    RAISE EXCEPTION 'QA330 expected row-level security on public.offers';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'offers'
      AND policyname = 'offers_insert_own_provider'
      AND cmd = 'INSERT'
      AND 'authenticated' = ANY (roles)
      AND with_check ILIKE '%provider_actor_id%'
      AND with_check ILIKE '%current_profile_actor_id%'
  ) THEN
    RAISE EXCEPTION 'QA330 expected the authenticated offers_insert_own_provider policy';
  END IF;
END
$qa330_policy_preflight$;

SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa330_actor_a$
BEGIN
  IF current_user <> 'authenticated' THEN
    RAISE EXCEPTION 'QA330 actor A checks must run as authenticated';
  END IF;

  IF public.current_profile_actor_id() IS DISTINCT FROM
     '30000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA330 actor A profile resolution did not match the fixture';
  END IF;

  IF NOT has_table_privilege(current_user, 'public.offers', 'INSERT') THEN
    RAISE EXCEPTION 'QA330 actor A lacks INSERT privilege; the test would not isolate RLS';
  END IF;

  INSERT INTO public.offers (name, provider_actor_id)
  VALUES ('QA330 actor A allowed', '30000000-0000-4000-8000-000000000001');

  BEGIN
    INSERT INTO public.offers (name, provider_actor_id)
    VALUES ('QA330 actor A rejected actor B', '30000000-0000-4000-8000-000000000002');
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'QA330 expected RLS to reject actor B supplied by authenticated actor A';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  BEGIN
    INSERT INTO public.offers (name, provider_actor_id)
    VALUES ('QA330 actor A rejected null actor', NULL);
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'QA330 expected RLS to reject a null provider_actor_id';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END
$qa330_actor_a$;

RESET ROLE;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;

DO $qa330_actor_b$
BEGIN
  IF current_user <> 'authenticated' THEN
    RAISE EXCEPTION 'QA330 actor B checks must run as authenticated';
  END IF;

  IF public.current_profile_actor_id() IS DISTINCT FROM
     '30000000-0000-4000-8000-000000000002'::uuid THEN
    RAISE EXCEPTION 'QA330 actor B profile resolution did not match the fixture';
  END IF;

  IF NOT has_table_privilege(current_user, 'public.offers', 'INSERT') THEN
    RAISE EXCEPTION 'QA330 actor B lacks INSERT privilege; the test would not isolate RLS';
  END IF;

  INSERT INTO public.offers (name, provider_actor_id)
  VALUES ('QA330 actor B allowed', '30000000-0000-4000-8000-000000000002');

  BEGIN
    INSERT INTO public.offers (name, provider_actor_id)
    VALUES ('QA330 actor B rejected actor A', '30000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'QA330 expected RLS to reject actor A supplied by authenticated actor B';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END
$qa330_actor_b$;

RESET ROLE;

DO $qa330_result_assertions$
DECLARE
  v_allowed integer;
  v_rejected integer;
BEGIN
  SELECT count(*) INTO v_allowed
  FROM public.offers
  WHERE name IN ('QA330 actor A allowed', 'QA330 actor B allowed');

  SELECT count(*) INTO v_rejected
  FROM public.offers
  WHERE name IN (
    'QA330 actor A rejected actor B',
    'QA330 actor A rejected null actor',
    'QA330 actor B rejected actor A'
  );

  IF v_allowed <> 2 THEN
    RAISE EXCEPTION 'QA330 expected exactly two actor-matched inserts, got %', v_allowed;
  END IF;

  IF v_rejected <> 0 THEN
    RAISE EXCEPTION 'QA330 expected zero actor-mismatched/null inserts, got %', v_rejected;
  END IF;
END
$qa330_result_assertions$;

ROLLBACK;

SELECT 'QA330 legacy offers INSERT RLS actor-binding regression PASS; transaction rolled back' AS result;
