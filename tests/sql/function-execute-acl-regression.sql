\set ON_ERROR_STOP on

-- These stubs live only in a dedicated temporary database created by the runner.
-- New PostgreSQL functions receive PUBLIC EXECUTE by default unless default ACLs override it.
CREATE OR REPLACE FUNCTION public.current_profile_actor_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT NULL::uuid';

CREATE OR REPLACE FUNCTION public.dt_select_product_master(uuid, uuid, uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS 'SELECT ''{}''::jsonb';

CREATE OR REPLACE FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS 'SELECT ''{}''::jsonb';

CREATE OR REPLACE FUNCTION public.dt_has_tenant_access(uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS 'SELECT false';

CREATE OR REPLACE FUNCTION public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS 'SELECT ''{}''::jsonb';

CREATE OR REPLACE FUNCTION public.dt_publish_product_request(uuid, uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS 'SELECT ''{}''::jsonb';

CREATE OR REPLACE FUNCTION public.is_message_participant(uuid, uuid, uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS 'SELECT false';

-- Snapshot ownership before ACL changes. REVOKE cannot remove an owner's implicit privileges,
-- so the fixture must not accidentally model anon/authenticated as function owners.
CREATE TEMP TABLE qima_acl_function_owner_snapshot (
  function_oid oid PRIMARY KEY,
  owner_oid oid NOT NULL
) ON COMMIT PRESERVE ROWS;

-- Add a direct anon grant as well, so the migration must remove both inherited
-- PUBLIC access and a possible pre-existing direct anon grant.
GRANT EXECUTE ON FUNCTION public.current_profile_actor_id() TO anon;
GRANT EXECUTE ON FUNCTION public.dt_select_product_master(uuid, uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) TO anon;
GRANT EXECUTE ON FUNCTION public.dt_has_tenant_access(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.dt_publish_product_request(uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_message_participant(uuid, uuid, uuid) TO anon;

DO $acl$
DECLARE
  v_function_oid oid;
  v_anon_oid oid;
  v_authenticated_oid oid;
  v_owner_oid oid;
  v_expected_security_definer boolean[] := ARRAY[true, false, true, true, true, true, true];
  v_is_security_definer boolean;
  v_has_pinned_search_path boolean;
  v_index integer := 0;
  v_function_oids oid[] := ARRAY[
    'public.current_profile_actor_id()'::regprocedure::oid,
    'public.dt_select_product_master(uuid,uuid,uuid)'::regprocedure::oid,
    'public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure::oid,
    'public.dt_has_tenant_access(uuid)'::regprocedure::oid,
    'public.dt_submit_answer(uuid,uuid,integer,uuid,text,text,uuid)'::regprocedure::oid,
    'public.dt_publish_product_request(uuid,uuid)'::regprocedure::oid,
    'public.is_message_participant(uuid,uuid,uuid)'::regprocedure::oid
  ];
BEGIN
  SELECT oid INTO v_anon_oid FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated_oid FROM pg_roles WHERE rolname = 'authenticated';
  IF v_anon_oid IS NULL OR v_authenticated_oid IS NULL THEN
    RAISE EXCEPTION 'ACL regression fixture requires anon and authenticated roles';
  END IF;

  FOREACH v_function_oid IN ARRAY v_function_oids LOOP
    v_index := v_index + 1;

    SELECT p.proowner INTO v_owner_oid FROM pg_proc p WHERE p.oid = v_function_oid;
    IF v_owner_oid IN (v_anon_oid, v_authenticated_oid) THEN
      RAISE EXCEPTION 'ACL regression fixture owner must not be anon/authenticated on %', v_function_oid::regprocedure;
    END IF;
    INSERT INTO qima_acl_function_owner_snapshot(function_oid, owner_oid)
    VALUES (v_function_oid, v_owner_oid);

    IF NOT has_function_privilege('anon', v_function_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'ACL regression fixture did not establish anon EXECUTE before migration on %', v_function_oid::regprocedure;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = v_function_oid
        AND a.grantee = 0
        AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION 'Expected PostgreSQL default PUBLIC EXECUTE before migration on %', v_function_oid::regprocedure;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = v_function_oid
        AND a.grantee = v_anon_oid
        AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION 'Expected a direct anon EXECUTE ACL before migration on %', v_function_oid::regprocedure;
    END IF;

    SELECT p.prosecdef,
           COALESCE(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=public']
      INTO v_is_security_definer, v_has_pinned_search_path
      FROM pg_proc p
     WHERE p.oid = v_function_oid;

    IF v_is_security_definer IS DISTINCT FROM v_expected_security_definer[v_index] THEN
      RAISE EXCEPTION 'Fixture security mode mismatch on %; expected SECURITY %',
        v_function_oid::regprocedure,
        CASE WHEN v_expected_security_definer[v_index] THEN 'DEFINER' ELSE 'INVOKER' END;
    END IF;

    IF NOT v_has_pinned_search_path THEN
      RAISE EXCEPTION 'Fixture does not pin search_path=public on %', v_function_oid::regprocedure;
    END IF;
  END LOOP;
END
$acl$;

-- Synthetic CI invariant only: client-facing roles must not be able to create
-- objects in public. This is not a statement about the live Supabase ACL.
DO $schema_create_before$
BEGIN
  IF has_schema_privilege('anon', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'anon unexpectedly has CREATE on public before ACL migrations';
  END IF;
  IF has_schema_privilege('authenticated', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'authenticated unexpectedly has CREATE on public before ACL migrations';
  END IF;
END
$schema_create_before$;

\ir ../../supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql
\ir ../../supabase/migrations/20261110080000_harden_authenticated_helper_anon_acl.sql
-- Reapplying both migrations must remain safe and produce the same ACL.
\ir ../../supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql
\ir ../../supabase/migrations/20261110080000_harden_authenticated_helper_anon_acl.sql
-- Reapplying both migrations must remain safe and produce the same ACL.
\ir ../../supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql
\ir ../../supabase/migrations/20261110080000_harden_authenticated_helper_anon_acl.sql

-- The RPC ACL migrations must not broaden client CREATE on the public schema.
-- This assertion covers the disposable fixture only; production privileges are
-- still an independent read-only verification gate.
DO $schema_create_after$
BEGIN
  IF has_schema_privilege('anon', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'anon gained CREATE on public during ACL migrations';
  END IF;
  IF has_schema_privilege('authenticated', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'authenticated gained CREATE on public during ACL migrations';
  END IF;
END
$schema_create_after$;

DO $
DECLARE
  v_function_oid oid;
  v_anon_oid oid;
  v_authenticated_oid oid;
  v_owner_oid oid;
  v_expected_owner_oid oid;
  v_public_or_anon_execute boolean;
  v_expected_security_definer boolean[] := ARRAY[true, false, true, true, true, true, true];
  v_is_security_definer boolean;
  v_has_pinned_search_path boolean;
  v_index integer := 0;
  v_function_oids oid[] := ARRAY[
    'public.current_profile_actor_id()'::regprocedure::oid,
    'public.dt_select_product_master(uuid,uuid,uuid)'::regprocedure::oid,
    'public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure::oid,
    'public.dt_has_tenant_access(uuid)'::regprocedure::oid,
    'public.dt_submit_answer(uuid,uuid,integer,uuid,text,text,uuid)'::regprocedure::oid,
    'public.dt_publish_product_request(uuid,uuid)'::regprocedure::oid,
    'public.is_message_participant(uuid,uuid,uuid)'::regprocedure::oid
  ];
BEGIN
  SELECT oid INTO v_anon_oid FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated_oid FROM pg_roles WHERE rolname = 'authenticated';

  FOREACH v_function_oid IN ARRAY v_function_oids LOOP
    v_index := v_index + 1;

    SELECT p.proowner INTO v_owner_oid FROM pg_proc p WHERE p.oid = v_function_oid;
    SELECT s.owner_oid INTO v_expected_owner_oid
      FROM qima_acl_function_owner_snapshot s
     WHERE s.function_oid = v_function_oid;
    IF v_expected_owner_oid IS NULL OR v_owner_oid IS DISTINCT FROM v_expected_owner_oid THEN
      RAISE EXCEPTION 'Function owner changed during ACL migration on %', v_function_oid::regprocedure;
    END IF;

    IF has_function_privilege('anon', v_function_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'anon still has effective EXECUTE on %', v_function_oid::regprocedure;
    END IF;

    IF NOT has_function_privilege('authenticated', v_function_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'authenticated lost effective EXECUTE on %', v_function_oid::regprocedure;
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = v_function_oid
        AND a.grantee IN (0, v_anon_oid)
        AND a.privilege_type = 'EXECUTE'
    ) INTO v_public_or_anon_execute;

    IF v_public_or_anon_execute THEN
      RAISE EXCEPTION 'PUBLIC or direct anon EXECUTE ACL remains on %', v_function_oid::regprocedure;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = v_function_oid
        AND a.grantee = v_authenticated_oid
        AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION 'authenticated EXECUTE grant is not explicit on %', v_function_oid::regprocedure;
    END IF;

    SELECT p.prosecdef,
           COALESCE(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=public']
      INTO v_is_security_definer, v_has_pinned_search_path
      FROM pg_proc p
     WHERE p.oid = v_function_oid;

    IF v_is_security_definer IS DISTINCT FROM v_expected_security_definer[v_index] THEN
      RAISE EXCEPTION 'Function security mode changed on %; expected SECURITY %',
        v_function_oid::regprocedure,
        CASE WHEN v_expected_security_definer[v_index] THEN 'DEFINER' ELSE 'INVOKER' END;
    END IF;

    IF NOT v_has_pinned_search_path THEN
      RAISE EXCEPTION 'Function search_path changed or is not pinned to public on %', v_function_oid::regprocedure;
    END IF;
  END LOOP;
END
$$;

SELECT 'function EXECUTE ACL regression PASS' AS result;
SELECT 'covered functions: 7' AS result;
