# QIMA V1 Function Register — QA402

## QA402 — changed optional conditions parameter rejects same-key replay

**Status:** IMPLEMENTED — QA402 static contract PASS in QIMA CI #1426; PostgreSQL runtime pending  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa402-conditions-mismatch-replay-20261114-1551`  
**Base commit:** `3d35831b70744a3fe725dfdeb77831630c5ee9de`

## Scope

- Characterize the existing request-hash mapping `'conditions', p_conditions` in `execute_create_offer_v1`.
- The first request creates an offer with `p_conditions = 'qa402-original-conditions'`.
- The replay uses the same tenant, idempotency key, input, name, demand, product, provider actor, quantity, price, currency and every other optional field, but changes only `p_conditions` to `'qa402-changed-conditions'`.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer can be persisted.
- Verify the original request hash, idempotency result, completed execution, original offer conditions and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage verifies the migration hashes `p_conditions` exactly once before the mismatch guard and persistence, exact equality of all other effective parameters, read-only runtime assertions, and Verify / PostgreSQL 16 / PostgreSQL 17.6 wiring.

## Validation state

- The existing migration includes `'conditions', p_conditions` in the effective request hash.
- The disposable fixture's `create_offer_v1` stores `p_conditions` in `offers.conditions`.
- The scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-conditions-mismatch-replay-contract.sh`.
- No application code or migration is changed.
- QIMA CI [#1426](https://github.com/meridane/QimaTrade-MVP/actions/runs/43568610148) was triggered on code-bearing commit `8b81b4ca30d518b8f921b935dfd7e79234e26222`. Verify completed successfully: the QA402 static contract, npm audit, TypeScript, Next.js production build and all 347 Playwright tests passed. The full PostgreSQL 16 and PostgreSQL 17.6 jobs remain in progress at their final runner-privilege characterization steps; no `QA402 PASS` runtime marker is claimed yet.
- CodeQL [#1374](https://github.com/meridane/QimaTrade-MVP/actions/runs/43568610095) completed successfully.
- Vercel Preview for code-bearing commit `8b81b4ca30d518b8f921b935dfd7e79234e26222` returned SUCCESS: [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/G76eFK5JFHhd1XSTo5HWo4d8DNJf). The latest documentation-only HEAD is `6eb646e43d981e457535603c2a09e834754ac7bb`; its separate Vercel status remains pending.
- QA402 remains PENDING until Verify and both complete PostgreSQL runtime jobs succeed and contain the explicit `QA402 PASS` marker.

## QA401 prerequisite closure

- QIMA CI [#1425](https://github.com/meridane/QimaTrade-MVP/actions/runs/43563313321) completed successfully. Verify passed the QA401 static contract, npm audit, TypeScript, Next.js production build and all 347 Playwright tests.
- The complete PostgreSQL 16 and PostgreSQL 17.6 jobs both succeeded; each runtime log contains the explicit `QA401 PASS` marker.
- CodeQL [#1373](https://github.com/meridane/QimaTrade-MVP/actions/runs/43563313314) completed successfully.
- Vercel Preview remains unavailable because the provider returned `build-rate-limit`; no Preview Ready status is claimed.

## Safety and decision boundaries

- Runtime tests use only the disposable PostgreSQL CI fixture and the integration runner's loopback-only `qima_test` guard.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.
