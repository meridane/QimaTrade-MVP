\set ON_ERROR_STOP on

-- QA332 exercises PostgreSQL INSERT ... RETURNING and SELECT-policy mechanics
-- using a synthetic actor-scoped SELECT policy. It is not a proposed/live policy.
DO $qa332_environment_guard$
BEGIN
  IF current_database() <> 'qima_test' THEN
    RAISE EXCEPTION 'QA332 requires the disposable qima_test database; refusing database %', current_database();
  END IF;

  IF current_setting('application_name', true) IS DISTINCT FROM 'qima-ci-legacy-offer-returning' THEN
    RAISE EXCEPTION 'QA332 must run only from the dedicated CI regression step';
  END IF;
END
$qa332_environment_guard$;

BEGIN;

ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON public.offers TO authenticated;

-- QA330 rolls its migration back, so apply the existing INSERT policy here
-- inside this independent disposable transaction.
\ir ../../supabase/migrations/20260829130000_fix_offers_insert_rls_actor_lookup.sql

DO $qa332_policy_preflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'offers'
      AND policyname = 'offers_insert_own_provider'
      AND cmd = 'INSERT'
  ) THEN
    RAISE EXCEPTION 'QA332 expected the existing actor-bound INSERT policy';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'offers'
      AND cmd IN ('SELECT', 'ALL')
  ) THEN
    RAISE EXCEPTION 'QA332 baseline must not contain a SELECT policy before the synthetic policy is added';
  END IF;
END
$qa332_policy_preflight$;

