# CREATE_OFFER regression and security test plan

Status: preparation only — no production database access and no SQL execution.
PR: #26 (open, draft, not merged).
Migration under review: supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql

## Confirmed repository findings

- The proposed migration writes action_executions statuses RUNNING and COMPLETED, and idempotency_keys statuses IN_PROGRESS and COMPLETED, using the uppercase values described by the PR's constraint contract.
- The public JSON continues returning status "succeeded".
- The idempotency hash covers p_input and all effective business parameters.
- Tenant membership is checked for p_tenant_id.
- provider_actor_id is compared to the actor found using a profiles query with LIMIT 1.
- Demand existence is checked, but the function does not visibly assert that the demand belongs to or is authorized in the chosen tenant.
- SELECT ... FOR UPDATE on idempotency_keys only locks a row if one already exists. Parallel first-time calls can race; a uniqueness constraint may reject one, but graceful replay and no-duplicate behavior remain untested.
- app/api/offers/route.ts still inserts directly into public.offers. app/api/actions/create-offer/route.ts and app/offers/actions.ts go through executeUniversalAction.
- app/api/actions/create-offer/route.ts and app/offers/actions.ts choose dt_memberships with LIMIT 1, potentially selecting an arbitrary tenant for multi-tenant users.
- The repository's migrations do not reproduce the complete remote schema. Do not reset the database or blindly replay migrations.

## Required isolated database regression cases

Run only against a disposable local PostgreSQL/Supabase environment with the exact function dependencies and compatible schema. Never run the test fixture against production and do not create real production offers.

### A. Status contract
1. A valid call creates one offer and one action_executions row with status COMPLETED.
2. It creates one idempotency_keys row with status COMPLETED.
3. The public result includes status "succeeded", objectId and executionId.
4. Status columns never receive lowercase "running" or "succeeded".

### B. Idempotence and concurrency
1. Same tenant, same key, same effective parameters: return the same result and create no second offer.
2. Same tenant and key but changed quantity, price, currency, demand, Product Master, attributes, lifecycle, offer type or pricing model: reject with IDEMPOTENCY_KEY_REUSE.
3. Same textual key in different tenants: verify intended uniqueness scope.
4. Concurrent first calls with the same tenant/key and identical input: one offer maximum; the second call must return the first result or a documented retryable conflict.
5. Concurrent calls with same key but different input: at most one can commit; no partial rows or second offer.
6. Confirm uniqueness constraints and transaction boundaries from the actual schema before claiming these tests are covered.

### C. Tenant authorization
1. Unauthenticated callers are rejected.
2. A user without membership in the supplied tenant is rejected.
3. A tenant-A user cannot act under tenant B.
4. A tenant-A user cannot create an offer using a demand belonging to tenant B unless the documented business model explicitly grants that capability.
5. provider_actor_id spoofing is rejected.
6. Resolve whether action_definitions is global or tenant-scoped; enforce the correct scoping.
7. Profile-to-actor selection is deterministic or an invariant ensures only one applicable profile exists; do not rely on arbitrary LIMIT 1 if multiple rows are valid.

### D. Validation and audit
1. Invalid/missing demand, inactive/missing Product Master, invalid quantity, negative price, missing currency, blank idempotency key and null p_input fail without partial offer/execution/idempotency/event rows.
2. Confirm whether zero price is allowed and whether currency is required when price is null.
3. Validate required attribute keys, value types, allowed options and units on the server, not only in the UI.
4. Success creates exactly one ACTION_SUCCEEDED event matching execution, actor, tenant, correlation ID and offer.
5. Errors/rollback leave no orphan RUNNING or IN_PROGRESS rows. Clarify whether FAILED outcomes are intentionally persisted; ordinary PL/pgSQL exceptions roll back changes in the transaction.

## Architectural follow-up
- Unify app/api/offers/route.ts with the Universal Action Runtime while retaining existing multipart-form validation and redirect semantics.
- Replace arbitrary tenant selection with a validated explicit tenant context, or reject ambiguous multi-membership users until they select a tenant.
- Document and enforce the demand ownership/authorization contract before changing the SQL guard.
- Security Gate stays NOT PASS until the isolated DB, tenant-negative, concurrency, and code CI tests genuinely pass.

