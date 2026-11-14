# QIMA V1 Function Register — QA406

## QA406 — changed p_lifecycle replay rejection

**Status:** CLOSED — QIMA CI [#43586652941](https://github.com/meridane/QimaTrade-MVP/actions/runs/43586652941) completed SUCCESS; both full PostgreSQL jobs and both explicit runtime markers are confirmed.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa406-lifecycle-mismatch-replay-20261114-1940`  
**Base commit:** `b2d4213ec84d0277ff334aff8fa99cace9f24bc2`

## Scope

- Characterize the existing request-hash mapping `'lifecycle', p_lifecycle` in `execute_create_offer_v1`.
- The disposable fixture exposes `offers.lifecycle` as text; no production lifecycle taxonomy is inferred or introduced.
- The first request uses `fixture-lifecycle-original`; the same-tenant/same-key replay changes only `p_lifecycle` to `fixture-lifecycle-replay`.
- All other effective parameters remain identical, including a stable synthetic `p_market` and `p_documentation_status = NULL`.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer is persisted.
- Verify the original request hash, idempotency result, completed execution, original offer lifecycle and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage checks the hash mapping exactly once and before the mismatch guard/persistence, both lifecycle arguments, identical non-target parameters, read-only post-call assertions, and Verify/PostgreSQL 16/PostgreSQL 17.6 workflow wiring.

## Validation state

- The existing migration maps `'lifecycle', p_lifecycle` into the request hash and passes `p_lifecycle` to `create_offer_v1`; no migration or application code is changed.
- The runtime scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-lifecycle-mismatch-replay-contract.sh`.
- The Verify workflow invokes the static contract exactly once; both PostgreSQL jobs use the existing isolated CREATE_OFFER integration runner.
- QA405 prerequisite is CLOSED: QIMA CI [#43583865145](https://github.com/meridane/QimaTrade-MVP/actions/runs/43583865145) completed SUCCESS; both full PostgreSQL jobs contain one explicit QA405 marker; CodeQL [#43583865161](https://github.com/meridane/QimaTrade-MVP/actions/runs/43583865161) completed SUCCESS.
- QIMA CI #43586652941 / run #1438 completed SUCCESS. Verify, npm audit at the configured high threshold, TypeScript, Next.js production build and Playwright **347/347** all passed.
- PostgreSQL 16 and PostgreSQL 17.6 full jobs completed SUCCESS; each runtime log contains exactly one `QA406 PASS` marker. Catalog, replication-slot, database settings, ACL, RLS, cleanup and runner-privilege checks also completed successfully.
- CodeQL [#43586652920](https://github.com/meridane/QimaTrade-MVP/actions/runs/43586652920) completed SUCCESS.
- The combined Vercel status for this documentation-only PR head is `build-rate-limit`; this is a provider quota result, not a failed application build. No Preview Ready is claimed for this head.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing loopback-only integration runner.
- Synthetic lifecycle labels characterize hash sensitivity only; they do not define or approve a production lifecycle taxonomy.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- The demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
