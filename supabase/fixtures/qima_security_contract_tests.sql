-- QIMA local fixture assertions
-- Run ONLY after supabase/fixtures/qima_security_contract.sql on the disposable local database.
-- This file is a test script, not a production migration. It rolls back all changes.
begin;

do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'qima_security_fixture') then
    raise exception 'Fixture missing: apply qima_security_contract.sql to LOCAL database first';
  end if;
  if (select count(*) from qima_security_fixture.memberships) < 2 then
    raise exception 'Expected synthetic tenant memberships A/B';
  end if;
  if has_schema_privilege('anon', 'qima_security_fixture', 'USAGE') then
    raise exception 'Anonymous role unexpectedly has fixture schema access';
  end if;
  if has_table_privilege('anon', 'qima_security_fixture.sessions', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.observations', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.transitions', 'SELECT')
     or has_table_privilege('anon', 'qima_security_fixture.product_requests', 'SELECT') then
    raise exception 'Anonymous role unexpectedly has fixture table read privileges';
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

-- Test RLS visibility as User A.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);

do $$
declare n integer;
begin
  select count(*) into n from qima_security_fixture.sessions;
  if n <> 1 then raise exception 'User A expected exactly 1 visible session, got %', n; end if;
  select count(*) into n from qima_security_fixture.observations;
  if n <> 1 then raise exception 'User A expected exactly 1 visible observation, got %', n; end if;
  select count(*) into n from qima_security_fixture.transitions;
  if n <> 1 then raise exception 'User A expected exactly 1 visible transition, got %', n; end if;
  select count(*) into n from qima_security_fixture.product_requests;
  if n <> 1 then raise exception 'User A expected exactly 1 own product request, got %', n; end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
set local role authenticated;

do $$
declare n integer;
begin
  select count(*) into n from qima_security_fixture.sessions;
  if n <> 1 then raise exception 'User B expected exactly 1 visible session, got %', n; end if;
  select count(*) into n from qima_security_fixture.observations;
  if n <> 1 then raise exception 'User B expected exactly 1 visible observation, got %', n; end if;
  select count(*) into n from qima_security_fixture.transitions;
  if n <> 1 then raise exception 'User B expected exactly 1 visible transition, got %', n; end if;
  select count(*) into n from qima_security_fixture.product_requests;
  if n <> 1 then raise exception 'User B expected exactly 1 own product request, got %', n; end if;
end $$;

rollback;
