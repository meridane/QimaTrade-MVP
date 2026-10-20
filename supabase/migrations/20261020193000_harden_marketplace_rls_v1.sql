-- QIMA V1 marketplace RLS hardening.
-- Proposed migration: validate in an isolated Supabase environment before production.

-- Anonymous API clients must not have direct table privileges on private marketplace data.
revoke all privileges on table
  public.demands,
  public.offers,
  public.matches,
  public.messages
from anon;

-- RLS does not protect against TRUNCATE and does not replace SQL privilege minimization.
revoke delete, truncate, references, trigger, maintain on table
  public.demands,
  public.offers,
  public.matches,
  public.messages
from authenticated;

-- Messages are visible/writable only to the two distinct participants of an accepted
-- demand/offer match. The sender argument, when supplied, must be one of those parties.
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
    from public.demands d
    join public.offers o
      on o.id = p_message_offer_id
    join public.matches m
      on m.demand_id = d.id
     and m.offer_id = o.id
     and m.status = 'accepted'
    where d.id = p_message_demand_id
      and d.requester_actor_id is not null
      and o.provider_actor_id is not null
      and d.requester_actor_id <> o.provider_actor_id
      and public.current_actor_id() in (d.requester_actor_id, o.provider_actor_id)
      and (
        p_sender_actor_id is null
        or p_sender_actor_id in (d.requester_actor_id, o.provider_actor_id)
      )
  );
$function$;

revoke all on function public.is_message_participant(uuid, uuid, uuid) from public, anon;
grant execute on function public.is_message_participant(uuid, uuid, uuid) to authenticated;

-- The existing server action updates a rejected match when a buyer changes their
-- decision. Permit that update only for the demand owner, and freeze the match identity.
create or replace function public.guard_match_decision_update()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  if new.id is distinct from old.id
    or new.name is distinct from old.name
    or new.match_type is distinct from old.match_type
    or new.score is distinct from old.score
    or new.expires_at is distinct from old.expires_at
    or new.demand_id is distinct from old.demand_id
    or new.offer_id is distinct from old.offer_id
    or new.capability_id is distinct from old.capability_id
    or new.service_id is distinct from old.service_id
    or new.source_business_object_id is distinct from old.source_business_object_id
    or new.target_business_object_id is distinct from old.target_business_object_id
    or new.created_at is distinct from old.created_at
  then
    raise exception 'MATCH_IDENTITY_FIELDS_IMMUTABLE';
  end if;

  if old.status = 'accepted' and new.status is distinct from old.status then
    raise exception 'ACCEPTED_MATCH_STATUS_IMMUTABLE';
  end if;

  if new.status is distinct from 'accepted' and new.status is distinct from 'rejected' then
    raise exception 'INVALID_MATCH_STATUS';
  end if;

  return new;
end;
$function$;

drop trigger if exists matches_guard_decision_update on public.matches;
create trigger matches_guard_decision_update
before update on public.matches
for each row execute function public.guard_match_decision_update();

drop policy if exists matches_update_demand_requester on public.matches;
create policy matches_update_demand_requester
on public.matches
for update
to authenticated
using (public.is_demand_requester(demand_id))
with check (
  public.is_demand_requester(demand_id)
  and status in ('accepted', 'rejected')
);
