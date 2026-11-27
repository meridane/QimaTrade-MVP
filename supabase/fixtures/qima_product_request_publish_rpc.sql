-- Disposable PostgreSQL fixture for the real product-request publish RPC migration.
-- Synthetic users and tenants only. Never apply this file to Supabase Cloud.

create extension if not exists pgcrypto;

create table public.dt_tenants (
  id uuid primary key,
  name text not null
);

create table public.dt_memberships (
  tenant_id uuid not null,
  user_id uuid not null,
  role text not null default 'member',
  primary key (tenant_id, user_id)
);

create table public.product_requests (
  id uuid primary key,
  tenant_id uuid not null,
  user_id uuid not null,
  decision_session_id uuid not null,
  product_master_id uuid not null,
  title text not null,
  description text,
  quantity numeric(18,3),
  unit text,
  status text not null default 'draft',
  demand_id uuid,
  updated_at timestamptz not null default now()
);

create table public.product_masters (
  id uuid primary key,
  status text not null,
  subcategory_id uuid,
  code text not null,
  canonical_name text not null
);

create table public.profiles (
  auth_user_id uuid not null,
  actor_id uuid not null
);

create table public.demands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  demand_status text not null,
  documentation_status text not null,
  quantity numeric(18,3),
  scope jsonb not null,
  source text not null,
  requester_actor_id uuid not null
);

create table public.categories (
  id uuid primary key,
  name text not null
);

create table public.subcategories (
  id uuid primary key,
  category_id uuid not null,
  name text not null
);

-- Model an explicit pre-existing anon grant. CREATE OR REPLACE preserves ACLs,
-- so the hardening migration must revoke this grant explicitly.
create or replace function public.dt_publish_product_request(p_request_id uuid, p_user_id uuid)
returns jsonb
language sql
as $
  select '{}'::jsonb
$;
grant execute on function public.dt_publish_product_request(uuid, uuid) to anon;

alter table public.product_requests enable row level security;
create policy product_requests_select_own_tenant on public.product_requests
  for select to authenticated
  using (
    exists (
      select 1 from public.dt_memberships m
      where m.tenant_id = product_requests.tenant_id
        and m.user_id = auth.uid()
    )
  );

insert into public.dt_tenants (id, name) values
  ('11111111-1111-4111-8111-111111111111', 'Tenant A'),
  ('22222222-2222-4222-8222-222222222222', 'Tenant B');

-- User A belongs to Tenant B only. The owned request remains in Tenant A,
-- modeling a revoked Tenant A membership while another membership survives.
insert into public.dt_memberships (tenant_id, user_id, role) values
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'member');

insert into public.product_masters (id, status, subcategory_id, code, canonical_name) values
  ('33333333-3333-4333-8333-333333333333', 'active', null, 'SYNTH-001', 'Synthetic Product');

insert into public.profiles (auth_user_id, actor_id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '44444444-4444-4444-8444-444444444444');

insert into public.product_requests (
  id, tenant_id, user_id, decision_session_id, product_master_id, title, quantity, unit
) values (
  '55555555-5555-4555-8555-555555555555',
  '11111111-1111-4111-8111-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '66666666-6666-4666-8666-666666666666',
  '33333333-3333-4333-8333-333333333333',
  'Synthetic request',
  1,
  'pcs'
);
