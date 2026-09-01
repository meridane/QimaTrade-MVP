-- Security Gate v1: make Decision Tree answer persistence server-authoritative.
-- The client submits only the observation. The database derives the rule and target node.

begin;

-- Remove the previous client-authoritative overload.
drop function if exists public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid, uuid, uuid);

create or replace function public.dt_submit_answer(
  p_session_id uuid,
  p_user_id uuid,
  p_expected_revision integer,
  p_node_id uuid,
  p_field text,
  p_value text,
  p_client_command_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.dt_sessions%rowtype;
  v_observation public.dt_observations%rowtype;
  v_transition public.dt_transitions%rowtype;
  v_next_revision integer;
  v_rule public.dt_rules%rowtype;
  v_target_node_id uuid;
  v_tree_id uuid;
  v_membership_exists boolean;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception using errcode = '42501', message = 'UNAUTHENTICATED';
  end if;

  if p_field not in ('category', 'subcategory') then
    raise exception using errcode = 'P0001', message = 'INVALID_FIELD';
  end if;

  if p_value is null or btrim(p_value) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_VALUE';
  end if;

  select exists (
    select 1
    from public.dt_memberships m
    where m.tenant_id = s.tenant_id
      and m.user_id = p_user_id
  ) into v_membership_exists
  from public.dt_sessions s
  where s.id = p_session_id;

  if not coalesce(v_membership_exists, false) then
    raise exception using errcode = 'P0002', message = 'SESSION_NOT_FOUND';
  end if;

  select * into v_session
  from public.dt_sessions
  where id = p_session_id
    and user_id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'SESSION_NOT_FOUND';
  end if;

  if v_session.status <> 'active' then
    raise exception using errcode = 'P0001', message = 'SESSION_NOT_ACTIVE';
  end if;

  -- Idempotency is checked before the revision check so a retried command
  -- returns the original result even if the session revision has advanced.
  select * into v_observation
  from public.dt_observations
  where session_id = p_session_id
    and client_command_id = p_client_command_id;

  if found then
    select * into v_transition
    from public.dt_transitions
    where observation_id = v_observation.id
    order by created_at desc
    limit 1;

    return jsonb_build_object(
      'duplicate', true,
      'observationId', v_observation.id,
      'revision', coalesce(v_transition.to_revision, v_session.revision),
      'currentNodeId', coalesce(v_transition.to_node_id, v_session.current_node_id)
    );
  end if;

  if v_session.revision <> p_expected_revision then
    raise exception using errcode = '40001', message = 'CONCURRENCY_CONFLICT';
  end if;

  if v_session.current_node_id <> p_node_id then
    raise exception using errcode = 'P0001', message = 'CURRENT_NODE_CONFLICT';
  end if;

  -- The node must belong to the exact published version used by the session.
  if not exists (
    select 1
    from public.dt_nodes n
    where n.id = p_node_id
      and n.tree_version_id = v_session.tree_version_id
  ) then
    raise exception using errcode = 'P0001', message = 'NODE_VERSION_MISMATCH';
  end if;

  -- Resolve the transition canonically from the stored rules. The client is
  -- not allowed to provide rule_id or target_node_id anymore.
  select r.* into v_rule
  from public.dt_rules r
  where r.tree_version_id = v_session.tree_version_id
    and r.source_node_id = p_node_id
    and r.field = p_field
    and r.operator = 'equals'
    and r.value = p_value
  order by r.priority asc, r.id asc
  limit 1;

  if not found then
    raise exception using errcode = 'P0001', message = 'NO_VALID_TRANSITION';
  end if;

  select r.target_node_id into v_target_node_id
  from public.dt_rules r
  where r.id = v_rule.id
    and exists (
      select 1 from public.dt_nodes n
      where n.id = r.target_node_id
        and n.tree_version_id = v_session.tree_version_id
    );

  if v_target_node_id is null then
    raise exception using errcode = 'P0001', message = 'TARGET_NODE_VERSION_MISMATCH';
  end if;

  -- Ensure the session really belongs to the tenant of its tree/version.
  select t.id into v_tree_id
  from public.dt_tree_versions v
  join public.dt_trees t on t.id = v.tree_id
  where v.id = v_session.tree_version_id
    and t.tenant_id = v_session.tenant_id;

  if v_tree_id is null then
    raise exception using errcode = 'P0001', message = 'TREE_TENANT_MISMATCH';
  end if;

  v_next_revision := p_expected_revision + 1;

  insert into public.dt_observations (
    tenant_id, session_id, node_id, field, value, client_command_id
  ) values (
    v_session.tenant_id,
    p_session_id,
    p_node_id,
    p_field,
    to_jsonb(p_value),
    p_client_command_id
  ) returning * into v_observation;

  update public.dt_sessions
  set current_node_id = v_target_node_id,
      revision = v_next_revision,
      updated_at = now()
  where id = p_session_id
    and user_id = p_user_id
    and revision = p_expected_revision
    and status = 'active';

  if not found then
    raise exception using errcode = '40001', message = 'CONCURRENCY_CONFLICT';
  end if;

  insert into public.dt_transitions (
    tenant_id, session_id, observation_id, rule_id,
    from_node_id, to_node_id, from_revision, to_revision
  ) values (
    v_session.tenant_id,
    p_session_id,
    v_observation.id,
    v_rule.id,
    p_node_id,
    v_target_node_id,
    p_expected_revision,
    v_next_revision
  ) returning * into v_transition;

  return jsonb_build_object(
    'duplicate', false,
    'observationId', v_observation.id,
    'revision', v_next_revision,
    'currentNodeId', v_target_node_id
  );
exception
  when unique_violation then
    -- Covers a race on the idempotency key. The caller can safely retry.
    raise exception using errcode = '40001', message = 'CONCURRENCY_CONFLICT';
end;
$$;

revoke all on function public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid) from public;
grant execute on function public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid) to authenticated;

