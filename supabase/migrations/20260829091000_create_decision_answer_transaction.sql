create or replace function public.dt_submit_answer(
  p_session_id uuid,
  p_user_id uuid,
  p_expected_revision integer,
  p_node_id uuid,
  p_field text,
  p_value text,
  p_client_command_id uuid,
  p_rule_id uuid,
  p_target_node_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_session public.dt_sessions%rowtype;
  v_observation public.dt_observations%rowtype;
  v_transition public.dt_transitions%rowtype;
  v_next_revision integer;
begin
  select * into v_session
  from public.dt_sessions
  where id = p_session_id and user_id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'SESSION_NOT_FOUND';
  end if;

  select * into v_observation
  from public.dt_observations
  where session_id = p_session_id and client_command_id = p_client_command_id;

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

  v_next_revision := p_expected_revision + 1;

  insert into public.dt_observations (
    tenant_id, session_id, node_id, field, value, client_command_id
  ) values (
    v_session.tenant_id, p_session_id, p_node_id, p_field, to_jsonb(p_value), p_client_command_id
  ) returning * into v_observation;

  update public.dt_sessions
  set current_node_id = p_target_node_id,
      revision = v_next_revision,
      updated_at = now()
  where id = p_session_id and user_id = p_user_id and revision = p_expected_revision;

  if not found then
    raise exception using errcode = '40001', message = 'CONCURRENCY_CONFLICT';
  end if;

  insert into public.dt_transitions (
    tenant_id, session_id, observation_id, rule_id,
    from_node_id, to_node_id, from_revision, to_revision
  ) values (
    v_session.tenant_id, p_session_id, v_observation.id, p_rule_id,
    p_node_id, p_target_node_id, p_expected_revision, v_next_revision
  ) returning * into v_transition;

  return jsonb_build_object(
    'duplicate', false,
    'observationId', v_observation.id,
    'revision', v_next_revision,
    'currentNodeId', p_target_node_id
  );
end;
$$;

revoke all on function public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid, uuid, uuid) from public;
grant execute on function public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid, uuid, uuid) to authenticated;
