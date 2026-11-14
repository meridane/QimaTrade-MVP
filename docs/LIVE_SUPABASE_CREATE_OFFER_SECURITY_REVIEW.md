# Live Supabase Security Review — CREATE_OFFER and SECURITY DEFINER Functions

Date: 2026-10-27  
Project: `yyulzlnrfcbaxovzjbnh`  
Method: read-only PostgreSQL catalog/function-definition queries. No writes or migrations executed.

## Scope

Focused review of live definitions; not a complete audit of every function or RLS policy. The proposed migrations in PR #26 are not applied to the live database.

## Confirmed findings

### F-01 — Live CREATE_OFFER wrapper still writes lowercase statuses

The live `public.execute_create_offer_v1(...)` inserts `'running'` into `action_executions.status` and `idempotency_keys.status`, then updates them to `'succeeded'`. The proposed repository migration instead uses `RUNNING` / `COMPLETED` for action executions and `IN_PROGRESS` / `COMPLETED` for idempotency keys, while preserving public JSON `status: "succeeded"`.

**Impact:** the live implementation remains inconsistent with the status contract this PR is designed to fix. CI success applies to the proposed migration in an isolated PostgreSQL fixture; it does not mean the live database has changed.

**Next step:** do not apply the migration until authorization and migration-parity gates are resolved and the change is approved.

### F-02 — Low-level `create_offer_v1` remains executable by authenticated users

Live privilege inspection: `anon_execute = false`; `authenticated_execute = true`. The function is `SECURITY DEFINER`, checks authentication/provider actor, validates basic quantity/price/currency and existence of product and demand, then inserts the offer. It does not check that the demand is authorized for the selected tenant. Proposed migration `20261027100000_restrict_direct_create_offer_rpc.sql` is not applied.

**Impact:** authenticated clients can directly call the lower-level RPC, bypassing the wrapper's idempotency/execution/event contract. Exact exploitability depends on surrounding grants and business rules, but the privilege is confirmed and requires review.

**Next step:** validate all legitimate callers and dependencies before deploying the proposed privilege restriction.

### F-03 — Tenant membership does not establish demand-answer permission

The live wrapper verifies membership in `p_tenant_id` and existence of `p_demand_id`, but does not verify that the demand belongs to, was published to, or is otherwise answerable by that tenant. The inspected `demands` table has no `tenant_id` column.

**Next step:** define the canonical eligibility rule from the actual business model and add negative integration tests. Do not invent a column or guess the rule in SQL.

### F-04 — Actor lookup uses `LIMIT 1`, but a uniqueness invariant exists

The live `execute_create_offer_v1`, `create_offer_v1`, `current_actor_id()`, and `current_profile_actor_id()` implementations select an actor from `profiles` with `LIMIT 1` and no ordering. The follow-up catalog query found a UNIQUE constraint and unique index on `profiles.auth_user_id`, so at most one profile row can match the authenticated user under the current schema.

**Assessment:** this is not currently confirmed as an exploitable nondeterminism for lookups filtered by `auth_user_id`. The duplicated unique constraints/indexes may be redundant, but should not be removed without checking migration history and dependencies.

**Next step:** retain the one-user/one-profile invariant and verify it in disposable tests; do not change this lookup solely because it uses `LIMIT 1`.

### F-05 — Product request publication also uses arbitrary profile selection

Live `dt_publish_product_request(p_request_id, p_user_id)` checks `auth.uid() = p_user_id`, locks a request owned by that user, and verifies an active Product Master. When creating a demand it selects a matching profile actor with `LIMIT 1`. It is `SECURITY DEFINER` and authenticated-executable.

**Next step:** verify profile uniqueness and review this function with decision-tree/product-request tests before modification.

## Function inventory

The read-only query returned **20 SECURITY DEFINER functions** in `public`; **17 are executable by `authenticated`**, and none of these 20 was executable by `anon` in the inspected privilege check.

Functions needing focused review include:
- `create_offer_v1`, `execute_create_offer_v1`
- `current_actor_id`, `current_profile_actor_id`, `dt_has_tenant_access`
- `dt_publish_product_request`, `dt_submit_answer`, `get_action_definition_v1`
- `is_demand_participant`, `is_demand_requester`, `is_offer_participant`, `is_match_participant`, `is_message_participant`, `is_counter_offer_participant`
- `can_access_project`, `is_project_creator`, `is_project_participant`

