# QIMA V1 Function Register — QA404

## QA404 — changed p_market replay rejection

**Status:** CLOSED — QIMA CI [#43577222315](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577222315) completed SUCCESS on checkpoint commit `4fb984510621dd38ad2e9273fd5373eff07624cf`; Verify, both full PostgreSQL jobs, CodeQL and explicit QA404 runtime markers are confirmed successful.  
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
- QIMA CI [#43577037530](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577037530) started for code commit `f0136cf53a2d8b7edd7375107cbd45a6f679d8b5`. Its Verify job completed SUCCESS: the QA404 static contract passed, npm audit at the configured high threshold passed, TypeScript passed, the Next.js production build passed, and Playwright completed **347/347**.
- The PostgreSQL 16 `Run isolated CREATE_OFFER integration and concurrency tests` step and PostgreSQL 17.6 `Run CREATE_OFFER integration and concurrency tests on PostgreSQL 17` step both completed SUCCESS. Their full jobs were still running the remaining privilege, RLS, ACL and cleanup characterizations at this checkpoint. No explicit `QA404 PASS` log marker is claimed until the completed job logs can be inspected.
- CodeQL [#43577037553](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577037553) completed SUCCESS.
- The combined Vercel status for this HEAD reports `build-rate-limit`. The separate Vercel Preview Comments check completed SUCCESS with no unresolved feedback; that is not a deployment-ready confirmation.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing loopback-only integration runner.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- The separate demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.

## Final closure — 14 November 2026

- QIMA CI [#43577222315](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577222315) completed SUCCESS for checkpoint commit `4fb984510621dd38ad2e9273fd5373eff07624cf`. Verify passed the QA404 static contract, npm audit (configured high threshold), TypeScript, Next.js production build and **347/347** Playwright tests.
- The complete PostgreSQL 16 job completed SUCCESS; its log contains exactly one explicit `QA404 PASS` marker and the remaining privilege, catalog, ACL, RLS and cleanup assertions completed.
- The complete PostgreSQL 17.6 job completed SUCCESS; its log contains exactly one explicit `QA404 PASS` marker and the remaining privilege, catalog, ACL, RLS and cleanup assertions completed.
- CodeQL [#43577222369](https://github.com/meridane/QimaTrade-MVP/actions/runs/43577222369) completed SUCCESS.
- The combined Vercel status for this documentation checkpoint commit reports `build-rate-limit`; this is a provider build-capacity limitation, not a demonstrated source compilation failure.
- QA404 is CLOSED. This is a regression characterization of the existing `p_market` request-hash field, not a finding of a Production vulnerability.
