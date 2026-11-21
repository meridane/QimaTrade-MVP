-- Reassert authenticated-only EXECUTE ACLs for RPC/RLS helpers.
-- Source review found no anon application caller for these functions:
-- dt_has_tenant_access is used by authenticated-only RLS policies;
-- dt_submit_answer and dt_publish_product_request are called after server auth;
-- is_message_participant is used by the authenticated legacy-message RLS path.
-- This migration is branch-only and has not been applied to Supabase Production.

BEGIN;

REVOKE ALL PRIVILEGES ON FUNCTION public.dt_has_tenant_access(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dt_has_tenant_access(uuid)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.dt_publish_product_request(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dt_publish_product_request(uuid, uuid)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.is_message_participant(uuid, uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_message_participant(uuid, uuid, uuid)
  TO authenticated;

COMMIT;
