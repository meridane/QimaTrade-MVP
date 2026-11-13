# QA390 — CREATE_OFFER SQL NULL numeric boundary regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa390-null-numeric-boundaries-20261114-0316
Parent HEAD: 8a2c73a2defa41d8aef8f342f97f1b260e616037
Status: IMPLEMENTED — CI VALIDATION PENDING

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
- QA390 remains PENDING until Verify emits QA390 PASS and both PostgreSQL 16 and PostgreSQL 17.6 full integration jobs complete SUCCESS with the runtime marker.
- This test characterizes existing SQL NULL rejection only; it does not introduce new acceptance or canonicalization behavior.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No numeric canonicalization or new business rule was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