## Validation evidence on 2026-10-27
- Prior CI run 40355755095: success for dependency audit, TypeScript, production build, Playwright Chromium installation and browser smoke tests.
- Prior CodeQL run 40355755332: success.
- Documentation update commit 1a157198db4c4e67275150c1b1073b771f51bda4 triggered new runs: QIMA CI 40359312354 was pending and CodeQL 40359312595 was in progress at the latest read.
- Successful CI/CodeQL do not prove execute_create_offer_v1 was executed against PostgreSQL.
- No production migration was applied and no production offer was created during this review.


## Follow-up audit — route contract compatibility (2026-10-27)

### Confirmed from current code
- `app/api/offers/route.ts` is a separate multipart/form-data path. It accepts a missing demand ID, missing Product Master ID, and an optional price; when price is omitted it writes a null price/currency and still creates an offer.
- The route inserts directly into `public.offers`, so it bypasses the Universal Action Runtime, idempotency keys, action execution status transitions, and `ACTION_SUCCEEDED` event creation.
- `app/api/actions/create-offer/route.ts` instead requires the Universal Action Runtime input contract, including a demand and Product Master ID, and normalizes price to a number. It is not a drop-in replacement for the multipart route without a deliberate product/business decision.
- The inspected migration's `execute_create_offer_v1` rejects a null price and requires a demand and active Product Master. Therefore, simply replacing the direct insert with the action call would change existing accepted form behavior and could break valid draft offers.
- The available demand-creation migration builds `demands` with `requester_actor_id` and JSON scope; it does not add a `tenant_id` to demands. A demand-to-tenant authorization check cannot safely be guessed from the current evidence.

### Safe next implementation step
1. Define whether every offer must be attached to a demand and an active Product Master, and whether draft offers may have no price.
2. Define the canonical relationship from tenant membership/actor to a demand (for example, ownership by requester actor, if that is the approved business rule).
3. Add isolated PostgreSQL integration tests against a disposable schema with the real function dependencies.
4. Only then design a compatibility-preserving migration of `app/api/offers/route.ts` to the Universal Action Runtime. Preserve multipart parsing, validation error codes, and the 303 redirect if the product contract requires them.

### Security decision
Do not alter the SQL tenant guard or replace the legacy offer route until the business ownership contract is explicit. This is a real design dependency, not a CI failure. Security Gate remains NOT PASS; no production database or offers were touched.


## Implementation decision — idempotency first-insert race (2026-10-27)

Decision taken: serialize CREATE_OFFER attempts using a transaction-scoped PostgreSQL advisory lock keyed by tenant ID plus idempotency key, before looking up the idempotency row. This addresses the specific gap where `SELECT ... FOR UPDATE` cannot lock a not-yet-existing row.

- Code: `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`.
- Intended behavior: requests using the same tenant/key are processed sequentially; an identical retry sees the completed result, while a changed payload is rejected by the request-hash check.
- Scope: this is a proposed migration change on the PR branch only. It has not been run against PostgreSQL or production.
- Remaining verification: confirm advisory-lock behavior with concurrent integration tests in a disposable database, and inspect the actual unique constraint scope on `idempotency_keys`.
- This does not resolve demand-to-tenant authorization, optional draft offer compatibility, or direct inserts in `app/api/offers/route.ts`.
- Security Gate remains NOT PASS until runtime tests pass.


## Live schema verification — 2026-10-27 (read-only)

The following facts were confirmed by read-only queries against the configured Supabase project. No SQL writes or migrations were executed.

- `idempotency_keys_tenant_key_uidx` is a unique index on `(tenant_id, key)`. The advisory lock's tenant/key scope therefore matches the current uniqueness scope.
- `action_executions.status` permits `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`, `BLOCKED`; `idempotency_keys.status` permits `IN_PROGRESS`, `COMPLETED`, `FAILED`. The migration's inserted/intermediate values align with these checks.
- `profiles.auth_user_id` has a unique constraint/index. The prior concern that a single auth user could have multiple profile rows is not supported by the live schema. Keep the check for missing `actor_id`, but don't treat `LIMIT 1` by itself as evidence of duplicate profiles.
- `dt_memberships` is keyed by `(tenant_id, user_id)`; a user can still belong to more than one tenant. The app-level ambiguity guard remains necessary until an explicit active-tenant context exists.
- `demands` has no `tenant_id`. The linked `product_requests` table does have `tenant_id` and `user_id`, but the demand bridge stores only `requester_actor_id` and scope on the demand.
- The live `is_demand_participant(uuid)` helper considers the demand requester and users who already have a match-linked offer. It does not establish general marketplace visibility for a new provider. Therefore, simply requiring `is_demand_participant(p_demand_id)` would block a new supplier's first offer; comparing the demand's tenant to the supplier tenant would also be the wrong rule for a cross-tenant marketplace.
- Existing RLS policies for `demands` expose a demand to its requester or a participant. The create-offer SQL's existence-only check is not enough to prove that a provider is allowed to respond to a demand. A canonical published/visible-to-suppliers rule must be designed before tightening the SQL guard.

