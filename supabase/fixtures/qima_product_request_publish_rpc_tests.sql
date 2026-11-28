-- Exercises the actual migration function against a disposable two-tenant schema.

-- Verify the migration's EXECUTE boundary before exercising the RPC.
-- has_function_privilege includes privileges inherited through PUBLIC.
do $$
begin
  if not has_function_privilege(
    'authenticated',
    'public.dt_publish_product_request(uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception 'authenticated role cannot execute the product-request publish RPC';
  end if;

  if has_function_privilege(
    'anon',
    'public.dt_publish_product_request(uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception 'anon role unexpectedly inherits EXECUTE on the product-request publish RPC';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '', false);
set role authenticated;

do $q$
declare
  v_denied boolean := false;
begin
  begin
    perform public.dt_publish_product_request(
      '55555555-5555-4555-8555-555555555555',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    );
  exception when others then
    if sqlerrm = 'UNAUTHENTICATED' then
      v_denied := true;
    else
      raise;
    end if;
  end;

  if not v_denied then
    raise exception 'publish RPC accepted a caller with a null authenticated subject';
  end if;
end;
$q$;

reset role;

do $q$
begin
  if (select count(*) from public.demands) <> 0 then
    raise exception 'unauthenticated publish unexpectedly created a demand';
  end if;
  if (select status from public.product_requests where id = '55555555-5555-4555-8555-555555555555') <> 'draft' then
    raise exception 'unauthenticated publish unexpectedly changed request status';
  end if;
end;
$q$;

select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false);
set role authenticated;

do $$
declare
  v_denied boolean := false;
begin
  begin
    perform public.dt_publish_product_request(
      '55555555-5555-4555-8555-555555555555',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    );
  exception when others then
    if sqlerrm = 'UNAUTHENTICATED' then
      v_denied := true;
    else
      raise;
    end if;
  end;

  if not v_denied then
    raise exception 'publish RPC accepted a caller-supplied user id that differs from auth.uid()';
  end if;
end;
$$;

reset role;

do $$
begin
  if (select count(*) from public.demands) <> 0 then
    raise exception 'mismatched user-id publish unexpectedly created a demand';
  end if;
  if (select status from public.product_requests where id = '55555555-5555-4555-8555-555555555555') <> 'draft' then
    raise exception 'mismatched user-id publish unexpectedly changed request status';
  end if;
end;
$$;

set role authenticated;

do $$
declare
  v_denied boolean := false;
begin
  begin
    perform public.dt_publish_product_request(
      '55555555-5555-4555-8555-555555555555',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    );
  exception when others then
    if sqlerrm = 'PRODUCT_REQUEST_NOT_FOUND' then
      v_denied := true;
    else
      raise;
    end if;
  end;

  if not v_denied then
    raise exception 'publish RPC accepted a request from a tenant with no current membership';
  end if;
end;
$$;

reset role;

do $$
begin
  if (select count(*) from public.demands) <> 0 then
    raise exception 'denied cross-tenant publish unexpectedly created a demand';
  end if;
  if (select status from public.product_requests where id = '55555555-5555-4555-8555-555555555555') <> 'draft' then
    raise exception 'denied cross-tenant publish unexpectedly changed request status';
  end if;
end;
$$;

-- Membership in the correct tenant is not sufficient when the request belongs to another user.
insert into public.dt_memberships (tenant_id, user_id, role) values
  ('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'member');

select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', false);
set role authenticated;

do $q$
declare
  v_denied boolean := false;
begin
  begin
    perform public.dt_publish_product_request(
      '55555555-5555-4555-8555-555555555555',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    );
  exception when others then
    if sqlerrm = 'PRODUCT_REQUEST_NOT_FOUND' then
      v_denied := true;
    else
      raise;
    end if;
  end;

  if not v_denied then
    raise exception 'tenant member published a request owned by a different user';
  end if;
end;
$q$;

reset role;

do $q$
begin
  if (select count(*) from public.demands) <> 0 then
    raise exception 'non-owner tenant member unexpectedly created a demand';
  end if;
  if (select status from public.product_requests where id = '55555555-5555-4555-8555-555555555555') <> 'draft' then
    raise exception 'non-owner tenant member unexpectedly changed request status';
  end if;
end;
$q$;

delete from public.dt_memberships
where tenant_id = '11111111-1111-4111-8111-111111111111'
  and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

-- Restore membership in the request's exact tenant; the same owner can now publish.
insert into public.dt_memberships (tenant_id, user_id, role) values
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'member');

select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false);
set role authenticated;

do $$
declare
  v_result jsonb;
begin
  v_result := public.dt_publish_product_request(
    '55555555-5555-4555-8555-555555555555',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  );
  if v_result ->> 'status' <> 'published' then
    raise exception 'member publish did not return published status: %', v_result;
  end if;
end;
$$;

reset role;

do $$
begin
  if (select count(*) from public.demands) <> 1 then
    raise exception 'authorized publish did not create exactly one demand';
  end if;
  if (select status from public.product_requests where id = '55555555-5555-4555-8555-555555555555') <> 'published' then
    raise exception 'authorized publish did not update request status';
  end if;
end;
$$;

select 'PASS: publish RPC ACL and tenant-specific membership are enforced by the migration' as result;
