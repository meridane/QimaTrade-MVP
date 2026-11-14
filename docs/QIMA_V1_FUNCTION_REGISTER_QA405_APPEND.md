# QIMA V1 Function Register — QA405

## QA405 — changed p_documentation_status replay rejection

**Status:** IMPLEMENTED — pending GitHub Actions validation on the updated PR head.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa405-documentation-status-mismatch-replay-20261114-1904`  
**Base commit:** `4fb984510621dd38ad2e9273fd5373eff07624cf`

## Scope

- Characterize the existing request-hash mapping `'documentationStatus', p_documentation_status` in `execute_create_offer_v1`.
- The disposable fixture exposes `offers.documentation_status` as text without imposing a new business enumeration.
- The first request uses the synthetic value `fixture-documentation-status-original`; the same-tenant/same-key replay changes only `p_documentation_status` to `fixture-documentation-status-replay`.
- All other explicitly supplied effective parameters remain identical, including a stable synthetic `p_market` value.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer is persisted.
- Verify the original request hash, idempotency result, completed execution, original offer documentation status and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage verifies the hash mapping appears exactly once before the mismatch guard and persistence, all non-target parameters remain identical, the runtime assertions are read-only, and Verify / PostgreSQL 16 / PostgreSQL 17.6 wiring exists.

## Validation state

- The existing migration maps `'documentationStatus', p_documentation_status` into the request hash and passes the parameter to `create_offer_v1`; no migration or application code is changed.
- The runtime scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-documentation-status-mismatch-replay-contract.sh`.
- The Verify workflow invokes the static contract exactly once; both PostgreSQL jobs use the existing isolated CREATE_OFFER integration runner.
- QA404 prerequisite is CLOSED: QIMA CI [#43577222315](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577222315) completed SUCCESS; both full PostgreSQL jobs contain one explicit QA404 marker; CodeQL [#43577222369](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577222369) completed SUCCESS.
- QA405 validation will be recorded after the updated PR head starts GitHub Actions.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing isolated integration runner.
- Synthetic documentation-status labels characterize hash sensitivity only; they do not define or approve a production status taxonomy.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- The demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