### Updated decision

Do not invent a demand ownership check from `tenant_id` (which does not exist on `demands`) and do not reuse `is_demand_participant` as a first-offer authorization check. The next implementation should first define a narrow, auditable predicate for a supplier's right to respond to a demand, then test requester, unrelated supplier, already-matched supplier, and cross-tenant supplier cases in an isolated database.

The offer form compatibility decision remains: draft offers may currently omit demand, Product Master, and price. The current universal SQL action requires all three (and an active Product Master), so route unification must wait until the action contract deliberately supports drafts or the product flow is deliberately changed. No production mutation was performed. Security Gate remains NOT PASS.


## Additional security finding — direct RPC bypass (2026-10-27)

Read-only inspection of live PostgreSQL routine grants found that both `create_offer_v1(...)` and `execute_create_offer_v1(...)` are executable by the `authenticated` role. The first function inserts into `offers` directly and does not itself write an `action_executions` row, idempotency record, or `ACTION_SUCCEEDED` event. This means an authenticated client that can call the RPC directly could bypass the Universal Action Runtime's audit/idempotency path.

### Branch-only mitigation proposed

Added `supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql` to revoke `PUBLIC` and `authenticated` execution on the low-level `create_offer_v1` function, while explicitly retaining authenticated execution on `execute_create_offer_v1`.

- This is an additive migration file on the PR branch only.
- It has **not** been applied to Supabase.
- Before production application, verify the migration against a disposable database and confirm that `execute_create_offer_v1` can still call `create_offer_v1` under its SECURITY DEFINER owner.
- Regression tests must prove authenticated direct RPC is denied, the supported runtime path still creates a single offer, same-key retries do not duplicate, and failure rolls back the execution/idempotency rows.
- The legacy `app/api/offers/route.ts` writes directly to `offers` under RLS and is not calling the low-level RPC; this mitigation does not yet unify that route.

Security Gate remains NOT PASS until these checks pass.

## HTTP validation regressions added — 2026-10-27

Added Playwright cases in `tests/e2e/auth-smoke.spec.ts` for malformed quantity, malformed price, and malformed JSON attributes on the legacy multipart offer endpoint. These assert HTTP 400 responses before authentication/database access.

This is a narrow regression improvement only. It does not establish that authenticated offer creation is authorized, idempotent, concurrency-safe, or routed through the Universal Action Runtime. It also does not exercise PostgreSQL routine grants or SECURITY DEFINER behavior. The PR's security gate remains NOT PASS pending isolated PostgreSQL integration tests and a deliberate compatibility/security contract for draft offers and demand visibility.


## CI feedback — 2026-10-27

The latest run before this correction passed dependency audit, TypeScript, production build and CodeQL. Playwright reported 15 passed and one failed: the malformed-attributes test expected HTTP 400 before authentication, but the current route parses attributes only after authentication and reference validation. The test asserted an order the implementation does not promise, so it was removed instead of changing the endpoint's behavior just to satisfy the test. The replacement commit's CI must be checked before considering the regression set green. No production database changes were made.


## SQL numeric boundary regression — 2026-10-27

- Follow-up review found that PostgreSQL `numeric` supports special values such as `NaN` and `Infinity`; comparisons like `quantity <= 0` or `price < 0` do not reliably reject all such values.
- Branch-only fix: `execute_create_offer_v1` now rejects `NaN`, `Infinity`, and `-Infinity` for quantity and price before creating execution/idempotency rows.
- This change is committed to the PR branch, but has not yet been exercised against PostgreSQL. CI verifies the application pipeline, not this SQL branch.
- Required isolated SQL tests: call the wrapper with each special numeric value for both quantity and price; assert rejection and no offer, action execution, idempotency key, or success event is committed.
- Production remains untouched. Security Gate remains NOT PASS until the isolated PostgreSQL tests and the demand-visibility authorization contract are satisfied.


