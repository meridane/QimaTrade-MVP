-- QIMA local fixture assertions
-- Run ONLY after supabase/fixtures/qima_security_contract.sql on the disposable local database.
-- This file is a test script, not a production migration. It rolls back all changes.
begin;

do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'qima_security_fixture') then
    raise exception 'Fixture missing: apply qima_security_contract.sql to LOCAL database first';
  end if;
  if (select count(*) from qima_security_fixture.memberships) <> 2 then
    raise exception 'Expected exactly two synthetic tenant memberships A/B';
  end if;
  if (select count(*) from qima_security_fixture.sessions) <> 2 then
    raise exception 'Expected exactly two synthetic tenant sessions A/B';
  end if;
  if (select count(*) from qima_security_fixture.observations) <> 2 then
    raise exception 'Expected exactly two synthetic tenant observations A/B';
  end if;
  if (select count(*) from qima_security_fixture.transitions) <> 2 then
    raise exception 'Expected exactly two synthetic tenant transitions A/B';
  end if;
  if (select count(*) from qima_security_fixture.product_requests) <> 2 then
    raise exception 'Expected exactly two synthetic tenant product requests A/B';
  end if;
  if has_schema_privilege('anon', 'qima_security_fixture', 'USAGE') then
    raise exception 'Anonymous role unexpectedly has fixture schema access';
  end if;
  if has_table_privilege('anon', 'qima_security_fixture.memberships', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.sessions', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.observations', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.transitions', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.product_requests', 'SELECT') then
    raise exception 'Anonymous role unexpectedly has fixture table read privileges';
  end if;
  if has_table_privilege('authenticated', 'qima_security_fixture.memberships', 'INSERT')
     or has_table_privilege('authenticated', 'qima_security_fixture.memberships', 'UPDATE')
     or has_table_privilege('authenticated', 'qima_security_fixture.memberships', 'DELETE') then
    raise exception 'Authenticated role unexpectedly has direct membership write privileges';
  end if;
  if has_table_privilege('authenticated', 'qima_security_fixture.sessions', 'INSERT')
     or has_table_privilege('authenticated', 'qima_security_fixture.sessions', 'UPDATE')
     or has_table_privilege('authenticated', 'qima_security_fixture.sessions', 'DELETE') then
    raise exception 'Authenticated role unexpectedly has direct session write privileges';
  end if;
  if has_table_privilege('authenticated', 'qima_security_fixture.observations', 'INSERT')
     or has_table_privilege('authenticated', 'qima_security_fixture.observations', 'UPDATE')
     or has_table_privilege('authenticated', 'qima_security_fixture.observations', 'DELETE') then
    raise exception 'Authenticated role unexpectedly has direct observation write privileges';
  end if;
  if has_table_privilege('authenticated', 'qima_security_fixture.transitions', 'INSERT')
     or has_table_privilege('authenticated', 'qima_security_fixture.transitions', 'UPDATE')
     or has_table_privilege('authenticated', 'qima_security_fixture.transitions', 'DELETE') then
    raise exception 'Authenticated role unexpectedly has direct transition write privileges';
  end if;
  if has_table_privilege('authenticated', 'qima_security_fixture.product_requests', 'INSERT')
     or has_table_privilege('authenticated', 'qima_security_fixture.product_requests', 'UPDATE')
     or has_table_privilege('authenticated', 'qima_security_fixture.product_requests', 'DELETE') then
    raise exception 'Authenticated role unexpectedly has direct product-request write privileges';
  end if;
end $$;

-- Exercise real anonymous reads, not only catalog privilege metadata.
-- A successful zero-row SELECT is not sufficient: each statement must be denied.
set local role anon;
do $qima$
declare
  v_query text;
begin
  foreach v_query in array array[
    'select * from qima_security_fixture.memberships',
    'select * from qima_security_fixture.sessions',
    'select * from qima_security_fixture.observations',
    'select * from qima_security_fixture.transitions',
    'select * from qima_security_fixture.product_requests'
  ] loop
    begin
      execute v_query;
      raise exception 'Anonymous SELECT unexpectedly succeeded: %', v_query;
    exception
      when insufficient_privilege then
        null;
    end;
  end loop;
end $qima$;
reset role;

-- Exercise actual authenticated client writes, not only ACL catalog metadata.
-- Every operation must be rejected; the surrounding transaction is rolled back below.
set local role authenticated;
do $qima_dml$
declare
  v_query text;
