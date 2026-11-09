\set ON_ERROR_STOP on

-- These stubs live only in a dedicated temporary database created by the runner.
-- New PostgreSQL functions receive PUBLIC EXECUTE by default unless default ACLs override it.
CREATE OR REPLACE FUNCTION public.current_profile_actor_id()
RETURNS uuid
LANGUAGE sql
AS 'SELECT NULL::uuid';

CREATE OR REPLACE FUNCTION public.dt_select_product_master(uuid, uuid, uuid)
RETURNS jsonb
LANGUAGE sql
AS 'SELECT ''{}''::jsonb';

CREATE OR REPLACE FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
)
RETURNS jsonb
LANGUAGE sql
AS 'SELECT ''{}''::jsonb';

-- Add a direct anon grant as well, so the migration must remove both inherited
-- PUBLIC access and a possible pre-existing direct anon grant.
GRANT EXECUTE ON FUNCTION public.current_profile_actor_id() TO anon;
GRANT EXECUTE ON FUNCTION public.dt_select_product_master(uuid, uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) TO anon;

DO $acl$
DECLARE
  v_function_oid oid;
  v_function_oids oid[] := ARRAY[
    'public.current_profile_actor_id()'::regprocedure::oid,
    'public.dt_select_product_master(uuid,uuid,uuid)'::regprocedure::oid,
    'public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure::oid
  ];
BEGIN
  FOREACH v_function_oid IN ARRAY v_function_oids LOOP
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
  END LOOP;
END
$acl$;

\ir ../../supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql
-- Reapplying the migration must remain safe and produce the same ACL.
\ir ../../supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql

DO $$
DECLARE
  v_function_oid oid;
  v_anon_oid oid;
  v_authenticated_oid oid;
  v_public_or_anon_execute boolean;
  v_function_oids oid[] := ARRAY[
    'public.current_profile_actor_id()'::regprocedure::oid,
    'public.dt_select_product_master(uuid,uuid,uuid)'::regprocedure::oid,
    'public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'::regprocedure::oid
  ];
BEGIN
  SELECT oid INTO v_anon_oid FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated_oid FROM pg_roles WHERE rolname = 'authenticated';

  FOREACH v_function_oid IN ARRAY v_function_oids LOOP
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
  END LOOP;
END
$$;

SELECT 'function EXECUTE ACL regression PASS' AS result;
