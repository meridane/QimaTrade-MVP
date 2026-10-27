# Live Supabase Security Review — CREATE_OFFER and SECURITY DEFINER Functions

Date: 2026-10-27  
Project: `yyulzlnrfcbaxovzjbnh`  
Method: read-only catalog/function-definition queries. No writes or migrations executed.

## Scope and limitation

This is a focused review of the live definitions returned by PostgreSQL catalogs. It is not a complete audit of every function or RLS policy. The proposed migrations in PR #26 are not applied to the live database; the definitions below reflect the current remote state at the time of inspection.

## Confirmed findings

### F-01 — Live CREATE_OFFER wrapper still writes statuses that conflict with the documented constraints

The live `public.execute_create_offer_v1(...)` definition inserts `'running'` into `action_executions.status` and `idempotency_keys.status`, then updates them to `'succeeded'`. The current repository proposal aligns these values to `RUNNING` / `COMPLETED` for action executions and `IN_PROGRESS` / `COMPLETED` for idempotency keys, while preserving public JSON `status: "succeeded"`.

**Impact:** the live implementation remains inconsistent with the status contract that the PR is designed to fix. CI success applies to the proposed migration in an isolated PostgreSQL fixture; it does not mean the live database has been changed.

**Safe next step:** do not apply the migration until authorization and migration parity gates below are resolved and the change is approved. Then deploy only through the agreed reviewed migration process.

### F-02 — Low-level `create_offer_v1` remains executable by authenticated users

Live privilege inspection returned:
- `anon_execute = false`
- `authenticated_execute = true`

The function is `SECURITY DEFINER`, checks authentication and provider actor, validates basic quantity/price/currency and existence of the product and demand, then inserts the offer. It does not itself check that the supplied demand is authorized for the selected tenant. The proposed migration `20261027100000_restrict_direct_create_offer_rpc.sql` is intended to remove direct authenticated execution, but it has not been applied.

**Impact:** the lower-level RPC remains directly callable by authenticated clients, bypassing the wrapper's idempotency/execution/event contract. The exact exploitability depends on grants and surrounding RLS/business rules, but the privilege is confirmed and should be reviewed as a security issue.

**Safe next step:** keep the proposed privilege restriction under review; validate all legitimate callers and function ownership/dependencies before production deployment.

### F-03 — CREATE_OFFER wrapper verifies tenant membership but not demand-to-tenant authorization

The live wrapper verifies that the current user has membership in `p_tenant_id`, and that `p_demand_id` exists. It does not verify that the demand belongs to, was published to, or is otherwise answerable by that tenant. The `demands` table has no `tenant_id` column in the inspected schema; do not invent one or add a guard based on a nonexistent field.

**Impact:** membership in a tenant alone does not establish permission to answer an arbitrary existing demand.

**Safe next step:** define the canonical eligibility rule using the actual business model (for example requester/market/scope/participant relationships), then add negative integration tests. Do not guess the rule in SQL.

### F-04 — Actor lookup uses arbitrary `LIMIT 1`

The live `execute_create_offer_v1`, `create_offer_v1`, `current_actor_id()`, and `current_profile_actor_id()` implementations select an actor from `profiles` with `LIMIT 1` and no ordering. The repository API layer was changed to reject ambiguous tenant membership, but the database actor lookup still assumes that the user resolves to one applicable profile actor.

**Impact:** if multiple eligible profile rows are possible, the selected actor is not deterministic.

**Safe next step:** inspect actual uniqueness constraints and data invariants for `profiles.auth_user_id`; only replace the lookup after confirming the intended one-user/one-actor contract and preserving legitimate legacy records.

### F-05 — Product request publication also uses arbitrary profile selection

Live `dt_publish_product_request(p_request_id, p_user_id)` checks that `auth.uid() = p_user_id`, locks a request owned by that user, and verifies an active Product Master. When creating a demand it selects a matching profile actor with `LIMIT 1`, without ordering. The function is `SECURITY DEFINER` and authenticated-executable.

**Safe next step:** verify the profile uniqueness invariant and review this function alongside the decision-tree/product-request tests before modifying it.

## Functions inventoried

The read-only query found 19 SECURITY DEFINER functions in `public`. Among them, 15 were executable by `authenticated`; none of the listed functions was executable by `anon`. Functions requiring focused review include:
- `create_offer_v1`
- `execute_create_offer_v1`
- `current_actor_id`
- `current_profile_actor_id`
- `dt_has_tenant_access`
- `dt_publish_product_request`
- `dt_submit_answer`
- `get_action_definition_v1`
- `is_demand_participant`, `is_demand_requester`, `is_offer_participant`, `is_match_participant`, `is_message_participant`, `is_counter_offer_participant`
- `can_access_project`, `is_project_creator`, `is_project_participant`

This inventory is not a blanket recommendation to revoke execution. Each function needs its callers, grants, ownership, search_path, RLS dependencies and intended access contract reviewed individually. The inspected functions use `SET search_path TO 'public'`; the calls to `auth.uid()` are schema-qualified in the bodies reviewed.

## Status and next gates

- GitHub CI on commit `3d2e51547099461ad66f2ee0a7fcb75157f8f41e`: PASS.
- CodeQL on the same commit: PASS.
- Vercel Preview: READY.
- PR #26: open, draft, unmerged.
- Production database writes/migrations: none performed during this review.
- Security Gate: **NOT PASS** until demand authorization is specified, direct RPC privileges are resolved, the legacy direct-insert offer route is addressed compatibly, and migration parity is reconciled.

## Evidence boundary

These findings are based on live catalog/function-definition query results at review time. They do not establish the full set of effective grants, every RLS policy, or a complete mapping of 161 remote migration-history records to repository source. Continue read-only investigation and isolated testing; do not reset or blindly replay the production database migrations.
