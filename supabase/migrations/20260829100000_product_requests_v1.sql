create table if not exists public.product_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.dt_tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  decision_session_id uuid not null references public.dt_sessions(id) on delete restrict,
  product_master_id uuid not null references public.product_masters(id) on delete restrict,
  title text not null,
  description text,
  quantity numeric(18,3),
  unit text,
  status text not null default 'draft' check (status in ('draft','published','closed')),
  created_at timestamptz not null default now()
);

create index if not exists product_requests_tenant_idx on public.product_requests(tenant_id);
create index if not exists product_requests_user_idx on public.product_requests(user_id);
create index if not exists product_requests_product_master_idx on public.product_requests(product_master_id);

alter table public.product_requests enable row level security;

create policy "product_requests_select_own_tenant" on public.product_requests
for select using (
  exists (select 1 from public.dt_memberships m where m.tenant_id = product_requests.tenant_id and m.user_id = auth.uid())
);

create policy "product_requests_insert_own_tenant" on public.product_requests
for insert with check (
  user_id = auth.uid()
  and exists (select 1 from public.dt_memberships m where m.tenant_id = product_requests.tenant_id and m.user_id = auth.uid())
);