This is not a blanket recommendation to revoke execution. Review each function's callers, grants, ownership, search_path, RLS dependencies and intended access contract individually. Inspected functions use `SET search_path TO 'public'`; reviewed calls to `auth.uid()` are schema-qualified.

## Status and next gates

- GitHub CI on commit `3d2e51547099461ad66f2ee0a7fcb75157f8f41e`: PASS.
- CodeQL on the same commit: PASS.
- Vercel Preview: READY.
- PR #26: open, draft, unmerged.
- Production database writes/migrations: none performed during this review.
- Security Gate: **NOT PASS** until demand authorization is specified, direct RPC privileges are resolved, the legacy direct-insert offer route is addressed compatibly, and migration parity is reconciled.

## Evidence boundary

These findings reflect live catalog/function-definition query results at review time. They do not establish every effective grant, every RLS policy, or a complete mapping of 161 remote migration-history records to repository source. Continue read-only investigation and isolated testing; do not reset or blindly replay production migrations.


## Live demand/offer lifecycle data check — 2026-10-27 (read-only)

A follow-up aggregate query against the live tables returned:
- `demands`: 23 rows with `demand_status = 'draft'`; all 23 also have `documentation_status = 'incomplete'`.
- `offers`: 3 rows with `lifecycle = 'draft'`; all 3 currently have nonzero prices.

This is a small current dataset, not proof of all future workflow states. However, it makes the supplier-eligibility gap concrete: the current live demands are all drafts, so there is no observed published-demand state to use as an authorization predicate yet. A safe response-eligibility rule must be coordinated with the demand publication workflow (including whether incomplete drafts are visible to providers). Do not make drafts publicly answerable merely to unblock offer creation.

The current legacy route's optional-price capability is confirmed by code, but the present three live offers do not demonstrate any existing null-price draft. Preserve route compatibility until the product contract is explicitly decided; do not infer that null-price drafts are or are not needed from this small sample.

No rows were modified.


## Follow-up implementation — explicit tenant selection on product-request publish route

Repository review found a second route-level arbitrary-tenant selection in `app/api/product-requests/publish/route.ts`: it queried `dt_memberships` with `.limit(1).maybeSingle()` and used that tenant for `PUBLISH_PRODUCT_REQUEST`. A user with multiple tenant memberships could therefore publish under an arbitrary tenant context.

Branch-only fix in commit `1c3d2ab5069c7ac7276708f50fa1a4c6f4149ac0`:
- Fetch all memberships for the authenticated user.
- Return `TENANT_MEMBERSHIP_REQUIRED` when none exist or the membership query fails.
- Deduplicate tenant IDs and return HTTP 409 `TENANT_SELECTION_REQUIRED` when there is not exactly one tenant.
- Preserve the Universal Action Runtime call and successful response contract.
- Treat a missing/non-string idempotency key safely rather than calling `.trim()` on an arbitrary JSON value.

This follows the existing safety behavior in the CREATE_OFFER route. It does not implement active-tenant selection; multi-tenant users must currently select/use a single-membership account flow before this action can proceed. No production code or database was changed.

## Publication contract finding

The existing `dt_publish_product_request` database function creates a demand with `demand_status = 'draft'` and `documentation_status = 'incomplete'`, then marks the product request `published`. The word “published” currently refers to the product request workflow result, not necessarily a supplier-visible demand. Therefore, the eligibility rule for suppliers cannot safely be inferred from the `product_requests.status` alone. A separate, explicit demand publication/visibility state or documented semantic mapping is required before tightening `execute_create_offer_v1`.


## Follow-up implementation — defensive request identifiers (2026-10-27)

In `app/api/actions/create-offer/route.ts`, optional `correlationId` and `idempotencyKey` previously used `.trim()` without first confirming the JSON values were strings. Malformed JSON such as an object/number in either field could throw a TypeError and return the generic 400 action error.

Branch-only fix committed as `73ea68d550a00a0839ced24c75a4bf38012fa9a6`:
- Use the supplied identifier only when it is a non-empty string after trimming.
- Generate a UUID otherwise.
- Preserve normal request behavior for valid strings.
- This is defensive parsing only; the database runtime still validates idempotency semantics.

Validation evidence as of this note:
- On the preceding route-fix commit, the isolated PostgreSQL CREATE_OFFER integration/concurrency job passed.
- CodeQL passed.
- TypeScript, dependency audit and production build passed; Playwright Chromium installation/browser smoke tests were still running when checked.
- These results do not yet validate the newest commit. Wait for its own CI and CodeQL runs before treating it as verified.
