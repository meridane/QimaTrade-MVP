begin;

insert into public.dt_tenants (id, name)
values ('11111111-1111-4111-8111-111111111111', 'QimaTrade MVP')
on conflict (id) do update set name = excluded.name;

insert into public.dt_memberships (tenant_id, user_id, role)
values
  ('11111111-1111-4111-8111-111111111111', '69a457bc-7a71-4448-abde-5fcdabe5928c', 'owner'),
  ('11111111-1111-4111-8111-111111111111', '27fce695-bc74-45b8-929b-1c060bd87cc7', 'member'),
  ('11111111-1111-4111-8111-111111111111', '0ff94844-975e-4021-b6fc-eb20212323f0', 'member')
on conflict (tenant_id, user_id) do update set role = excluded.role;

insert into public.dt_trees (id, tenant_id, tree_key, title)
values ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111', 'product-classification', 'Product Classification')
on conflict (id) do update set tenant_id = excluded.tenant_id, tree_key = excluded.tree_key, title = excluded.title;

insert into public.dt_tree_versions (id, tree_id, version, status, entry_node_id, published_at)
values ('33333333-3333-4333-8333-333333333333', '22222222-2222-4222-8222-222222222222', '1.0.0', 'published', null, now())
on conflict (id) do update set status = 'published', version = '1.0.0', published_at = coalesce(public.dt_tree_versions.published_at, now());

insert into public.dt_nodes (id, tree_version_id, node_key, kind, title, description, image_url)
values
('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333','category','category','Choose a category','Select the category that best matches your product.','https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=1200&q=85'),
('55555555-5555-4555-8555-555555555555','33333333-3333-4333-8333-333333333333','industrial-subcategory','subcategory','Industrial Machinery','Select the closest industrial equipment group.','https://images.unsplash.com/photo-1565043666747-69f6646db940?auto=format&fit=crop&w=1200&q=85'),
('66666666-6666-4666-8666-666666666666','33333333-3333-4333-8333-333333333333','construction-subcategory','subcategory','Construction & Building Materials','Select the closest construction material group.','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=85'),
('77777777-7777-4777-8777-777777777777','33333333-3333-4333-8333-333333333333','terminal-cnc','terminal','CNC & Machine Tools','Modern CNC machining and machine-tool equipment.','https://images.unsplash.com/photo-1565610222536-ef125c59da2e?auto=format&fit=crop&w=1200&q=85'),
('88888888-8888-4888-8888-888888888888','33333333-3333-4333-8333-333333333333','terminal-pumps','terminal','Pumps & Compressors','Industrial pumping and compression equipment.','https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=85'),
('99999999-9999-4999-8999-999999999999','33333333-3333-4333-8333-333333333333','terminal-cement','terminal','Cement & Concrete','Cement, ready-mix concrete and concrete elements.','https://images.unsplash.com/photo-1592394673782-86e7b5ad3b4f?auto=format&fit=crop&w=1200&q=85'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','terminal-bricks','terminal','Bricks & Blocks','Construction bricks, concrete blocks and AAC blocks.','https://images.unsplash.com/photo-1531835551805-16d864c8d7e8?auto=format&fit=crop&w=1200&q=85')
on conflict (id) do update set title = excluded.title, description = excluded.description, image_url = excluded.image_url;

update public.dt_tree_versions
set entry_node_id = '44444444-4444-4444-8444-444444444444'
where id = '33333333-3333-4333-8333-333333333333';

insert into public.dt_rules (id, tree_version_id, source_node_id, field, operator, value, target_node_id, priority)
values
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','category','equals','Industrial Machinery','55555555-5555-4555-8555-555555555555',10),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','category','equals','Construction & Building Materials','66666666-6666-4666-8666-666666666666',20),
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','33333333-3333-4333-8333-333333333333','55555555-5555-4555-8555-555555555555','subcategory','equals','CNC & Machine Tools','77777777-7777-4777-8777-777777777777',10),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','33333333-3333-4333-8333-333333333333','55555555-5555-4555-8555-555555555555','subcategory','equals','Pumps & Compressors','88888888-8888-4888-8888-888888888888',20),
('ffffffff-ffff-4fff-8fff-ffffffffffff','33333333-3333-4333-8333-333333333333','66666666-6666-4666-8666-666666666666','subcategory','equals','Cement & Concrete','99999999-9999-4999-8999-999999999999',10),
('12345678-1234-4234-8234-123456789012','33333333-3333-4333-8333-333333333333','66666666-6666-4666-8666-666666666666','subcategory','equals','Bricks & Blocks','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',20)
on conflict (id) do update set field = excluded.field, operator = excluded.operator, value = excluded.value, target_node_id = excluded.target_node_id, priority = excluded.priority;

commit;