# CREATE_OFFER regression and security test plan

Status: preparation only — no production database access and no SQL execution.
Target change: PR #26, commit 54dec2d3f255b04319416e2279429dcd7522f168.
Migration under review: supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql

## Confirmed code facts from repository review

- The migration writes action_executions statuses RUNNING and COMPLETED, and idempotency_keys statuses IN_PROGRESS and COMPLETED, in uppercase to match the constraints described by the PR.
- It preserves the external JSON status "succeeded".
- It computes the idempotency hash across p_input plus business parameters.
- It verifies that the authenticated user belongs to p_tenant_id.
- It checks that provider_actor_id equals the actor returned by a LIMIT 1 profile lookup.
- It verifies that the demand exists, but does not prove that the demand belongs to the submitted tenant or is authorized for this offer.
- Idempotency lookup uses SELECT ... FOR UPDATE, but when no row exists there is nothing to lock. Concurrent first requests with the same tenant/key can race; the unique constraint may reject one request. That may prevent duplicate offers if the whole call is transactional and constraints are correct, but behavior is not a validated graceful idempotent replay.
- app/api/offers/route.ts still inserts directly into public.offers. app/api/actions/create-offer/route.ts and app/offers/actions.ts use executeUniversalAction -> execute_create_offer_v1.
- app/offers/actions.ts and app/api/actions/create-offer/route.ts use dt_memberships ... LIMIT 1 to select tenant, so a multi-tenant user can be assigned an arbitrary tenant.
- The repository migration directory is not a complete reproduction of the remote database; do not reset or blindly replay migrations.

## Required isolated regression cases

Run only against a disposable Supabase/local PostgreSQL database with the exact compatible schema and function dependencies. Do not run these against production and do not create offers in production.

1. Status contract:
   - A valid request creates one offer and one action_executions row with status COMPLETED.
   - It creates one idempotency_keys row with status COMPLETED.
   - Its public JSON returns status "succeeded" and a stable objectId/executionId.
   - No lowercase "running" or "succeeded" is written into status columns.

2. Idempotency:
   - Same tenant + same key + same effective parameters: repeated calls return the same result and do not create a second offer.
   - Same tenant + same key + changed quantity, price, currency, demand, product, attributes, lifecycle, or offer type: reject with IDEMPOTENCY_KEY_REUSE.
   - Same key string in different tenants: verify the intended uniqueness scope and independent behavior.
   - Concurrent calls with same tenant/key and identical body: exactly one offer; second call either returns the first result or a documented retryable conflict. No duplicate offer.
   - Concurrent same key but different body: at most one operation commits and the other must be rejected without leaving partial rows.

3. Authorization / tenant boundaries:
   - Unauthenticated caller rejected.
   - User with no membership in p_tenant_id rejected.
   - User belonging to tenant A cannot create against tenant B.
   - User in tenant A cannot create an offer for a demand owned/requested by tenant B.
   - User cannot spoof provider_actor_id.
   - A published decision tree/action definition in one tenant must not be accidentally accepted for another tenant if definitions are tenant scoped.
   - Profile lookup must be deterministic or enforce one applicable actor per authenticated identity; no arbitrary LIMIT 1 if multiple rows are legal.

4. Input contract:
   - Invalid/null demand, inactive/missing Product Master, missing currency, zero/negative quantity, negative price, null idempotency key, or null p_input are rejected without partial action/idempotency/event/offer rows.
   - Confirm whether price is permitted to be zero and whether currency is required when price is null; match the API contract.
   - Confirm attribute schema requirements/types/options/units are validated server-side rather than only by UI.

5. Audit:
   - Successful execution creates exactly one ACTION_SUCCEEDED event with matching execution, actor, tenant, correlation ID, and offer.
   - Exceptions/rollback do not leave orphan RUNNING/IN_PROGRESS rows or partial offers.
   - Define whether failed executions are intentionally persisted; PostgreSQL function exceptions normally roll back writes in the same transaction.

## Architectural follow-up

- Unify app/api/offers/route.ts to use the Universal Action Runtime, preserving its existing form response/redirect contract and validation. Do not simply delete the route.
- Replace arbitrary tenant selection with an explicit tenant context chosen from authenticated memberships (or require exactly one membership and return a clear error when more than one exists).
- Document and enforce the demand ownership model before extending the SQL authorization predicate.
- Do not mark Security Gate PASS until isolated DB tests, tenant negative tests, concurrency tests, and the existing code gates all pass.

## Validation evidence as of 2026-10-27

- GitHub PR #26 is open, draft, and not merged.
- QIMA CI run 40355755095: success. Job steps report dependency audit, TypeScript, production build, Playwright Chromium installation, and browser smoke tests completed successfully.
- QIMA CodeQL Security run 40355755332: success. Analyze JavaScript and TypeScript completed successfully.
- These checks do not demonstrate that execute_create_offer_v1 was run against a database.
- No migration was applied and no production offer was created as part of this review.
