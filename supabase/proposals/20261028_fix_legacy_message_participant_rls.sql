-- PROPOSAL ONLY — NOT A SUPABASE MIGRATION.
-- Review: docs/LEGACY_MESSAGES_RLS_REVIEW_2026-10-28.md
-- Do not run against production. First copy to a disposable database and run
-- the regression matrix in the review document.
--
-- This keeps the current function signature so existing policies continue to
-- call it, but sender identity alone is no longer treated as membership.
-- Access is established only by being the requester of the exact demand or
-- the provider of an offer whose demand_id matches the message's demand_id.
-- The INSERT policy separately checks that sender_actor_id belongs to auth.uid().

CREATE OR REPLACE FUNCTION public.is_message_participant(
  p_message_demand_id uuid,
  p_message_offer_id uuid,
  p_sender_actor_id uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.auth_user_id = auth.uid()
      AND (
        EXISTS (
          SELECT 1
          FROM public.demands d
          WHERE d.id = p_message_demand_id
            AND d.requester_actor_id = p.actor_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.offers o
          JOIN public.demands d ON d.id = o.demand_id
          WHERE o.id = p_message_offer_id
            AND d.id = p_message_demand_id
            AND o.provider_actor_id = p.actor_id
        )
      )
  );
$function$;

-- Intentionally do not alter grants or policies here. Validate existing
-- EXECUTE grants, RLS behavior, and all positive/negative cases in isolation.
-- If legitimate chat access currently depends on another workflow, update
-- this predicate only after documenting and testing that business rule.
