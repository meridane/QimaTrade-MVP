create table if not exists public.project_documents (
  id uuid primary key default gen_random_uuid(),
  document_id text not null unique,
  project_id uuid not null references public.projects(id) on delete cascade,
  order_id uuid references public.project_orders(id) on delete cascade,
  shipment_id uuid references public.project_shipments(id) on delete cascade,
  uploaded_by_actor_id uuid not null references public.actors(id),
  document_type text not null check (document_type in ('invoice','packing_list','payment_proof','delivery_proof','contract','other')),
  file_name text not null,
  storage_path text not null unique,
  mime_type text,
  file_size bigint,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_documents_link_check check (order_id is not null or shipment_id is not null)
);

alter table public.project_documents enable row level security;
grant select, insert, update, delete on public.project_documents to authenticated;

create policy project_documents_select on public.project_documents for select to authenticated using (public.can_access_project(project_id));
create policy project_documents_insert on public.project_documents for insert to authenticated with check (
  public.can_access_project(project_id)
  and exists (select 1 from public.project_participants pp where pp.project_id = project_documents.project_id and pp.actor_id = project_documents.uploaded_by_actor_id)
);
create policy project_documents_update on public.project_documents for update to authenticated using (public.can_access_project(project_id)) with check (public.can_access_project(project_id));
create policy project_documents_delete on public.project_documents for delete to authenticated using (public.can_access_project(project_id));

insert into storage.buckets (id, name, public) values ('project-documents', 'project-documents', false) on conflict (id) do update set public = false;
grant select, insert, update, delete on storage.objects to authenticated;

create policy project_documents_storage_select on storage.objects for select to authenticated using (bucket_id = 'project-documents' and public.can_access_project(((storage.foldername(name))[1])::uuid));
create policy project_documents_storage_insert on storage.objects for insert to authenticated with check (bucket_id = 'project-documents' and public.can_access_project(((storage.foldername(name))[1])::uuid));
create policy project_documents_storage_update on storage.objects for update to authenticated using (bucket_id = 'project-documents' and public.can_access_project(((storage.foldername(name))[1])::uuid)) with check (bucket_id = 'project-documents' and public.can_access_project(((storage.foldername(name))[1])::uuid));
create policy project_documents_storage_delete on storage.objects for delete to authenticated using (bucket_id = 'project-documents' and public.can_access_project(((storage.foldername(name))[1])::uuid));
