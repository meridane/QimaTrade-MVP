-- Make the intended authenticated-only RPC surface explicit regardless of historical/default function ACLs.
-- The three functions are used by authenticated application/RLS paths; no anon caller is required.
-- This is an additive migration. It has not been applied to Supabase Production.

BEGIN;

REVOKE ALL PRIVILEGES ON FUNCTION public.current_profile_actor_id()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_profile_actor_id()
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.dt_select_product_master(uuid, uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dt_select_product_master(uuid, uuid, uuid)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) TO authenticated;

COMMIT;
