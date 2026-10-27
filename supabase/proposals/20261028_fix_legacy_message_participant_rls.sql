-- PROPOSAL ONLY — NOT A SUPABASE MIGRATION.
-- Review: docs/LEGACY_MESSAGES_RLS_REVIEW_2026-10-28.md
-- Do not run against production. First apply only to a disposable database,
-- with synthetic users, and run all cases in the review document.
--
-- The predicate validates that the caller is the requester for this exact
-- demand, or the provider for an offer belonging to this exact demand.
-- Sender identity is deliberately not used as proof of access; the existing
-- INSERT policy separately requires sender_actor_id to match the caller.
-- The demand/offer pair is validated before either participant path.

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
    JOIN public.demands d ON d.id = p_message_demand_id
    WHERE p.auth_user_id = auth.uid()
      AND (
        -- Demand-only message is supported only when no offer is supplied.
        (p_message_offer_id IS NULL AND d.requester_actor_id = p.actor_id)
        OR
        -- If an offer is supplied, it must belong to this demand. The
        -- requester can read/respond to that demand's offer conversation.
        EXISTS (
          SELECT 1
          FROM public.offers o
          WHERE o.id = p_message_offer_id
            AND o.demand_id = d.id
            AND d.requester_actor_id = p.actor_id
        )
        OR
        -- Provider may access only their own offer and its matching demand.
        EXISTS (
          SELECT 1
          FROM public.offers o
          WHERE o.id = p_message_offer_id
            AND o.demand_id = d.id
            AND o.provider_actor_id = p.actor_id
        )
      )
  );
$function$;

-- Intentionally do not alter grants or policies here. Validate current
-- EXECUTE grants, RLS evaluation, and all positive/negative cases in isolation.
-- If product rules require demand-only messages from providers or accepted
-- matches without a direct offer, document and test that rule before changing
-- this predicate. Existing messages remain stored; this changes access checks.
