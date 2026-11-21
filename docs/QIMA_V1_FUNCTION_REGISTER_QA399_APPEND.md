# QIMA V1 Function Register — QA399

## QA399 — JSONB array order remains significant for p_attributes idempotency

**Status:** CLOSED — QIMA CI #1421 completed successfully  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa399-jsonb-array-order-significant-20261114-1305`  
**Base commit:** `f95f1cbd837945de28eeccc12d7a30926dd2b221`

## Scope

- Exercise the existing `execute_create_offer_v1` function with one completed tenant-scoped idempotency key.
- The first request supplies `p_attributes = {"items":["alpha","beta"],"meta":{"region":"kr"}}`.
- The replay keeps every other effective parameter identical and changes only the array to `["beta","alpha"]`.
- Assert that the two JSONB values and their canonical `jsonb::text` representations are distinct before the replay.
- Require the replay to raise the exact `IDEMPOTENCY_KEY_REUSE` error.
- Require unchanged row counts in `idempotency_keys`, `action_executions`, `offers` and `action_events`.
- Verify the original request hash, completed idempotency result, execution, offer attributes and success event remain unchanged.
- Static coverage confirms the existing request hash includes `coalesce(p_attributes, '{}'::jsonb)`, the two calls differ only in `p_attributes`, and Verify plus both PostgreSQL 16/17.6 jobs remain wired.

## Validation state

- Source review confirms the existing migration hashes the complete `p_attributes` JSONB value; PostgreSQL JSONB preserves array element order while canonicalizing object key order.
- This scenario uses text-only array elements and does not test numeric lexical canonicalization or change MKT-1.3.
- No migration or application code is changed.
- Runtime SQL is appended to `tests/sql/create-offer-runtime.sql`; static contract is `tests/sql/test-create-offer-attributes-array-order-replay-contract.sh`.
- QIMA CI [#1416](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555179600) completed with overall FAILURE. The QA399 static Verify step, npm audit, TypeScript, production build and browser smoke tests completed SUCCESS; CodeQL [#1364](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555179638) completed SUCCESS.
- Both PostgreSQL runtime jobs failed at the same QA399 assertion: `QA399 initial request did not persist exactly one idempotency row, execution, offer and event`. The test compared scoped post-call counts (filtered to the QA399 key/offer/execution) with `v_before` global table counts, so those quantities were not comparable. This is a regression-test accounting defect, not evidence of an application or Production defect.
- Correction: remove the unrelated global baseline and assert exactly one row in each QA399-scoped persistence query after the first call; the existing fixture-absence guard and post-replay equality checks remain. The static contract now rejects any `v_before` reference and requires all four exact-one assertions.
- QIMA CI [#1418](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555387436) also completed FAILURE. Verify rejected the still-present QA399 `v_before` declaration; both PostgreSQL jobs failed earlier in the shared SQL runner because a broad first-occurrence replacement had removed the unrelated `v_before` declaration from QA91. The logs report `"v_before" is not a known variable` in `qa91_integrity`. This was an editing-scope defect in the regression test, not an application or Production failure.
- Correction: scope the edit to the exact dollar-quoted blocks. Restore `v_before record;` in QA91, remove it only from QA399, and add static assertions that QA91 retains its declaration/baseline read while QA399 contains no `v_before` reference.
- QIMA CI [#1419](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555517101) was triggered on code commit `6f2afc94cb093a0a969b0d81c9e0ba3327ea1a5f`. Verify completed SUCCESS, including the QA399 static contract, npm audit, TypeScript, production build and browser smoke tests. The PostgreSQL 16 CREATE_OFFER runtime step and the PostgreSQL 17.6 CREATE_OFFER runtime step both completed SUCCESS; however, both full PostgreSQL jobs were still IN_PROGRESS at the latest checkpoint while later cleanup, RLS and ACL regressions continued. Runtime log artifacts were not yet downloadable, so the QA399 notice marker has not been independently confirmed in both logs.
- CodeQL [#1367](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555517063) completed SUCCESS. The Vercel status for this HEAD was FAILURE with the target `build-rate-limit`; no Preview readiness is claimed. This is an external Preview build quota/plan limit, not a source-code test result, and no billing or account setting was changed.
- QA399 is CLOSED: QIMA CI #1421 completed SUCCESS; the complete PostgreSQL 16 and 17.6 jobs both contain the explicit QA399 PASS marker, Verify completed npm audit, TypeScript, production build and 347/347 Playwright tests, and CodeQL #1369 completed SUCCESS. The Vercel check remains FAILURE with a `build-rate-limit` target; no Preview Ready is claimed and this external Preview quota does not change the QA result.

## Safety and decision boundaries

- Tests use disposable PostgreSQL CI fixtures only.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This characterizes JSONB array ordering; it is not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.
