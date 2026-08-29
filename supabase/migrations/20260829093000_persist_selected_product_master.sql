alter table public.dt_sessions
  add column if not exists selected_product_master_id uuid references public.product_masters(id) on delete restrict;

create index if not exists dt_sessions_selected_product_master_idx
  on public.dt_sessions(selected_product_master_id);

create or replace function public.dt_select_product_master(
  p_session_id uuid,
  p_user_id uuid,
  p_product_master_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_session public.dt_sessions%rowtype;
  v_product public.product_masters%rowtype;
begin
  select * into v_session
  from public.dt_sessions
  where id = p_session_id and user_id = p_user_id
  for update;

  if not found then raise exception 'SESSION_NOT_FOUND'; end if;

  select * into v_product
  from public.product_masters
  where id = p_product_master_id and status = 'active';

  if not found then raise exception 'PRODUCT_MASTER_NOT_FOUND'; end if;

  if not exists (
    select 1 from public.dt_nodes n
    where n.id = v_session.current_node_id
      and n.canonical_subcategory_id = v_product.subcategory_id
  ) then
    raise exception 'PRODUCT_MASTER_NOT_IN_CLASSIFICATION';
  end if;

  update public.dt_sessions
  set selected_product_master_id = v_product.id,
      status = 'completed',
      updated_at = now()
  where id = v_session.id;

  return jsonb_build_object(
    'sessionId', v_session.id,
    'productMasterId', v_product.id,
    'productMasterCode', v_product.code,
    'status', 'completed'
  );
end;
$$;

grant execute on function public.dt_select_product_master(uuid, uuid, uuid) to authenticated;
