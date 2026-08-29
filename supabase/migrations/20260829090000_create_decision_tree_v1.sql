create extension if not exists pgcrypto;

create table if not exists public.dt_tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.dt_memberships (
  tenant_id uuid not null references public.dt_tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  created_at timestamptz not null default now(),
  primary key (tenant_id, user_id)
);

create table if not exists public.dt_trees (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.dt_tenants(id) on delete cascade,
  tree_key text not null,
  title text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, tree_key)
);

create table if not exists public.dt_tree_versions (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.dt_trees(id) on delete cascade,
  version text not null,
  status text not null check (status in ('draft','published','archived')),
  entry_node_id uuid,
  created_at timestamptz not null default now(),
  published_at timestamptz,
  unique (tree_id, version)
);

create table if not exists public.dt_nodes (
  id uuid primary key default gen_random_uuid(),
  tree_version_id uuid not null references public.dt_tree_versions(id) on delete cascade,
  node_key text not null,
  kind text not null check (kind in ('category','subcategory','terminal')),
  title text not null,
  description text not null default '',
  image_url text not null default '',
  created_at timestamptz not null default now(),
  unique (tree_version_id, node_key)
);

alter table public.dt_tree_versions
  drop constraint if exists dt_tree_versions_entry_node_id_fkey;
alter table public.dt_tree_versions
  add constraint dt_tree_versions_entry_node_id_fkey
  foreign key (entry_node_id) references public.dt_nodes(id) on delete restrict;

create table if not exists public.dt_rules (
  id uuid primary key default gen_random_uuid(),
  tree_version_id uuid not null references public.dt_tree_versions(id) on delete cascade,
  source_node_id uuid not null references public.dt_nodes(id) on delete cascade,
  field text not null,
  operator text not null check (operator in ('equals')),
  value text not null,
  target_node_id uuid not null references public.dt_nodes(id) on delete restrict,
  priority integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.dt_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.dt_tenants(id) on delete cascade,
  tree_version_id uuid not null references public.dt_tree_versions(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  current_node_id uuid not null references public.dt_nodes(id) on delete restrict,
  revision integer not null default 0,
  status text not null default 'active' check (status in ('active','completed','abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dt_observations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.dt_tenants(id) on delete cascade,
  session_id uuid not null references public.dt_sessions(id) on delete cascade,
  node_id uuid not null references public.dt_nodes(id) on delete restrict,
  field text not null,
  value jsonb,
  client_command_id uuid not null,
  created_at timestamptz not null default now(),
  unique (session_id, client_command_id)
);

create table if not exists public.dt_transitions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.dt_tenants(id) on delete cascade,
  session_id uuid not null references public.dt_sessions(id) on delete cascade,
  observation_id uuid not null references public.dt_observations(id) on delete cascade,
  rule_id uuid references public.dt_rules(id) on delete restrict,
  from_node_id uuid not null references public.dt_nodes(id) on delete restrict,
  to_node_id uuid not null references public.dt_nodes(id) on delete restrict,
  from_revision integer not null,
  to_revision integer not null,
  created_at timestamptz not null default now(),
  unique (session_id, to_revision)
);

create index if not exists dt_tree_versions_tree_status_idx on public.dt_tree_versions(tree_id, status);
create index if not exists dt_nodes_tree_version_idx on public.dt_nodes(tree_version_id);
create index if not exists dt_rules_source_node_idx on public.dt_rules(source_node_id, priority);
create index if not exists dt_sessions_tenant_user_idx on public.dt_sessions(tenant_id, user_id);
create index if not exists dt_observations_session_idx on public.dt_observations(session_id, created_at);
create index if not exists dt_transitions_session_idx on public.dt_transitions(session_id, created_at);

alter table public.dt_tenants enable row level security;
alter table public.dt_memberships enable row level security;
alter table public.dt_trees enable row level security;
alter table public.dt_tree_versions enable row level security;
alter table public.dt_nodes enable row level security;
alter table public.dt_rules enable row level security;
alter table public.dt_sessions enable row level security;
alter table public.dt_observations enable row level security;
alter table public.dt_transitions enable row level security;

create or replace function public.dt_has_tenant_access(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.dt_memberships m
    where m.tenant_id = p_tenant_id and m.user_id = auth.uid()
  );
$$;

revoke all on function public.dt_has_tenant_access(uuid) from public;
grant execute on function public.dt_has_tenant_access(uuid) to authenticated;

create policy dt_tenants_select on public.dt_tenants for select to authenticated
  using (public.dt_has_tenant_access(id));
create policy dt_memberships_select on public.dt_memberships for select to authenticated
  using (user_id = auth.uid());
create policy dt_trees_all on public.dt_trees for all to authenticated
  using (public.dt_has_tenant_access(tenant_id))
  with check (public.dt_has_tenant_access(tenant_id));
create policy dt_tree_versions_all on public.dt_tree_versions for all to authenticated
  using (exists (select 1 from public.dt_trees t where t.id = tree_id and public.dt_has_tenant_access(t.tenant_id)))
  with check (exists (select 1 from public.dt_trees t where t.id = tree_id and public.dt_has_tenant_access(t.tenant_id)));
create policy dt_nodes_all on public.dt_nodes for all to authenticated
  using (exists (select 1 from public.dt_tree_versions v join public.dt_trees t on t.id = v.tree_id where v.id = tree_version_id and public.dt_has_tenant_access(t.tenant_id)))
  with check (exists (select 1 from public.dt_tree_versions v join public.dt_trees t on t.id = v.tree_id where v.id = tree_version_id and public.dt_has_tenant_access(t.tenant_id)));
create policy dt_rules_all on public.dt_rules for all to authenticated
  using (exists (select 1 from public.dt_tree_versions v join public.dt_trees t on t.id = v.tree_id where v.id = tree_version_id and public.dt_has_tenant_access(t.tenant_id)))
  with check (exists (select 1 from public.dt_tree_versions v join public.dt_trees t on t.id = v.tree_id where v.id = tree_version_id and public.dt_has_tenant_access(t.tenant_id)));
create policy dt_sessions_all on public.dt_sessions for all to authenticated
  using (public.dt_has_tenant_access(tenant_id) and user_id = auth.uid())
  with check (public.dt_has_tenant_access(tenant_id) and user_id = auth.uid());
create policy dt_observations_all on public.dt_observations for all to authenticated
  using (public.dt_has_tenant_access(tenant_id) and exists (select 1 from public.dt_sessions s where s.id = session_id and s.user_id = auth.uid()))
  with check (public.dt_has_tenant_access(tenant_id) and exists (select 1 from public.dt_sessions s where s.id = session_id and s.user_id = auth.uid()));
create policy dt_transitions_all on public.dt_transitions for all to authenticated
  using (public.dt_has_tenant_access(tenant_id) and exists (select 1 from public.dt_sessions s where s.id = session_id and s.user_id = auth.uid()))
  with check (public.dt_has_tenant_access(tenant_id) and exists (select 1 from public.dt_sessions s where s.id = session_id and s.user_id = auth.uid()));

comment on table public.dt_tenants is 'V1 Decision Tree tenant boundary';
comment on table public.dt_sessions is 'V1 runtime decision session state';
comment on table public.dt_observations is 'V1 recorded answers';
comment on table public.dt_transitions is 'V1 deterministic runtime transitions';
