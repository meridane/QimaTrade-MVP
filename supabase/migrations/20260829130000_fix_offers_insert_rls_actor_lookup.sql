create or replace function public.current_profile_actor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.actor_id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

grant execute on function public.current_profile_actor_id() to authenticated;

drop policy if exists offers_insert_own_provider on public.offers;

create policy offers_insert_own_provider
on public.offers
for insert
to authenticated
with check (
  provider_actor_id is not null
  and provider_actor_id = public.current_profile_actor_id()
);