-- Seed one row per synthetic provider so SELECT visibility can distinguish
-- own-provider rows from another provider's row for the same demand.
INSERT INTO public.offers (id, name, demand_id, provider_actor_id)
VALUES
  ('70000000-0000-4000-8000-000000000001', 'QA332 seed actor A', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001'),
  ('70000000-0000-4000-8000-000000000002', 'QA332 seed actor B', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002');

-- Without a SELECT policy, INSERT ... RETURNING must not expose the new row.
-- The nested block always rolls the probe insert back: PostgreSQL may reject
-- it, or RETURNING may yield no visible row.
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa332_returning_requires_select_policy$
DECLARE
  v_returned_id uuid;
  v_returned_row boolean := false;
BEGIN
  IF current_user <> 'authenticated' THEN
    RAISE EXCEPTION 'QA332 no-SELECT probe must execute as authenticated';
  END IF;

  BEGIN
    INSERT INTO public.offers (name, demand_id, provider_actor_id)
    VALUES ('QA332 no SELECT policy probe', '50000000-0000-4000-8000-000000000001', public.current_profile_actor_id())
    RETURNING id INTO v_returned_id;

    v_returned_row := FOUND AND v_returned_id IS NOT NULL;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'QA332_ROLLBACK_PROBE';
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_returned_row := false;
    WHEN SQLSTATE 'P0001' THEN
      IF SQLERRM <> 'QA332_ROLLBACK_PROBE' THEN
        RAISE;
      END IF;
  END;

  IF v_returned_row THEN
    RAISE EXCEPTION 'QA332 unexpectedly returned an inserted row without a SELECT policy';
  END IF;
END
$qa332_returning_requires_select_policy$;

RESET ROLE;

-- This policy is synthetic and transaction-scoped. It tests mechanics only;
-- it does not define the real supplier/buyer conversation visibility contract.
CREATE POLICY qa332_offers_select_own_provider
ON public.offers
FOR SELECT
TO authenticated
USING (provider_actor_id = public.current_profile_actor_id());

SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;

DO $qa332_actor_a_returning_and_select$
DECLARE
  v_returned_id uuid;
  v_own_rows integer;
  v_other_rows integer;
  v_returned_visible integer;
BEGIN
  IF current_user <> 'authenticated' THEN
    RAISE EXCEPTION 'QA332 actor A checks must execute as authenticated';
  END IF;

  INSERT INTO public.offers (name, demand_id, provider_actor_id)
  VALUES ('QA332 returned actor A', '50000000-0000-4000-8000-000000000001', public.current_profile_actor_id())
  RETURNING id INTO v_returned_id;

  IF NOT FOUND OR v_returned_id IS NULL THEN
    RAISE EXCEPTION 'QA332 expected INSERT RETURNING to expose actor A own row under the synthetic SELECT policy';
  END IF;

  SELECT count(*) INTO v_returned_visible
  FROM public.offers
  WHERE id = v_returned_id
    AND demand_id = '50000000-0000-4000-8000-000000000001';
  IF v_returned_visible <> 1 THEN
    RAISE EXCEPTION 'QA332 actor A could not read its returned offer through the demand-scoped SELECT shape';
  END IF;

  SELECT count(*) INTO v_own_rows
  FROM public.offers
  WHERE demand_id = '50000000-0000-4000-8000-000000000001'
    AND name LIKE 'QA332 %';
  SELECT count(*) INTO v_other_rows
  FROM public.offers
  WHERE demand_id = '50000000-0000-4000-8000-000000000001'
    AND name LIKE 'QA332 %'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000002';

  IF v_own_rows <> 2 OR v_other_rows <> 0 THEN
    RAISE EXCEPTION 'QA332 actor A SELECT visibility mismatch: own rows %, other-provider rows %', v_own_rows, v_other_rows;
  END IF;
END
$qa332_actor_a_returning_and_select$;

RESET ROLE;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;

DO $qa332_actor_b_returning_and_select$
DECLARE
  v_returned_id uuid;
  v_own_rows integer;
  v_other_rows integer;
  v_returned_visible integer;
BEGIN
  IF current_user <> 'authenticated' THEN
    RAISE EXCEPTION 'QA332 actor B checks must execute as authenticated';
  END IF;

  INSERT INTO public.offers (name, demand_id, provider_actor_id)
  VALUES ('QA332 returned actor B', '50000000-0000-4000-8000-000000000001', public.current_profile_actor_id())
  RETURNING id INTO v_returned_id;

  IF NOT FOUND OR v_returned_id IS NULL THEN
    RAISE EXCEPTION 'QA332 expected INSERT RETURNING to expose actor B own row under the synthetic SELECT policy';
  END IF;

  SELECT count(*) INTO v_returned_visible
  FROM public.offers
  WHERE id = v_returned_id
    AND demand_id = '50000000-0000-4000-8000-000000000001';
  IF v_returned_visible <> 1 THEN
    RAISE EXCEPTION 'QA332 actor B could not read its returned offer through the demand-scoped SELECT shape';
  END IF;

  SELECT count(*) INTO v_own_rows
  FROM public.offers
  WHERE demand_id = '50000000-0000-4000-8000-000000000001'
    AND name LIKE 'QA332 %';
  SELECT count(*) INTO v_other_rows
  FROM public.offers
  WHERE demand_id = '50000000-0000-4000-8000-000000000001'
    AND name LIKE 'QA332 %'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001';

  IF v_own_rows <> 2 OR v_other_rows <> 0 THEN
    RAISE EXCEPTION 'QA332 actor B SELECT visibility mismatch: own rows %, other-provider rows %', v_own_rows, v_other_rows;
  END IF;
END
$qa332_actor_b_returning_and_select$;

RESET ROLE;

DO $qa332_final_assertions$
DECLARE
  v_total integer;
BEGIN
  SELECT count(*) INTO v_total
  FROM public.offers
  WHERE name IN (
    'QA332 seed actor A',
    'QA332 seed actor B',
    'QA332 returned actor A',
    'QA332 returned actor B',
    'QA332 no SELECT policy probe'
  );

  IF v_total <> 4 THEN
    RAISE EXCEPTION 'QA332 expected two seed rows and two successful RETURNING rows, got %', v_total;
  END IF;
END
$qa332_final_assertions$;

ROLLBACK;

SELECT 'QA332 legacy offers INSERT RETURNING and synthetic actor-scoped SELECT regression PASS; transaction rolled back' AS result;
