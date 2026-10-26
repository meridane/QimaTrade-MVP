-- Prevent authenticated clients from bypassing the CREATE_OFFER Universal Action Runtime.
-- The public-facing route inserts through RLS; the runtime invokes create_offer_v1
-- from execute_create_offer_v1, which is SECURITY DEFINER and runs as its owner.
-- This migration is intentionally additive and is not applied to any database here.

BEGIN;

REVOKE ALL ON FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.create_offer_v1(
  text, uuid, uuid, uuid, numeric, numeric, text, text, text, text,
  jsonb, text, text, text, text
) FROM authenticated;

-- Make the supported entry point explicit for signed-in clients.
GRANT EXECUTE ON FUNCTION public.execute_create_offer_v1(
  uuid, text, jsonb, text, uuid, uuid, uuid, numeric, numeric, text,
  text, text, text, jsonb, text, text, text, text
) TO authenticated;

COMMIT;
