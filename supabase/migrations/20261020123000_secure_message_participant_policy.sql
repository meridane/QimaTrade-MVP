-- Restrict message visibility and insertion to the two participants of an accepted match.
-- The sender_actor_id argument is intentionally not used to determine participation:
-- SELECT policies pass each row's sender, but both participants must read both sides.
create or replace function public.is_message_participant(
  p_message_demand_id uuid,
  p_message_offer_id uuid,
  p_sender_actor_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $function$
  select exists (
    select 1
    from public.profiles p
    join public.demands d on d.requester_actor_id = p.actor_id
    join public.matches m on m.demand_id = d.id
    join public.offers o on o.id = m.offer_id
    where p.auth_user_id = auth.uid()
      and d.id = p_message_demand_id
      and o.id = p_message_offer_id
      and m.status = 'accepted'
      and o.provider_actor_id is not null
      and o.provider_actor_id <> d.requester_actor_id
  )
  or exists (
    select 1
    from public.profiles p
    join public.offers o on o.provider_actor_id = p.actor_id
    join public.matches m on m.offer_id = o.id
    join public.demands d on d.id = m.demand_id
    where p.auth_user_id = auth.uid()
      and d.id = p_message_demand_id
      and o.id = p_message_offer_id
      and m.status = 'accepted'
      and d.requester_actor_id is not null
      and d.requester_actor_id <> o.provider_actor_id
  );
$function$;
