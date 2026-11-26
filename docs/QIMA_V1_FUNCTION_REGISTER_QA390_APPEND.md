# QA390 — CREATE_OFFER SQL NULL numeric boundary regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa390-null-numeric-boundaries-20261114-0316
Parent HEAD: 8a2c73a2defa41d8aef8f342f97f1b260e616037
Status: CLOSED — QIMA CI #1403 SUCCESS

## Initial state verified

- PR #26 is OPEN, draft, mergeable and unmerged; HEAD verified: 8a2c73a2defa41d8aef8f342f97f1b260e616037.
- The latest completed QIMA CI run on that HEAD was [#1402](https://github.com/meridane/QimaTrade-MVP/actions/runs/43478281064), conclusion SUCCESS.
- Verify, PostgreSQL 16 and PostgreSQL 17.6 jobs all completed SUCCESS. The PostgreSQL logs contain QA389 PASS and QA381 passed.
- QIMA CodeQL [#1350](https://github.com/meridane/QimaTrade-MVP/actions/runs/43478281072) and the Vercel Preview status check completed SUCCESS.
- QA389 was confirmed CLOSED before starting QA390.

## Objective

The current migration explicitly rejects SQL NULL for p_quantity and p_price with INVALID_QUANTITY and INVALID_PRICE. The existing numeric boundary tests cover NaN, positive/negative Infinity, zero and finite negative values, but the inspected runtime scenarios did not isolate SQL NULL for both required numeric arguments with four-table before/after assertions. QA390 adds those two missing cases without changing the domain rules.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Case 1 passes p_quantity = NULL::numeric with a valid finite price and requires exactly INVALID_QUANTITY.
   - Case 2 passes p_price = NULL::numeric with a valid finite quantity and requires exactly INVALID_PRICE.
   - Each case has a unique tenant-scoped idempotency key and offer name.
   - Each case compares before/after row counts for idempotency_keys, action_executions, offers and action_events.
   - Each case verifies that its idempotency key, execution and offer remain absent.
   - The block emits one QA390 PASS marker after both cases succeed.
2. Added tests/sql/test-create-offer-null-numeric-contract.sh.
   - Requires the existing SQL NULL guards and exact INVALID_QUANTITY / INVALID_PRICE errors in the migration.
   - Requires both isolated runtime cases, exact error assertions and four-table no-side-effect checks.
   - Requires the Verify step and shared PostgreSQL 16/17.6 runtime wiring.
3. Added the QA390 static contract to the Verify job.

## Validation

- The generated SQL block, static shell contract and workflow insertion were checked for exact fixture names, guard strings, markers and single-occurrence wiring.
- QA390 is CLOSED after QIMA CI [#1403](https://github.com/meridane/QimaTrade-MVP/actions/runs/43481871260) completed SUCCESS on HEAD f46b603934d82056d69597708598b6eae8d8d74a. Verify job 132080127263 emitted QA390 PASS; PostgreSQL 16 job 132080127314 and PostgreSQL 17.6 job 132080126694 each emitted the runtime QA390 PASS marker and completed SUCCESS. Both full jobs also emitted QA381 passed and all later catalog, ACL, RLS, runner-privilege and cleanup steps succeeded.
- This test characterizes existing SQL NULL rejection only; it does not introduce new acceptance or canonicalization behavior.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No numeric canonicalization or new business rule was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## Final validation and closure — 14 November 2026

- PR #26 remained OPEN, draft and unmerged at HEAD f46b603934d82056d69597708598b6eae8d8d74a.
- QIMA CI [#1403](https://github.com/meridane/QimaTrade-MVP/actions/runs/43481871260) completed SUCCESS.
- Verify job 132080127263 emitted QA390 PASS; npm audit at the high threshold, TypeScript, Next.js build and 347/347 Playwright tests passed.
- PostgreSQL 16 job 132080127314 and PostgreSQL 17.6 job 132080126694 each emitted QA390 PASS and QA381 passed; all subsequent catalog, ACL, RLS, runner-privilege and cleanup steps completed SUCCESS.
- QIMA CodeQL [#1351](https://github.com/meridane/QimaTrade-MVP/actions/runs/43481871281) completed SUCCESS. The Vercel status check for HEAD completed SUCCESS.
- QA390 is CLOSED. These are disposable CI regression tests, not a Production validation or proof of a vulnerability.
- No application code, migration, Supabase Production data, secret, persistent PostgreSQL setting, branch-protection rule, PR merge or Production deployment was changed.
