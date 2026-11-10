-- Prevent clients from bypassing the CREATE_OFFER Universal Action Runtime.
-- The SECURITY DEFINER wrapper must retain EXECUTE on this low-level function
-- even when the wrapper and low-level function have different owners.
-- This additive migration is branch-only; it has not been applied to Production.

BEGIN;

REVOKE ALL ON FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
) FROM PUBLIC, anon, authenticated;

-- A SECURITY DEFINER function executes with its own owner's privileges.
-- Grant the low-level RPC only to the trusted owner of the supported wrapper;
-- fail closed if the wrapper is missing, not SECURITY DEFINER, or owned by a
-- client-facing role that could otherwise retain direct execution.
DO $wrapper_owner$
DECLARE
  v_wrapper_oid oid;
  v_wrapper_owner_oid oid;
  v_wrapper_owner name;
  v_wrapper_is_security_definer boolean;
BEGIN
  v_wrapper_oid := to_regprocedure(
    'public.execute_create_offer_v1(uuid,text,jsonb,text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text)'
  );

  IF v_wrapper_oid IS NULL THEN
    RAISE EXCEPTION 'Expected CREATE_OFFER SECURITY DEFINER wrapper is missing';
  END IF;

  SELECT r.oid, r.rolname, p.prosecdef
  INTO v_wrapper_owner_oid, v_wrapper_owner, v_wrapper_is_security_definer
  FROM pg_proc p
  JOIN pg_roles r ON r.oid = p.proowner
  WHERE p.oid = v_wrapper_oid;

  IF NOT COALESCE(v_wrapper_is_security_definer, false) THEN
    RAISE EXCEPTION 'CREATE_OFFER wrapper must remain SECURITY DEFINER';
  END IF;

  IF v_wrapper_owner IS NULL OR v_wrapper_owner IN ('anon', 'authenticated') THEN
    RAISE EXCEPTION 'CREATE_OFFER wrapper must have a trusted non-client owner';
  END IF;

  -- A trusted owner role must not be reachable through membership by either
  -- client-facing role; otherwise its low-level EXECUTE grant could be inherited.
  IF pg_has_role('anon', v_wrapper_owner_oid, 'MEMBER')
     OR pg_has_role('authenticated', v_wrapper_owner_oid, 'MEMBER') THEN
    RAISE EXCEPTION 'CREATE_OFFER wrapper owner must not be a member of a client-facing role';
  END IF;

  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION public.create_offer_v1(text,uuid,uuid,uuid,numeric,numeric,text,text,text,text,jsonb,text,text,text,text) TO %I',
    v_wrapper_owner
  );
END
$wrapper_owner$;

-- Make the supported entry point explicit for signed-in clients.
GRANT EXECUTE ON FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) TO authenticated;

COMMIT;