begin
  foreach v_query in array array[
    'insert into qima_security_fixture.memberships (user_id, tenant_id, role) values (''cccccccc-cccc-4ccc-8ccc-cccccccccccc'', ''33333333-3333-4333-8333-333333333333'', ''member'')',
    'update qima_security_fixture.memberships set role = role where user_id = ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa''::uuid',
    'delete from qima_security_fixture.memberships where user_id = ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa''::uuid',
    'insert into qima_security_fixture.sessions (id, tenant_id, owner_user_id) values (''cccccccc-0000-4000-8000-000000000001'', ''11111111-1111-4111-8111-111111111111'', ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'')',
    'update qima_security_fixture.sessions set status = status where id = ''aaaaaaaa-0000-4000-8000-000000000001''::uuid',
    'delete from qima_security_fixture.sessions where id = ''aaaaaaaa-0000-4000-8000-000000000001''::uuid',
    'insert into qima_security_fixture.observations (id, tenant_id, session_id, actor_user_id, payload) values (''cccccccc-0000-4000-8000-000000000011'', ''11111111-1111-4111-8111-111111111111'', ''aaaaaaaa-0000-4000-8000-000000000001'', ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'', ''{}''::jsonb)',
    'update qima_security_fixture.observations set payload = payload where id = ''aaaaaaaa-0000-4000-8000-000000000011''::uuid',
    'delete from qima_security_fixture.observations where id = ''aaaaaaaa-0000-4000-8000-000000000011''::uuid',
    'insert into qima_security_fixture.transitions (id, tenant_id, session_id, from_node, to_node) values (''cccccccc-0000-4000-8000-000000000111'', ''11111111-1111-4111-8111-111111111111'', ''aaaaaaaa-0000-4000-8000-000000000001'', ''start'', ''next'')',
    'update qima_security_fixture.transitions set to_node = to_node where id = ''aaaaaaaa-0000-4000-8000-000000000111''::uuid',
    'delete from qima_security_fixture.transitions where id = ''aaaaaaaa-0000-4000-8000-000000000111''::uuid',
    'insert into qima_security_fixture.product_requests (id, tenant_id, requester_user_id) values (''cccccccc-0000-4000-8000-000000000222'', ''11111111-1111-4111-8111-111111111111'', ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'')',
    'update qima_security_fixture.product_requests set status = status where id = ''aaaaaaaa-0000-4000-8000-000000000111''::uuid',
    'delete from qima_security_fixture.product_requests where id = ''aaaaaaaa-0000-4000-8000-000000000111''::uuid'
  ] loop
    begin
      execute v_query;
      raise exception 'Authenticated direct DML unexpectedly succeeded: %', v_query;
    exception
      when insufficient_privilege then
        null;
    end;
  end loop;
end $qima_dml$;
reset role;

-- Test RLS visibility as User A.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);

do $$
declare n integer;
begin
  select count(*) into n from qima_security_fixture.memberships;
  if n <> 1 then raise exception 'User A expected exactly 1 visible membership, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.memberships where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid and tenant_id = '11111111-1111-4111-8111-111111111111'::uuid
  ) then
    raise exception 'User A expected its exact own memberships row';
  end if;
  if exists (
    select 1 from qima_security_fixture.memberships where user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
  ) then
    raise exception 'User A must not see the other tenant memberships row';
  end if;
  select count(*) into n from qima_security_fixture.sessions;
  if n <> 1 then raise exception 'User A expected exactly 1 visible session, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.sessions where id = 'aaaaaaaa-0000-4000-8000-000000000001'::uuid and tenant_id = '11111111-1111-4111-8111-111111111111'::uuid and owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
  ) then
    raise exception 'User A expected its exact own sessions row';
  end if;
  if exists (
    select 1 from qima_security_fixture.sessions where id = 'bbbbbbbb-0000-4000-8000-000000000002'::uuid
  ) then
    raise exception 'User A must not see the other tenant sessions row';
  end if;
  select count(*) into n from qima_security_fixture.observations;
  if n <> 1 then raise exception 'User A expected exactly 1 visible observation, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.observations where id = 'aaaaaaaa-0000-4000-8000-000000000011'::uuid and tenant_id = '11111111-1111-4111-8111-111111111111'::uuid and session_id = 'aaaaaaaa-0000-4000-8000-000000000001'::uuid and actor_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
  ) then
    raise exception 'User A expected its exact own observations row';
  end if;
  if exists (
    select 1 from qima_security_fixture.observations where id = 'bbbbbbbb-0000-4000-8000-000000000022'::uuid
  ) then
    raise exception 'User A must not see the other tenant observations row';
  end if;
  select count(*) into n from qima_security_fixture.transitions;
  if n <> 1 then raise exception 'User A expected exactly 1 visible transition, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.transitions where id = 'aaaaaaaa-0000-4000-8000-000000000111'::uuid and tenant_id = '11111111-1111-4111-8111-111111111111'::uuid and session_id = 'aaaaaaaa-0000-4000-8000-000000000001'::uuid
  ) then
    raise exception 'User A expected its exact own transitions row';
  end if;
  if exists (
    select 1 from qima_security_fixture.transitions where id = 'bbbbbbbb-0000-4000-8000-000000000222'::uuid
  ) then
    raise exception 'User A must not see the other tenant transitions row';
  end if;
  select count(*) into n from qima_security_fixture.product_requests;
  if n <> 1 then raise exception 'User A expected exactly 1 own product request, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.product_requests where id = 'aaaaaaaa-0000-4000-8000-000000000111'::uuid and tenant_id = '11111111-1111-4111-8111-111111111111'::uuid and requester_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
  ) then
    raise exception 'User A expected its exact own product requests row';
  end if;
  if exists (
    select 1 from qima_security_fixture.product_requests where id = 'bbbbbbbb-0000-4000-8000-000000000222'::uuid
  ) then
    raise exception 'User A must not see the other tenant product requests row';
  end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
