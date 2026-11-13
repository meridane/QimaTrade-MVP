# QA385 — CREATE_OFFER zero-quantity boundary regression

Date: 2026-11-13 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa385-zero-quantity-boundary-20261113-2225
Status: IMPLEMENTED — CI VALIDATION PENDING

## Initial state verified

- PR #26: OPEN, DRAFT, mergeable, not merged; base main, HEAD 1093c19ed032a95e6d7b0b00f11268a31956e035.
- QIMA CI #1393 completed SUCCESS on that parent HEAD.
- QA384 is closed after explicit Verify, PostgreSQL 16 and PostgreSQL 17.6 success markers. CodeQL #1342 and Vercel status also completed successfully.

## Objective

Protect the existing quantity boundary without changing application behavior or selecting a new business rule. The current migration explicitly rejects p_quantity <= 0 with INVALID_QUANTITY; the runtime suite had NaN, positive/negative Infinity and other invalid-input coverage, but no isolated zero-quantity boundary case.

## Changes

1. Appended a disposable PostgreSQL runtime block to tests/sql/create-offer-runtime.sql.
   - Uses an authenticated fixture identity and otherwise-valid tenant, actor, demand, product, price and currency.
   - Calls execute_create_offer_v1 with p_quantity = 0::numeric.
   - Requires exactly INVALID_QUANTITY.
   - Compares before/after counts for idempotency_keys, action_executions, offers and action_events, and verifies that the fixture key and offer are absent.
   - Emits an explicit QA385 PASS notice.
2. Added tests/sql/test-create-offer-zero-quantity-contract.sh.
   - Protects the existing strictly-positive quantity guard and exact error.
   - Requires the runtime zero case, expected error, four-table no-side-effect assertions and success marker.
   - Requires Verify plus the shared PostgreSQL 16 and 17.6 runtime runner wiring.
3. Added the QA385 contract to the Verify job in .github/workflows/ci.yml.

## Validation

- Source-level construction was reviewed against the current migration guard and shared disposable runtime fixture.
- The new Verify and PostgreSQL runtime checks have not yet executed on the new HEAD. Do not claim QA385 PASS until Verify emits its marker and both PostgreSQL jobs complete successfully.

## Safety and decision boundaries

- No migration or application code changed.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No price-zero acceptance test was added; that would freeze a separate commercial rule unnecessarily.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
