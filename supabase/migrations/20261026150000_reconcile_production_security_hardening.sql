-- QIMA production hardening performed on 2026-10-26.
-- Reconciliation record for review only; production changes were already applied
-- directly through the Supabase migration API. Do not replay blindly against an
-- environment whose schema/history has not been reconciled.

begin;

-- Restrict direct RPC execution on identity/participant helpers to authenticated.
revoke execute on function public.current_actor_id() from public, anon;
grant execute on function public.current_actor_id() to authenticated;

revoke execute on function public.is_counter_offer_participant(uuid, uuid) from public, anon;
grant execute on function public.is_counter_offer_participant(uuid, uuid) to authenticated;

revoke execute on function public.is_project_creator(uuid) from public, anon;
grant execute on function public.is_project_creator(uuid) to authenticated;

revoke execute on function public.current_profile_actor_id() from public, anon;
grant execute on function public.current_profile_actor_id() to authenticated;

-- Trigger function must not be callable as a direct API RPC.
revoke execute on function public.touch_payment_request_updated_at() from public, anon, authenticated;

-- Attribute reference tables: authenticated read-only; no anonymous access.
revoke all privileges on table public.attribute_options from anon;
revoke all privileges on table public.attribute_units from anon;

alter table public.attribute_options enable row level security;
alter table public.attribute_units enable row level security;

drop policy if exists attribute_options_authenticated_read on public.attribute_options;
create policy attribute_options_authenticated_read
  on public.attribute_options for select to authenticated using (true);

drop policy if exists attribute_units_authenticated_read on public.attribute_units;
create policy attribute_units_authenticated_read
  on public.attribute_units for select to authenticated using (true);

-- Pin search_path for functions previously reported by the Security Advisor.
alter function public.generate_demand_business_id() set search_path = pg_catalog, public, pg_temp;
alter function public.set_counter_offer_id() set search_path = pg_catalog, public, pg_temp;
alter function public.set_project_ids() set search_path = pg_catalog, public, pg_temp;
alter function public.set_task_id() set search_path = pg_catalog, public, pg_temp;
alter function public.set_project_orders_updated_at() set search_path = pg_catalog, public, pg_temp;
alter function public.set_updated_at() set search_path = pg_catalog, public, pg_temp;
alter function public.prevent_published_definition_mutation() set search_path = pg_catalog, public, pg_temp;

alter function core.json_value_at(jsonb, text) set search_path = pg_catalog, core, public, pg_temp;
alter function core.evaluate_rule_expression(jsonb, jsonb) set search_path = pg_catalog, core, public, pg_temp;
alter function core.validate_decision_tree_definition(jsonb) set search_path = pg_catalog, core, public, pg_temp;
alter function core.dt_get_node(jsonb, text) set search_path = pg_catalog, core, public, pg_temp;
alter function core.dt_set_data(jsonb, text, jsonb) set search_path = pg_catalog, core, public, pg_temp;

-- Archived/reference tables had no grants for anon/authenticated at the time
-- of audit. Enable RLS without inventing permissive policies.
alter table public.trade_domains_archived enable row level security;
alter table public.categories_archived enable row level security;
alter table public.subcategories_archived enable row level security;
alter table public.hs_codes enable row level security;
alter table public.product_hs_codes_archived enable row level security;
alter table public.taxonomy_hs_review_queue enable row level security;
alter table public.product_family_candidates enable row level security;
alter table public.product_masters_archived enable row level security;
alter table public.trade_domains_current_archived enable row level security;
alter table public.categories_current_archived enable row level security;
alter table public.subcategories_current_archived enable row level security;
alter table public.product_families_archived enable row level security;
alter table public.attribute_applicability enable row level security;
alter table public.attribute_audit_results enable row level security;

commit;