-- Configuration tables are readable by authenticated members but are not
-- writable by normal users. Runtime state remains user-scoped.
drop policy if exists dt_trees_all on public.dt_trees;
drop policy if exists dt_tree_versions_all on public.dt_tree_versions;
drop policy if exists dt_nodes_all on public.dt_nodes;
drop policy if exists dt_rules_all on public.dt_rules;

drop policy if exists dt_trees_select on public.dt_trees;
create policy dt_trees_select on public.dt_trees for select to authenticated
  using (public.dt_has_tenant_access(tenant_id));

drop policy if exists dt_tree_versions_select on public.dt_tree_versions;
create policy dt_tree_versions_select on public.dt_tree_versions for select to authenticated
  using (exists (
    select 1 from public.dt_trees t
    where t.id = tree_id and public.dt_has_tenant_access(t.tenant_id)
  ));

drop policy if exists dt_nodes_select on public.dt_nodes;
create policy dt_nodes_select on public.dt_nodes for select to authenticated
  using (exists (
    select 1
    from public.dt_tree_versions v
    join public.dt_trees t on t.id = v.tree_id
    where v.id = tree_version_id and public.dt_has_tenant_access(t.tenant_id)
  ));

drop policy if exists dt_rules_select on public.dt_rules;
create policy dt_rules_select on public.dt_rules for select to authenticated
  using (exists (
    select 1
    from public.dt_tree_versions v
    join public.dt_trees t on t.id = v.tree_id
    where v.id = tree_version_id and public.dt_has_tenant_access(t.tenant_id)
  ));

-- Runtime history is append-only for authenticated users: no UPDATE/DELETE.
drop policy if exists dt_observations_all on public.dt_observations;
drop policy if exists dt_observations_select on public.dt_observations;
create policy dt_observations_select on public.dt_observations for select to authenticated
  using (
    public.dt_has_tenant_access(tenant_id)
    and exists (
      select 1 from public.dt_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

-- Inserts are performed by the SECURITY DEFINER RPC only.
drop policy if exists dt_observations_insert on public.dt_observations;

revoke insert, update, delete on public.dt_observations from authenticated;
revoke insert, update, delete on public.dt_transitions from authenticated;

commit;