set local role authenticated;

do $$
declare n integer;
begin
  select count(*) into n from qima_security_fixture.memberships;
  if n <> 1 then raise exception 'User B expected exactly 1 visible membership, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.memberships where user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid and tenant_id = '22222222-2222-4222-8222-222222222222'::uuid
  ) then
    raise exception 'User B expected its exact own memberships row';
  end if;
  if exists (
    select 1 from qima_security_fixture.memberships where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
  ) then
    raise exception 'User B must not see the other tenant memberships row';
  end if;
  select count(*) into n from qima_security_fixture.sessions;
  if n <> 1 then raise exception 'User B expected exactly 1 visible session, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.sessions where id = 'bbbbbbbb-0000-4000-8000-000000000002'::uuid and tenant_id = '22222222-2222-4222-8222-222222222222'::uuid and owner_user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
  ) then
    raise exception 'User B expected its exact own sessions row';
  end if;
  if exists (
    select 1 from qima_security_fixture.sessions where id = 'aaaaaaaa-0000-4000-8000-000000000001'::uuid
  ) then
    raise exception 'User B must not see the other tenant sessions row';
  end if;
  select count(*) into n from qima_security_fixture.observations;
  if n <> 1 then raise exception 'User B expected exactly 1 visible observation, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.observations where id = 'bbbbbbbb-0000-4000-8000-000000000022'::uuid and tenant_id = '22222222-2222-4222-8222-222222222222'::uuid and session_id = 'bbbbbbbb-0000-4000-8000-000000000002'::uuid and actor_user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
  ) then
    raise exception 'User B expected its exact own observations row';
  end if;
  if exists (
    select 1 from qima_security_fixture.observations where id = 'aaaaaaaa-0000-4000-8000-000000000011'::uuid
  ) then
    raise exception 'User B must not see the other tenant observations row';
  end if;
  select count(*) into n from qima_security_fixture.transitions;
  if n <> 1 then raise exception 'User B expected exactly 1 visible transition, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.transitions where id = 'bbbbbbbb-0000-4000-8000-000000000222'::uuid and tenant_id = '22222222-2222-4222-8222-222222222222'::uuid and session_id = 'bbbbbbbb-0000-4000-8000-000000000002'::uuid
  ) then
    raise exception 'User B expected its exact own transitions row';
  end if;
  if exists (
    select 1 from qima_security_fixture.transitions where id = 'aaaaaaaa-0000-4000-8000-000000000111'::uuid
  ) then
    raise exception 'User B must not see the other tenant transitions row';
  end if;
  select count(*) into n from qima_security_fixture.product_requests;
  if n <> 1 then raise exception 'User B expected exactly 1 own product request, got %', n; end if;
  if not exists (
    select 1 from qima_security_fixture.product_requests where id = 'bbbbbbbb-0000-4000-8000-000000000222'::uuid and tenant_id = '22222222-2222-4222-8222-222222222222'::uuid and requester_user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
  ) then
    raise exception 'User B expected its exact own product requests row';
  end if;
  if exists (
    select 1 from qima_security_fixture.product_requests where id = 'aaaaaaaa-0000-4000-8000-000000000111'::uuid
  ) then
    raise exception 'User B must not see the other tenant product requests row';
  end if;
end $$;

rollback;
