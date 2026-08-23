create table if not exists public.project_inspections (
  id uuid primary key default gen_random_uuid(),
  inspection_id text not null unique,
  project_id uuid not null references public.projects(id) on delete cascade,
  order_id uuid references public.project_orders(id) on delete set null,
  shipment_id uuid references public.project_shipments(id) on delete set null,
  inspector_actor_id uuid references public.actors(actor_id) on delete set null,
  created_by_actor_id uuid not null references public.actors(actor_id),
  type text not null check (type in ('pre_purchase','pickup','warehouse_receipt','repair','pre_loading','final_delivery')),
  status text not null default 'draft' check (status in ('draft','in_progress','completed','approved','rejected')),
  summary text,
  recommendation text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.project_inspection_findings (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.project_inspections(id) on delete cascade,
  title text not null,
  description text,
  severity text not null default 'low' check (severity in ('low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','in_progress','resolved','accepted')),
  recommendation text,
  evidence_url text,
  created_by_actor_id uuid not null references public.actors(actor_id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.project_inspections enable row level security;
alter table public.project_inspection_findings enable row level security;
grant select, insert, update on public.project_inspections to authenticated;
grant select, insert, update on public.project_inspection_findings to authenticated;

drop policy if exists project_inspections_select on public.project_inspections;
drop policy if exists project_inspections_insert on public.project_inspections;
drop policy if exists project_inspections_update on public.project_inspections;
create policy project_inspections_select on public.project_inspections for select to authenticated using (public.can_access_project(project_id));
create policy project_inspections_insert on public.project_inspections for insert to authenticated with check (public.can_access_project(project_id));
create policy project_inspections_update on public.project_inspections for update to authenticated using (public.can_access_project(project_id)) with check (public.can_access_project(project_id));

drop policy if exists project_inspection_findings_select on public.project_inspection_findings;
drop policy if exists project_inspection_findings_insert on public.project_inspection_findings;
drop policy if exists project_inspection_findings_update on public.project_inspection_findings;
create policy project_inspection_findings_select on public.project_inspection_findings for select to authenticated using (exists (select 1 from public.project_inspections i where i.id = inspection_id and public.can_access_project(i.project_id)));
create policy project_inspection_findings_insert on public.project_inspection_findings for insert to authenticated with check (exists (select 1 from public.project_inspections i where i.id = inspection_id and public.can_access_project(i.project_id)));
create policy project_inspection_findings_update on public.project_inspection_findings for update to authenticated using (exists (select 1 from public.project_inspections i where i.id = inspection_id and public.can_access_project(i.project_id))) with check (exists (select 1 from public.project_inspections i where i.id = inspection_id and public.can_access_project(i.project_id)));
