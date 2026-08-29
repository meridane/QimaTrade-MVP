alter table public.offers add column if not exists product_master_id uuid references public.product_masters(id) on delete set null;
create index if not exists offers_product_master_status_idx on public.offers(product_master_id, lifecycle, created_at desc);
create index if not exists product_masters_subcategory_status_code_idx on public.product_masters(subcategory_id, status, code);
comment on column public.offers.product_master_id is 'Canonical Product Master targeted by this supplier offer in the MVP.';
