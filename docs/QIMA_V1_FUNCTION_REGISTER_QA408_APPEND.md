# QIMA V1 Function Register — QA408

## QA408 — changed p_pricing_model replay rejection

**Status:** IMPLEMENTED — pending GitHub Actions validation on the updated PR head.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa408-pricing-model-mismatch-replay-20261114-2207`  
**Base commit:** `9ed22f58151251abb1077c9462c40faaef684179`

## Scope

- Characterize the existing request-hash mapping `'pricingModel', p_pricing_model` in `execute_create_offer_v1`.
- The migration forwards `p_pricing_model` to `create_offer_v1`; the disposable fixture exposes `offers.pricing_model` as text.
- The first request uses `fixture-pricing-model-original`; the same-tenant/same-key replay changes only `p_pricing_model` to `fixture-pricing-model-replay`.
- Both calls retain the same non-target `p_offer_type = 'fixture-offer-type-stable'` and all other effective parameters remain identical.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer is persisted.
- Verify the original request hash, idempotency result, completed execution, original pricing model and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage checks the hash mapping exactly once and before the mismatch guard/persistence, fixture column, low-level function forwarding, both pricing-model arguments, stable non-target offer type, identical remaining parameters, read-only persisted-state assertions, and Verify/PostgreSQL 16/PostgreSQL 17.6 workflow wiring.

## Validation state

- QA407 prerequisite is CLOSED: QIMA CI [#43592280751](https://github.com/meridane/QimaTrade-MVP/actions/runs/43592280751) completed SUCCESS. Verify, npm audit, TypeScript, Next.js build and **347/347** Playwright tests passed.
- PostgreSQL 16 and PostgreSQL 17.6 full jobs completed SUCCESS; each log contains exactly one explicit `QA407 PASS` marker.
- CodeQL [#43592280688](https://github.com/meridane/QimaTrade-MVP/actions/runs/43592280688) and the combined Vercel status for the QA407 PR head completed SUCCESS.
- QA408 static coverage and runtime validation are pending the updated PR-head workflow; no runtime result is claimed yet.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing loopback-only integration runner.
- Synthetic pricing-model labels characterize hash sensitivity only; they do not define or approve a production pricing-model taxonomy or assert that these labels are valid in Production.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- The demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
