# QIMA V1 Function Register — QA407

## QA407 — changed p_offer_type replay rejection

**Status:** CLOSED — QIMA CI [#43592280751](https://github.com/meridane/QimaTrade-MVP/actions/runs/43592280751) (run #1439) completed SUCCESS; Verify, PostgreSQL 16, PostgreSQL 17.6 and CodeQL are confirmed.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa407-offer-type-mismatch-replay-20261114-2050`  
**Base commit:** `656c5a530b0c9746caa70db0df94a769bc0a0a57`

## Scope

- Characterize the existing request-hash mapping `'offerType', p_offer_type` in `execute_create_offer_v1`.
- The migration forwards `p_offer_type` to `create_offer_v1`; the disposable fixture exposes `offers.offer_type` as text.
- The first request uses `fixture-offer-type-original`; the same-tenant/same-key replay changes only `p_offer_type` to `fixture-offer-type-replay`.
- All other effective parameters remain identical, including `p_lifecycle = NULL`, stable synthetic `p_market`, and `p_pricing_model = NULL`.
- Require the exact `IDEMPOTENCY_KEY_REUSE` error before a second execution or offer is persisted.
- Verify the original request hash, idempotency result, completed execution, original offer type and `ACTION_SUCCEEDED` event remain unchanged.
- Require exactly one idempotency row, execution, offer and success event after the first call, with identical counts after the rejected replay.
- Static coverage checks the hash mapping exactly once and before the mismatch guard/persistence, fixture column, low-level function forwarding, both offer-type arguments, identical non-target parameters, read-only persisted-state assertions, and Verify/PostgreSQL 16/PostgreSQL 17.6 workflow wiring.

## Validation state

- QA406 prerequisite is CLOSED: QIMA CI [#43586652941](https://github.com/meridane/QimaTrade-MVP/actions/runs/43586652941) completed SUCCESS; Verify, npm audit, TypeScript, build and **347/347** Playwright tests passed.
- PostgreSQL 16 and PostgreSQL 17.6 full jobs completed SUCCESS; each log contains exactly one explicit `QA406 PASS` marker.
- CodeQL [#43586652920](https://github.com/meridane/QimaTrade-MVP/actions/runs/43586652920) completed SUCCESS.
- QIMA CI [#43592280751](https://github.com/meridane/QimaTrade-MVP/actions/runs/43592280751) completed SUCCESS. Verify passed QA407 static coverage, npm audit at the configured high threshold, TypeScript, Next.js production build and all **347/347** Playwright tests.
- PostgreSQL 16 job `132439348894` and PostgreSQL 17.6 job `132439348526` both completed SUCCESS; each full runtime log contains exactly one explicit `QA407 PASS` marker. The full CREATE_OFFER integration/concurrency, catalog, replication-slot, database-settings, ACL, RLS, runner-privilege and cleanup checks completed.
- CodeQL [#43592280688](https://github.com/meridane/QimaTrade-MVP/actions/runs/43592280688) completed SUCCESS. The combined Vercel status for PR HEAD `9ed22f58151251abb1077c9462c40faaef684179` is SUCCESS.
- The two expected negative cleanup-harness jobs concluded failure by design; their dedicated assertion jobs succeeded. The intentional skipped-job contract was also verified. No unexpected failing job remained.
- QA407 is CLOSED. This is a disposable-fixture regression characterization, not evidence of a Production vulnerability; no application code, migration or Production state was changed.

## Safety and decision boundaries

- Runtime tests use only disposable PostgreSQL CI fixtures and the existing loopback-only integration runner.
- Synthetic offer-type labels characterize hash sensitivity only; they do not define or approve a production offer-type taxonomy or assert that these labels are valid in Production.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of an existing request-hash field, not a finding of a Production vulnerability.
- The demand/tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
