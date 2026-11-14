# QIMA MKT-0.9 — CREATE_OFFER runtime contract and test gate

Date: 2026-10-28
Branch: `fix/create-offer-status-contract`
Review scope: migration and isolated-test harness source inspection. No tests were executed by this review tool.

## Confirmed from source

1. `execute_create_offer_v1` rejects `p_price IS NULL`, NaN, Infinity, and negative values with `INVALID_PRICE`.
2. `app/offers/actions.ts` allows an empty price in form validation, then sends `price: price ?? 0` to the universal action. This silently turns an omitted price into zero.
3. `app/api/actions/create-offer/route.ts` uses `Number(body.price)`; an omitted price becomes `NaN`, which the SQL function should reject.
4. The standalone draft route `app/api/offers/route.ts` directly inserts a nullable price into `public.offers` and does not call the universal action.
5. The branch includes a proposed migration `20261027100000_restrict_direct_create_offer_rpc.sql` that revokes direct EXECUTE on `create_offer_v1` from PUBLIC and authenticated, while granting the supported runtime RPC. It is branch-only; not applied to production.
6. The integration test runner is explicitly intended for a disposable PostgreSQL database and includes the fixture schema, both proposed migrations, runtime assertions and concurrent duplicate-key assertions.
7. CI's PostgreSQL service is PostgreSQL 16 while the inspected Supabase production instance is PostgreSQL 17. This is not automatically a blocker, but compatibility should be validated or the test version aligned.

## Blocking contract question

The UI and SQL currently disagree on whether a demand-response offer may have no price. The database runtime requires a numeric price, but the demand-response UI treats it as optional. Before changing code, choose one explicit contract:

- Option A (lowest schema impact): price is required for a demand response; keep no-price only for an independent draft. Add UI/server validation and ensure the API returns a clear 400 instead of a database error.
- Option B: price may be absent for a demand response; update the database function, table constraints, idempotency hash and downstream matching/pricing logic to preserve NULL or a distinct “price pending” state. This needs a reviewed migration and regression tests.

Do not map an absent price to zero unless zero is a genuine quoted price.

## Authorization test coverage gap

Current fixture tests exercise tenant membership and provider-actor spoofing. The test excerpt reviewed does not establish a test that a provider belonging to tenant A cannot respond to a demand owned by tenant B when both users are otherwise authenticated. Add this as a separate negative regression test once the demand/tenant ownership rule is specified.

## Current gate status

- Vercel Preview status for head commit `9bbc0c2d782ce13be5e64a61415429ed117f9924`: success.
- PR #26: open, draft, unmerged; GitHub currently reports mergeable.
- The workflow-run query returned no run record for this commit, so CI typecheck, build, npm audit and PostgreSQL integration results are not asserted here.
- No production database changes, migrations, permission changes, merge or production deployment occurred.

## Next action

Resolve the price contract and document the demand-owner/tenant/provider relationship. Then implement only on a branch and validate with CI before requesting review.