# QIMA V1 Function Register — QA403

## QA403 — changed p_geography replay rejection

**Status:** IMPLEMENTED — QA403 static Verify, npm audit, TypeScript, production build and 347 Playwright tests PASS in CI #43575168210; full PostgreSQL 16/17.6 jobs remain in final characterization.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa403-geography-mismatch-replay-20261114-1711`  
**Base commit:** `20eda0d2d83d1b1b845c421caa4e14acb1fa5c96`

## Scope

- Characterize the existing request-hash mapping `'geography', p_geography` in `execute_create_offer_v1`.
- The first disposable request creates an offer with `p_geography = 'KR'`.
- The replay uses the same tenant, idempotency key, input, name, demand, product, provider actor, quantity, price, currency and every other optional parameter unchanged, but changes only `p_geography` to `'US'`.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer can be persisted.
- Verify the original request hash, idempotency result, completed execution, original offer geography and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage verifies the migration hashes `p_geography` exactly once before the mismatch guard and persistence, all other effective parameters remain identical, the runtime assertions are read-only, and Verify / PostgreSQL 16 / PostgreSQL 17.6 wiring exists.
- The existing general runtime suite already contains a simple geography mismatch assertion. QA403 adds a dedicated fixture and explicit original-state preservation checks across all four persistence tables.

## Validation state

- The migration contains `'geography', p_geography`; the disposable fixture defines `offers.geography` as text and the existing NULL-default characterization reads it back.
- The scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-geography-mismatch-replay-contract.sh`.
- The Verify workflow invokes the new static contract exactly once; both PostgreSQL jobs use the existing isolated CREATE_OFFER integration runner.
- No application code or migration is changed.
- QIMA CI [#43574871835](https://github.com/meridane/QimaTrade-MVP/actions/runs/43574871835) first failed Verify because the copied QA403 block still emitted a second `QA402 PASS` marker; the marker was corrected in commit `9abe4980e7731132b7d7ffd25cf53eed2f6693a7`.
- QIMA CI [#43574996910](https://github.com/meridane/QimaTrade-MVP/actions/runs/43574996910) passed the QA403 static contract, but both PostgreSQL runtime jobs failed before the function call with `argument name "p_geography" used more than once`. The QA402 template's unchanged `p_geography => NULL` argument had been retained after changing the tested parameter to geography, so each call had a duplicate named argument. This is a test-fixture defect, not an application failure or evidence of a Production vulnerability. The duplicate argument has been removed and a static assertion now requires exactly two geography arguments (one per call) and no additional NULL geography argument.
- QIMA CI [#43575168210](https://github.com/meridane/QimaTrade-MVP/actions/runs/43575168210) on corrected code commit `f388d16d5290649a0a23598f47dbbfb240c3b891` completed the Verify/typecheck/audit/build/browser job with SUCCESS. The QA403 static contract passed, npm audit at the configured high threshold passed, TypeScript and Next.js production build passed, and Playwright completed **347/347**.
- The full PostgreSQL 16 and PostgreSQL 17.6 jobs both passed the CREATE_OFFER integration/concurrency step and continued through final runner privilege, catalog, ACL and database-setting characterizations. They were still in progress at the latest check; no `QA403 PASS` runtime marker is claimed yet.
- CodeQL [#43575168238](https://github.com/meridane/QimaTrade-MVP/actions/runs/43575168238) completed SUCCESS for corrected code commit `f388d16d5290649a0a23598f47dbbfb240c3b891`.
- Vercel Preview for corrected code commit `f388d16d5290649a0a23598f47dbbfb240c3b891` is READY: [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/GVxk2iuveiK4ne8n4bE5dbJUtYLB). The later documentation-only checkpoint HEAD has a combined Vercel status of `build-rate-limit`; no separate Preview Ready is claimed for that docs-only HEAD.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing loopback-only integration runner.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- The separate demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
