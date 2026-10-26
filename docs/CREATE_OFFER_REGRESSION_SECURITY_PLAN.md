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
