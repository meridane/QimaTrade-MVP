alter table public.dt_nodes
  add column if not exists canonical_category_id uuid references public.categories(id) on delete restrict,
  add column if not exists canonical_subcategory_id uuid references public.subcategories(id) on delete restrict;

create index if not exists dt_nodes_canonical_category_idx
  on public.dt_nodes(canonical_category_id);

create index if not exists dt_nodes_canonical_subcategory_idx
  on public.dt_nodes(canonical_subcategory_id);

update public.dt_nodes
set canonical_category_id = c.id
from public.categories c
join public.trade_domains td on td.id = c.trade_domain_id
where dt_nodes.node_key in ('industrial-subcategory','terminal-cnc','terminal-pumps')
  and c.code = 'TD03-C01'
  and td.code = 'TD03';

update public.dt_nodes
set canonical_category_id = c.id
from public.categories c
join public.trade_domains td on td.id = c.trade_domain_id
where dt_nodes.node_key in ('construction-subcategory','terminal-cement','terminal-bricks')
  and c.code = 'TD03-C02'
  and td.code = 'TD03';

update public.dt_nodes
set canonical_subcategory_id = s.id
from public.subcategories s
where dt_nodes.node_key = 'terminal-cnc'
  and s.code = 'TD03-C01-S05';

update public.dt_nodes
set canonical_subcategory_id = s.id
from public.subcategories s
where dt_nodes.node_key = 'terminal-pumps'
  and s.code = 'TD03-C01-S12';

update public.dt_nodes
set canonical_subcategory_id = s.id
from public.subcategories s
where dt_nodes.node_key = 'terminal-cement'
  and s.code = 'TD03-C02-S01';

update public.dt_nodes
set canonical_subcategory_id = s.id
from public.subcategories s
where dt_nodes.node_key = 'terminal-bricks'
  and s.code = 'TD03-C02-S03';

comment on column public.dt_nodes.canonical_category_id is 'Canonical Qima taxonomy category referenced by this decision node.';
comment on column public.dt_nodes.canonical_subcategory_id is 'Canonical Qima taxonomy subcategory referenced by this decision node.';
