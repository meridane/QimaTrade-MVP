alter table public.product_requests add column if not exists demand_id uuid references public.demands(id) on delete set null;
create index if not exists product_requests_demand_id_idx on public.product_requests(demand_id);

create or replace function public.dt_publish_product_request(p_request_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.product_requests%rowtype;
  v_product public.product_masters%rowtype;
  v_profile public.profiles%rowtype;
  v_demand public.demands%rowtype;
  v_scope jsonb;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'UNAUTHENTICATED';
  end if;

  select * into v_request
  from public.product_requests
  where id = p_request_id and user_id = p_user_id
  for update;
  if not found then raise exception 'PRODUCT_REQUEST_NOT_FOUND'; end if;

  if v_request.demand_id is not null then
    select * into v_demand from public.demands where id = v_request.demand_id;
    return jsonb_build_object('requestId', v_request.id, 'demandId', v_demand.id, 'status', 'published');
  end if;

  select * into v_product
  from public.product_masters
  where id = v_request.product_master_id and status = 'active';
  if not found then raise exception 'PRODUCT_MASTER_NOT_FOUND'; end if;

  select * into v_profile
  from public.profiles
  where auth_user_id = p_user_id and actor_id is not null
  limit 1;
  if not found then raise exception 'ACTOR_NOT_LINKED'; end if;

  v_scope := jsonb_build_object(
    'category', coalesce((select c.name from public.subcategories s join public.categories c on c.id = s.category_id where s.id = v_product.subcategory_id), ''),
    'subcategory', coalesce((select s.name from public.subcategories s where s.id = v_product.subcategory_id), ''),
    'product_master_id', v_product.id,
    'product_master_code', v_product.code,
    'product_master_name', v_product.canonical_name,
    'description', coalesce(v_request.description, ''),
    'unit', coalesce(v_request.unit, 'pcs'),
    'decision_session_id', v_request.decision_session_id
  );

  insert into public.demands (
    name,
    demand_status,
    documentation_status,
    quantity,
    scope,
    source,
    requester_actor_id
  ) values (
    v_request.title,
    'draft',
    'incomplete',
    v_request.quantity,
    v_scope,
    'qimatrade_decision_tree_v1',
    v_profile.actor_id
  ) returning * into v_demand;

  update public.product_requests
  set demand_id = v_demand.id,
      status = 'published',
      updated_at = now()
  where id = v_request.id;

  return jsonb_build_object(
    'requestId', v_request.id,
    'demandId', v_demand.id,
    'status', 'published'
  );
end;
$$;

revoke all on function public.dt_publish_product_request(uuid, uuid) from public;
grant execute on function public.dt_publish_product_request(uuid, uuid) to authenticated;