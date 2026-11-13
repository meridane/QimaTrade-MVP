# QA389 — CREATE_OFFER NaN quantity boundary regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa389-nan-quantity-boundary-20261114-0254
Status: IMPLEMENTED — CI VALIDATION PENDING

## Initial state verified

- PR #26 is OPEN, draft and unmerged; HEAD verified before this change: 685490710046873b69563d066277f742aeb9c36f.
- The latest completed QIMA CI run on that HEAD was [#43461032639](https://github.com/meridane/QimaTrade-MVP/actions/runs/43461032639), conclusion SUCCESS.
- Verify emitted QA382 through QA388 PASS; PostgreSQL 16 and PostgreSQL 17.6 emitted QA388 PASS and QA381 passed; both jobs completed SUCCESS.
- QIMA CodeQL [#43461032644](https://github.com/meridane/QimaTrade-MVP/actions/runs/43461032644) completed SUCCESS; the Vercel Preview status check on the same HEAD completed SUCCESS.
- QA388 was confirmed CLOSED before starting QA389.

## Objective

The existing migration rejects PostgreSQL numeric NaN for p_quantity through its explicit text-domain guard. QA384 already characterizes NaN for p_price, but its matrix does not include NaN for p_quantity. QA389 adds the missing quantity-side runtime case without changing the existing domain rule.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Uses p_quantity = 'NaN'::numeric and a valid finite price.
   - Requires exactly INVALID_QUANTITY.
   - Compares before/after row counts for idempotency_keys, action_executions, offers and action_events.
   - Verifies that the fixture idempotency key, execution and offer remain absent.
   - Emits one explicit QA389 PASS marker.
2. Added tests/sql/test-create-offer-nan-quantity-contract.sh.
   - Requires the existing migration quantity guard and INVALID_QUANTITY error.
   - Requires the isolated NaN-quantity runtime block, exact error assertion and four-table no-side-effect checks.
   - Requires the Verify step and shared PostgreSQL 16/17.6 runtime wiring.
3. Added the QA389 static contract to the Verify job.

## Validation

- Static source checks were performed on the constructed SQL block, shell contract and workflow wiring before publication.
- QA389 remains PENDING until Verify emits QA389 PASS and both PostgreSQL 16 and PostgreSQL 17.6 jobs complete SUCCESS with the runtime marker.
- The test is a regression characterization of the existing NaN rejection rule in disposable CI databases only.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No numeric canonicalization or new business acceptance rule was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