## CI hard gate and live demand-link coverage — 2026-10-27

### Verified CI for the audit-gate change

- Commit `7437f53f03dcd3492dfe700eea54a19e79aa583d`.
- QIMA CI run [40502419667](https://github.com/meridane/QimaTrade-MVP/actions/runs/40502419667): **SUCCESS**. PostgreSQL integration/concurrency tests, TypeScript, npm audit, production build and Playwright browser smoke tests all completed successfully.
- CodeQL run [40502419705](https://github.com/meridane/QimaTrade-MVP/actions/runs/40502419705): **SUCCESS**.
- Vercel Preview check: **SUCCESS**. This is not a production deployment.
- The npm audit artifact for this run was downloaded and inspected: 0 total vulnerabilities across 112 dependency entries (30 production, 45 development, 61 optional; categories do not necessarily sum to unique installed packages).
- CI workflow now has an `Enforce dependency audit result` step that fails the verification job if the audit step did not complete successfully. The audit itself is still run with `--audit-level=high`; low/moderate findings are reported but do not independently fail the audit command. Current report has none.

### Read-only data relationship check

- Live schema has `product_requests.tenant_id` and nullable `product_requests.demand_id`, but no `tenant_id` column on `demands`.
- Read-only aggregate query returned 23 demands: 10 have at least one linked `product_requests` row; 13 have no linked product request. Thus, using `product_requests` as the sole authorization bridge would leave 13 existing demands without a tenant mapping and could not safely be treated as the universal rule.
- This evidence reinforces the decision not to infer a tenant-ownership guard or use `is_demand_participant` as the new-provider authorization rule. A documented public-marketplace eligibility predicate is still required.

### Current status

The SQL integration tests validate the proposed functions against an isolated synthetic fixture, not full live-schema/RLS parity. PR #26 remains open and draft. No production migration, privilege change, real offer creation, or merge occurred. Security Gate remains **NOT PASS** pending demand authorization, draft-route compatibility, complete migration parity, targeted Supabase security review, lockfile/reproducibility, and branch protection verification.


## Migration inventory parity — 2026-10-27 (read-only)

- Supabase migration history contains **161** applied migration records; the repository branch currently contains **17** SQL files under `supabase/migrations/`.
- The remote history's latest entry is `20261026034925 enable_rls_on_unexposed_reference_tables`; the branch's two new CREATE_OFFER migration files are proposals dated 2026-10-27 and are not in the remote migration history.
- This is a substantial migration-history/repository parity gap. It does not by itself prove that every absent historical file is required to recreate production, but it means the current repository cannot be assumed to reproduce the live database from scratch.
- Do not run `supabase db reset`, `db push`, or bulk-replay the local migration directory against production to "fix" this gap. Next safe step is to export/read the full remote schema and migration inventory into a separate reconciliation artifact, map each remote migration to a source file or explicit baseline/exception, and test a clean disposable database before proposing any migration strategy.
- No migration applied and no production changes made.


## Supabase SECURITY DEFINER inventory and GitHub branch controls — 2026-10-27 (read-only)

### Supabase routine inventory

A live read-only catalog query returned 19 functions in schema `public` marked `SECURITY DEFINER`. All 19 declare `search_path=public`; none is executable by role `anon`. The catalog reports authenticated execution for the application-facing helpers and RPCs, including `create_offer_v1`, `execute_create_offer_v1`, `dt_submit_answer`, `dt_publish_product_request`, and participant/access helpers. Service-role-only entries include auth-related routines; other routines have no direct authenticated/anon execution.

This is an inventory, not proof that every routine is vulnerable. Each callable routine needs review of caller assumptions, row authorization, fully qualified object references, and whether a fixed `search_path` is safe for its body. In particular, the live database still grants authenticated execution on low-level `create_offer_v1`; the branch-only revoke migration has not been applied. Do not revoke all SECURITY DEFINER functions indiscriminately because RLS helpers/triggers may require their current grants.

### GitHub controls

- Read-only GitHub branch metadata reports `main.protected=false` and `fix/create-offer-status-contract.protected=false` with required status checks disabled.
- Repository rulesets endpoint returned an empty list.
- The direct branch-protection endpoint returned HTTP 403 for this integration, so required reviews/other settings could not be exhaustively inspected. The metadata nevertheless indicates that classic branch protection is not enabled on main or this feature branch.
- Do not change repository settings without explicit approval. Recommended target: protect `main`, require PR reviews and the CI/CodeQL checks, block force-push/deletion, and ensure the rules are configured with the checks' exact context names.

No database grants, branch settings, production schema, or production data were changed. Security Gate remains **NOT PASS**.


## CI result and lockfile artifact — 2026-10-27

- Commit `3ef0a6edc77c7c168d52e915984b80ff54fda15e` passed QIMA CI run [40505094643](https://github.com/meridane/QimaTrade-MVP/actions/runs/40505094643): generated lockfile, `npm ci`, dependency audit, TypeScript, production build, Playwright Chromium install, browser smoke tests, audit enforcement and disposable PostgreSQL integration/concurrency tests all succeeded.
- CodeQL run [40505094565](https://github.com/meridane/QimaTrade-MVP/actions/runs/40505094565) succeeded.
- Vercel Preview deployment is Ready: https://qimatrade-mvp-git-fix-create-offer-status-contract-bmk1.vercel.app
- CI generated a `package-lock.json` artifact (artifact ID `12734786467`, SHA-256 `96c72a29068f53ff100c3213cefcef8174bd708cba69e1b9b4210f27422dca8a`). It is currently an artifact, not a committed repository file. Do not claim dependency reproducibility is complete until this exact lockfile is reviewed, committed, and CI consumes the committed file rather than regenerating it.
- The integration test uses a synthetic disposable schema that intentionally models only the tested columns/constraints. Passing it does not prove full production schema parity or prove tenant-to-demand authorization.
- Remote Supabase migration history lists 161 applied versions, latest `20261026034925 enable_rls_on_unexposed_reference_tables`; repository currently has only 17 local SQL migration files. This is a migration-source/parity gap, not proof that each remote migration is simply missing. Build a complete version-to-source reconciliation table before any reset or replay.
- Security Advisor at 2026-10-27 still reports 45 RLS-enabled tables without policies (INFO; inspect table grants and whether each table is intentionally closed), 17 authenticated-executable SECURITY DEFINER functions (WARN), and `pg_trgm` in `public` (WARN). Do not bulk-revoke function grants or move the extension without checking dependencies and intended API contracts. Password protection status must be verified in Auth settings separately.
- GitHub metadata previously showed classic protection disabled for `main` and no rulesets; the connected GitHub integration cannot change/read all admin-only settings. Repository owner must enable branch protection manually unless administrative access is explicitly granted.
- No production migration was applied, no production rows were written, no offer was created, and PR #26 remains open/draft/unmerged.

## Decision gates that cannot safely be inferred

1. Demand eligibility: document the authorized rule connecting a supplier actor/tenant to a demand. `demands` has no `tenant_id`; 13 of 23 demands had no linked `product_requests` in the previous read. Until ownership/publication semantics are defined, do not add a guessed tenant guard.
2. Draft offers: current multipart `app/api/offers/route.ts` accepts missing demand/Product Master and missing price, and directly inserts offers. Runtime `CREATE_OFFER` requires demand, active Product Master, and price. The safe design is a separate explicit draft action/status or a compatibility adapter, but choosing between those changes business semantics and requires a documented product rule.
3. Zero/null price and currency: confirm whether zero is a valid price and whether currency is required for a draft without a price. Attribute validation should use the canonical Attribute Engine contract and be tested server-side.
4. Admin-only controls: branch protection and Supabase Auth breached-password protection need owner/admin action if connector permissions do not allow them.

## Gate status

**NOT PASS** — CI and CodeQL are green for the current commit, but CI success is not equivalent to completion of the security audit. Open gates: commit/reuse the lockfile, migration reconciliation, demand authorization contract, draft compatibility, attribute/price validation contract, function-by-function privilege review, and branch/Auth settings.


## Latest validation and next implementation boundary — 2026-10-27

### Verified automated results
- Commit `73ea68d550a00a0839ced24c75a4bf38012fa9a6`:
  - QIMA CI run [40514820339](https://github.com/meridane/QimaTrade-MVP/actions/runs/40514820339): **SUCCESS**.
  - CREATE_OFFER PostgreSQL isolated integration/concurrency job: **SUCCESS**.
  - npm audit, TypeScript, production build and Playwright browser smoke tests: **SUCCESS**.
  - CodeQL run [40514820258](https://github.com/meridane/QimaTrade-MVP/actions/runs/40514820258): **SUCCESS**.
- The latest documentation-only commit `84b0b2d0333ad85987e5380d0992de4aefc41812` must have its own checks confirmed before the branch is considered fully green.
- The PostgreSQL tests run against a disposable synthetic fixture, not the full live Supabase schema or its complete RLS/policy set.

### Legacy draft offer compatibility matrix

| Existing form behavior | Universal CREATE_OFFER contract | Safe disposition before business approval |
|---|---|---|
| Demand ID absent | Demand required | Preserve draft path; do not silently reject or fabricate a demand |
| Product Master absent | Active Product Master required | Preserve draft path or add an explicitly defined draft action |
| Price absent/null | Numeric price required | Preserve null price semantics until the product contract decides otherwise |
| Multipart request and 303 redirect | JSON/runtime result | Keep multipart parsing and redirect as an adapter if/when the backend contract supports drafts |
| Direct insert has no action log/idempotency/event | Runtime provides execution/idempotency/event contract | Add a draft-capable transactional server action/RPC before switching this route |

Recommended technical direction, not yet implemented: introduce a separate explicit `CREATE_OFFER_DRAFT` action (or a documented draft mode of the existing action) that supports nullable demand/Product Master/price while enforcing authenticated actor ownership, tenant context, idempotency, and event logging in one transaction. Keep `CREATE_OFFER` as the strict priced offer linked to an active Product Master and demand. Do not implement this until the product owner confirms that nullable drafts remain supported and defines the allowed transition from draft to a complete offer.

### Security decision still required
The marketplace must define which demands are answerable by a supplier. Neither a `demands.tenant_id` check (column does not exist) nor `is_demand_participant` (does not authorize a first offer by a new supplier) is a valid inferred replacement. Define and test a published/visible-to-suppliers predicate that supports legitimate cross-tenant marketplace responses while preventing drafts/private demands from being answered.

### Status
CI/CodeQL are green for the code commit listed above, but overall Security Gate remains **NOT PASS**. The draft-compatible runtime route, supplier visibility predicate, migration-source reconciliation, committed lockfile, and complete target-commit checks remain outstanding. No production migration, privilege change, offer creation, or merge was performed.


## Re-check after latest documentation commits — 2026-10-27

- The code-validation commit `73ea68d550a00a0839ced24c75a4bf38012fa9a6` remains confirmed green: QIMA CI run [40514820339](https://github.com/meridane/QimaTrade-MVP/actions/runs/40514820339) and CodeQL run [40514820258](https://github.com/meridane/QimaTrade-MVP/actions/runs/40514820258) both succeeded.
- The latest documentation commit `dc2451f7c1cb3a9c50a3c75cc8efcec2a6acaed8` has Vercel Preview status **SUCCESS**: https://vercel.com/bmk1/qimatrade-mvp/FwtzenFM6beRVseVWurtRdJBaLDf
- Its own QIMA CI run [40517483076](https://github.com/meridane/QimaTrade-MVP/actions/runs/40517483076) and CodeQL run [40517482934](https://github.com/meridane/QimaTrade-MVP/actions/runs/40517482934) were queued at the time of this check. The prior code commit's green results must not be represented as checks on this latest documentation commit.
- The generated lockfile artifact from run `40514820339` was downloaded and inspected in the working environment: it contains `package-lock.json` (62,981 bytes), SHA-256 `8d90037589e58bc2d0408a0d652b29ea5fcfa414cd98af60b155846cc321837f`. The lockfile is still an artifact and is **not committed** in the branch. CI continues to regenerate it each run, so reproducible dependency resolution is not complete.
- No production Supabase writes, migrations, grants changes, offer creation, PR merge, or production deployment were performed.
