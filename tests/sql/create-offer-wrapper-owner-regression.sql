\\set ON_ERROR_STOP on

-- Isolated regression: the wrapper owner is deliberately different from the
-- low-level create_offer_v1 owner. The migration must preserve only the
-- SECURITY DEFINER wrapper's required EXECUTE path after revoking client access.

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qima_wrapper_owner_test') THEN
    RAISE EXCEPTION 'The disposable wrapper-owner role must be created by the runner';
  END IF;
END
$roles$;

GRANT USAGE ON SCHEMA public TO anon, authenticated, qima_wrapper_owner_test;
GRANT CREATE ON SCHEMA public TO qima_wrapper_owner_test;

CREATE FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$ SELECT '70000000-0000-4000-8000-000000000001'::uuid $$;

-- Simulate historical direct grants in addition to PostgreSQL's default PUBLIC EXECUTE.
GRANT EXECUTE ON FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
) TO anon, authenticated;

CREATE FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $wrapper$
DECLARE
  v_offer_id uuid;
BEGIN
  v_offer_id := public.create_offer_v1(
    'wrapper-owner-regression',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1, 1, 'USD', NULL, NULL, NULL, '{}'::jsonb, NULL, 'draft', 'supplier_offer', 'fixed'
  );
  RETURN jsonb_build_object('status', 'succeeded', 'objectId', v_offer_id);
END
$wrapper$;

ALTER FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) OWNER TO qima_wrapper_owner_test;
REVOKE CREATE ON SCHEMA public FROM qima_wrapper_owner_test;

\\ir ../../supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql
-- Reapplying the additive REVOKE/GRANT migration must remain safe.
\\ir ../../supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql

DO $assertions$
DECLARE
  v_low_level_oid oid := 'public.create_offer_v1(text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure;
  v_wrapper_oid oid := 'public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure;
  v_anon_oid oid;
  v_authenticated_oid oid;
  v_wrapper_owner_oid oid;
  v_wrapper_owner name;
  v_is_security_definer boolean;
BEGIN
  SELECT oid INTO v_anon_oid FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated_oid FROM pg_roles WHERE rolname = 'authenticated';
  SELECT oid, rolname INTO v_wrapper_owner_oid, v_wrapper_owner
  FROM pg_roles WHERE rolname = 'qima_wrapper_owner_test';

  SELECT r.rolname, p.prosecdef
  INTO v_wrapper_owner, v_is_security_definer
  FROM pg_proc p
  JOIN pg_roles r ON r.oid = p.proowner
  WHERE p.oid = v_wrapper_oid;

  IF v_wrapper_owner IS DISTINCT FROM 'qima_wrapper_owner_test'
     OR NOT COALESCE(v_is_security_definer, false) THEN
    RAISE EXCEPTION 'Wrapper owner/security mode changed unexpectedly';
  END IF;

  IF has_function_privilege('anon', v_low_level_oid, 'EXECUTE')
     OR has_function_privilege('authenticated', v_low_level_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'A client-facing role still has direct low-level RPC execution';
  END IF;

  IF NOT has_function_privilege('qima_wrapper_owner_test', v_low_level_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY DEFINER wrapper owner cannot execute the low-level RPC';
  END IF;

  IF NOT has_function_privilege('authenticated', v_wrapper_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated lost execution on the supported wrapper';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    CROSS JOIN LATERAL aclexplode(
      COALESCE(p.proacl, acldefault('f', p.proowner))
    ) a
    WHERE p.oid = v_low_level_oid
      AND a.grantee IN (0, v_anon_oid, v_authenticated_oid)
      AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'PUBLIC, anon, or authenticated remains in the low-level function ACL';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    CROSS JOIN LATERAL aclexplode(
      COALESCE(p.proacl, acldefault('f', p.proowner))
    ) a
    WHERE p.oid = v_low_level_oid
      AND a.grantee = v_wrapper_owner_oid
      AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Wrapper owner EXECUTE grant is not explicit in the low-level function ACL';
  END IF;
END
$assertions$;

SET ROLE authenticated;
DO $authenticated_calls$
DECLARE
  v_result jsonb;
BEGIN
  BEGIN
    PERFORM public.create_offer_v1(
      'direct-call-must-fail',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1, 1, 'USD', NULL, NULL, NULL, '{}'::jsonb, NULL, 'draft', 'supplier_offer', 'fixed'
    );
    RAISE EXCEPTION 'authenticated unexpectedly executed the low-level RPC directly';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  v_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'wrapper-owner-test-key',
    '{}'::jsonb,
    'wrapper-owner-test',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    1, 1, 'USD',
    NULL, NULL, NULL, '{}'::jsonb, NULL, NULL, NULL, NULL
  );

  IF v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_result->>'objectId' IS DISTINCT FROM '70000000-0000-4000-8000-000000000001' THEN
    RAISE EXCEPTION 'SECURITY DEFINER wrapper did not return the low-level RPC result: %', v_result;
  END IF;
END
$authenticated_calls$;
RESET ROLE;

SET ROLE anon;
DO $anon_call$
BEGIN
  BEGIN
    PERFORM public.create_offer_v1(
      'anon-direct-call-must-fail',
      '50000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      1, 1, 'USD', NULL, NULL, NULL, '{}'::jsonb, NULL, 'draft', 'supplier_offer', 'fixed'
    );
    RAISE EXCEPTION 'anon unexpectedly executed the low-level RPC directly';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$anon_call$;
RESET ROLE;

SELECT 'CREATE_OFFER wrapper-owner EXECUTE regression PASS' AS result;
