# QIMA V1 Function Register — QA409

## QA409 — changed p_product_master_id replay rejection

**Status:** IMPLEMENTED — pending GitHub Actions validation on the updated PR head.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa409-product-master-mismatch-replay-20261114-2309`  
**Base commit:** `fcb83fa734a6a7613bed291c7804124431bd3c8f`

## Scope

- Characterize the existing request-hash mapping `'productMasterId', p_product_master_id` in `execute_create_offer_v1`.
- Confirm the migration forwards `p_product_master_id` to the low-level `create_offer_v1` call and the disposable fixture persists `offers.product_master_id`.
- The first request uses the existing active fixture product master `40000000-0000-4000-8000-000000000001`; the same-tenant/same-key replay changes only `p_product_master_id` to the alternate active fixture product master `40000000-0000-4000-8000-000000000002`.
- Keep the demand ID, provider actor, input, name, quantity, price, currency and all optional business parameters identical.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer is persisted.
- Verify the original request hash, idempotency result, completed execution, original product master ID and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Execute the SQL regression separately after the shared disposable fixture/migration runner in PostgreSQL 16 and PostgreSQL 17.6 jobs.
- Static coverage checks the hash mapping exactly once and before the mismatch guard/persistence, the fixture foreign key and alternate active product master, low-level function forwarding, original/replay IDs, unchanged non-target parameters, read-only persisted-state assertions and all three CI workflow hooks.

## Validation state

- QA408 prerequisite is CLOSED: QIMA CI [#1440](https://github.com/meridane/QimaTrade-MVP/actions/runs/43598662540) completed SUCCESS. Verify, PostgreSQL 16, PostgreSQL 17.6 and the two explicit `QA408 PASS` markers passed; npm audit, TypeScript, Next.js build and **347/347** Playwright tests passed.
- CodeQL [#1388](https://github.com/meridane/QimaTrade-MVP/actions/runs/43598662478) and the combined Vercel status for the QA408 PR head completed SUCCESS.
- QA409 static coverage and PostgreSQL runtime validation are pending the workflow triggered by this commit. No QA409 runtime result is claimed yet.

## Safety and decision boundaries

- Runtime validation uses only the existing disposable PostgreSQL CI service and loopback-only `DATABASE_URL`; the new SQL file performs the CREATE_OFFER function call and read-only persisted-state assertions.
- Both product-master IDs are pre-seeded active synthetic rows in the disposable fixture. They are not production identifiers and do not define or approve a product-master taxonomy.
- This test characterizes only idempotency hash sensitivity to `p_product_master_id`. It does not establish or test the separate demand-to-tenant ownership contract described in PR #26; that remains blocked on a documented business ownership model and approved negative tests.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- MKT-1.1, MKT-1.2 and MKT-1.3 remain subject to business approval.
