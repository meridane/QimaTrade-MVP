grant select on public.dt_tenants, public.dt_memberships, public.dt_trees, public.dt_tree_versions, public.dt_nodes, public.dt_rules, public.dt_sessions, public.dt_observations, public.dt_transitions, public.product_masters, public.product_requests to authenticated;

grant insert, update, delete on public.dt_sessions, public.dt_observations, public.dt_transitions, public.product_requests to authenticated;

grant usage, select on all sequences in schema public to authenticated;
