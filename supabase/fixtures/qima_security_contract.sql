-- QIMA isolated security-contract fixture
-- PURPOSE: exercise expected RLS/tenant-isolation contracts in a disposable local Supabase instance.
-- NOT a production schema dump, NOT a migration for production, and NOT proof of deployed behavior.
-- Run only against local Supabase after reviewing the file. It creates objects in qima_security_fixture.
-- Synthetic identities/tenants only. No production data or credentials.

begin;

create schema if not exists qima_security_fixture;
revoke all on schema qima_security_fixture from public;
grant usage on schema qima_security_fixture to authenticated;

create table if not exists qima_security_fixture.memberships (
  user_id uuid not null,
  tenant_id uuid not null,
  role text not null default 'member',
  primary key (user_id, tenant_id)
);

create table if not exists qima_security_fixture.sessions (
  id uuid primary key,
  tenant_id uuid not null,
  owner_user_id uuid not null,
  status text not null default 'active',
  revision integer not null default 0 check (revision >= 0),
  current_node_id text not null default 'start',
  created_at timestamptz not null default now()
);

create table if not exists qima_security_fixture.observations (
  id uuid primary key,
  tenant_id uuid not null,
  session_id uuid not null references qima_security_fixture.sessions(id),
  actor_user_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists qima_security_fixture.transitions (
  id uuid primary key,
  tenant_id uuid not null,
  session_id uuid not null references qima_security_fixture.sessions(id),
  from_node text not null,
  to_node text not null,
  created_at timestamptz not null default now()
);

create table if not exists qima_security_fixture.product_requests (
  id uuid primary key,
  tenant_id uuid not null,
  requester_user_id uuid not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

alter table qima_security_fixture.memberships enable row level security;
alter table qima_security_fixture.sessions enable row level security;
alter table qima_security_fixture.observations enable row level security;
alter table qima_security_fixture.transitions enable row level security;
alter table qima_security_fixture.product_requests enable row level security;

-- Membership rows are visible only to their own user.
drop policy if exists memberships_read_self on qima_security_fixture.memberships;
create policy memberships_read_self on qima_security_fixture.memberships
  for select to authenticated using (user_id = (select auth.uid()));

-- A user may read sessions only if they own the session and have membership in its tenant.
drop policy if exists sessions_read_member on qima_security_fixture.sessions;
create policy sessions_read_member on qima_security_fixture.sessions
  for select to authenticated using (
    owner_user_id = (select auth.uid())
    and exists (
      select 1 from qima_security_fixture.memberships m
      where m.user_id = (select auth.uid()) and m.tenant_id = sessions.tenant_id
    )
  );

-- History is read-only to clients. Mutations should occur only through a separately reviewed,
-- narrowly scoped RPC in the actual application. This fixture deliberately defines no DML policies.
drop policy if exists observations_read_member on qima_security_fixture.observations;
create policy observations_read_member on qima_security_fixture.observations
  for select to authenticated using (
    exists (
      select 1 from qima_security_fixture.memberships m
      where m.user_id = (select auth.uid()) and m.tenant_id = observations.tenant_id
    )
  );

drop policy if exists transitions_read_member on qima_security_fixture.transitions;
create policy transitions_read_member on qima_security_fixture.transitions
  for select to authenticated using (
    exists (
      select 1 from qima_security_fixture.memberships m
      where m.user_id = (select auth.uid()) and m.tenant_id = transitions.tenant_id
    )
  );

drop policy if exists product_requests_read_own_tenant on qima_security_fixture.product_requests;
create policy product_requests_read_own_tenant on qima_security_fixture.product_requests
  for select to authenticated using (
    requester_user_id = (select auth.uid())
    and exists (
      select 1 from qima_security_fixture.memberships m
      where m.user_id = (select auth.uid()) and m.tenant_id = product_requests.tenant_id
    )
  );

-- Explicit client grants: read-only contract for this fixture.
revoke all on all tables in schema qima_security_fixture from anon, authenticated;
grant select on all tables in schema qima_security_fixture to authenticated;

-- Synthetic test data: users A/B and tenants A/B.
insert into qima_security_fixture.memberships (user_id, tenant_id, role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'member'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'member')
on conflict do nothing;

insert into qima_security_fixture.sessions
 (id, tenant_id, owner_user_id, status, revision, current_node_id) values
 ('aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'active', 0, 'start'),
 ('bbbbbbbb-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'active', 0, 'start')
on conflict do nothing;

insert into qima_security_fixture.observations (id, tenant_id, session_id, actor_user_id, payload) values
 ('aaaaaaaa-0000-4000-8000-000000000011', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '{"fixture":"tenant-a"}'),
 ('bbbbbbbb-0000-4000-8000-000000000022', '22222222-2222-4222-8222-222222222222', 'bbbbbbbb-0000-4000-8000-000000000002', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '{"fixture":"tenant-b"}')
on conflict do nothing;

insert into qima_security_fixture.transitions (id, tenant_id, session_id, from_node, to_node) values
 ('aaaaaaaa-0000-4000-8000-000000000111', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-0000-4000-8000-000000000001', 'start', 'next-a'),
 ('bbbbbbbb-0000-4000-8000-000000000222', '22222222-2222-4222-8222-222222222222', 'bbbbbbbb-0000-4000-8000-000000000002', 'start', 'next-b')
on conflict do nothing;

insert into qima_security_fixture.product_requests (id, tenant_id, requester_user_id, status) values
 ('aaaaaaaa-0000-4000-8000-000000000111', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'open'),
 ('bbbbbbbb-0000-4000-8000-000000000222', '22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'open')
on conflict do nothing;

commit;

-- Suggested local checks (run as authenticated with JWT subject set to synthetic User A):
-- 1. SELECT from sessions/observations/transitions/product_requests should return only tenant A rows.
-- 2. INSERT/UPDATE/DELETE on sessions, observations, transitions and product_requests should be denied
--    to authenticated by table grants (no client write privileges).
-- 3. Repeat as synthetic User B and verify only tenant B rows are visible.
-- 4. Unauthenticated/anon access should fail.
-- This fixture intentionally does not model the production Decision Tree RPC, every real table,
-- role resolution, or production function grants. Those require canonical migrations and dedicated tests.
