# QIMA V1 Function Register — QA404

## QA404 — changed p_market replay rejection

**Status:** IMPLEMENTED — pending GitHub Actions validation on PostgreSQL 16 and PostgreSQL 17.6.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa404-market-mismatch-replay-20261114-1740`  
**Base commit:** `32ef9f799c7112cf7f125871090c780e776b1f9c`

## Scope

- Characterize the existing request-hash mapping `'market', p_market` in `execute_create_offer_v1`.
- The first disposable request uses the synthetic market value `fixture-market-original`.
- The replay keeps the same tenant, idempotency key, input, name, demand, product, provider actor, quantity, price, currency, geography, attributes and all other optional parameters unchanged, but changes only `p_market` to `fixture-market-replay`.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer can be persisted.
- Verify the original request hash, idempotency result, completed execution, original offer market and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage verifies the migration hashes `p_market` exactly once before the mismatch guard and persistence, all other effective parameters remain identical, the runtime assertions are read-only, and Verify / PostgreSQL 16 / PostgreSQL 17.6 wiring exists.
- Synthetic market labels test request-hash sensitivity only; they do not define or approve a business market taxonomy.

## Validation state

- The existing migration includes `'market', p_market`; the disposable fixture defines `offers.market` as text.
- The scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-market-mismatch-replay-contract.sh`.
- The Verify workflow invokes the new static contract exactly once; both PostgreSQL jobs use the existing isolated CREATE_OFFER integration runner.
- No application code or migration is changed.
- Prerequisite QA403 is CLOSED: QIMA CI [#43575452745](https://github.com/meridane/QimaTrade-MVP/actions/runs/43575452745) completed SUCCESS, including one explicit `QA403 PASS` runtime marker on each PostgreSQL version; CodeQL [#43575452736](https://github.com/meridane/QimaTrade-MVP/actions/runs/43575452736) completed SUCCESS.
- QA404 validation will be recorded after GitHub Actions starts for the updated PR head.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing loopback-only integration runner.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- The separate demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
