-- Fix legacy message participant authorization.
-- A sender actor match alone must never grant access to an arbitrary conversation.
-- This migration is branch-only until reviewed and explicitly applied to a non-production environment.

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
    JOIN public.demands d
      ON d.id = p_message_demand_id
    WHERE p.auth_user_id = auth.uid()
      AND (
        -- Requester may participate in their own demand, but a supplied offer
        -- must belong to that same demand.
        (
          d.requester_actor_id = p.actor_id
          AND (
            p_message_offer_id IS NULL
            OR EXISTS (
              SELECT 1
              FROM public.offers o
              WHERE o.id = p_message_offer_id
                AND o.demand_id = d.id
            )
          )
        )
        OR
        -- Supplier may participate only through their own offer, paired with
        -- the exact demand addressed by the message.
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

REVOKE ALL ON FUNCTION public.is_message_participant(uuid, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_message_participant(uuid, uuid, uuid) TO authenticated;
