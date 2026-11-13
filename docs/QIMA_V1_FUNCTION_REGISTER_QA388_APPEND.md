# QA388 — CREATE_OFFER positive-Infinity quantity and price regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa388-positive-infinity-boundaries-20261114-0113
Status: IMPLEMENTED — CI VALIDATION PENDING

## Initial state verified

- PR #26 is OPEN and not merged. Its description continues to identify the change as a draft; no review is recorded.
- HEAD verified: d60c7f4c520b3fd98bacb4ed45269641b686bec1.
- QIMA CI [#1397](https://github.com/meridane/QimaTrade-MVP/actions/runs/43451163902) completed SUCCESS on that HEAD.
- Verify emitted QA382 through QA387 PASS. PostgreSQL 16 and PostgreSQL 17.6 emitted QA387 PASS and QA381 passed; both integration jobs completed SUCCESS.
- CodeQL [#1346](https://github.com/meridane/QimaTrade-MVP/actions/runs/43451163974) and the Vercel status check completed SUCCESS.

## Objective

The migration already rejects positive Infinity for both p_quantity and p_price. Existing earlier runtime assertions reject these values, but they do not isolate the two cases with the same explicit four-table before/after persistence checks used by QA385–QA387. QA388 strengthens the no-side-effect characterization without changing the domain rule.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Positive Infinity quantity with a valid finite price must raise exactly INVALID_QUANTITY.
   - Positive Infinity price with a valid finite quantity must raise exactly INVALID_PRICE.
   - Each case uses its own tenant-scoped idempotency key and offer name.
   - Before/after row counts are compared for idempotency_keys, action_executions, offers and action_events.
   - The fixture key, execution and offer are checked for absence after each rejected call.
   - The block emits one explicit QA388 PASS marker after both cases succeed.
2. Added tests/sql/test-create-offer-positive-infinity-contract.sh.
   - Preserves both existing migration guards and exact domain errors.
   - Requires both isolated runtime cases and the no-side-effect assertions.
   - Requires the Verify contract and shared PostgreSQL 16/17.6 runner wiring.
3. Added the QA388 static contract to the Verify job.

## Validation

- Source-level construction and workflow wiring are checked before publication.
- QA388 remains PENDING until Verify emits QA388 PASS and both PostgreSQL 16 and PostgreSQL 17.6 integration jobs complete SUCCESS with the runtime marker.
- The positive-Infinity cases are regression coverage for an existing SQL contract; no application or migration behavior is changed.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No price-zero acceptance or numeric canonicalization behavior was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
