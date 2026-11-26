# QIMA V1 Function Register — QA397

## QA397 — semantically equivalent JSONB object key order replays the original result

**Status:** CLOSED — 14 November 2026  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa397-jsonb-key-order-idempotent-replay-20261114-1023`  
**Base commit:** `92dad6e0cd997dc9e439e5e4a8efdf7aa6bcbf4f`

## Scope

- Exercise the existing `execute_create_offer_v1` contract with one completed tenant-scoped idempotency key.
- The first call supplies JSONB `{"alpha":"one","beta":"two"}`.
- The replay supplies the same JSONB object with source key order reversed: `{"beta":"two","alpha":"one"}`.
- Assert PostgreSQL JSONB semantic equality and identical canonical `jsonb::text` output before calling the function.
- Require the replay to return the exact original JSON result; this case must not raise `IDEMPOTENCY_KEY_REUSE`.
- Require unchanged row counts in `idempotency_keys`, `action_executions`, `offers` and `action_events`.
- Verify the original request hash/result, completed execution input, offer and success event remain unchanged.
- Static coverage pins the existing `'input', p_input` request-hash field and confirms the same effective non-input parameters are used by both calls.
- Integrate the static check in Verify and reuse the disposable PostgreSQL 16 and 17.6 runtime jobs.

## Validation state

- Source review confirms `p_input` is typed as JSONB and is included in the existing request hash. PostgreSQL JSONB normalizes object key order; this scenario intentionally uses string values only and does not test numeric lexical canonicalization.
- No migration or application code is changed.
- The runtime scenario is appended to `tests/sql/create-offer-runtime.sql`; the static contract is `tests/sql/test-create-offer-jsonb-key-order-replay-contract.sh`.
- QIMA CI [#1414](https://github.com/meridane/QimaTrade-MVP/actions/runs/43540736504) completed SUCCESS. Verify, the full PostgreSQL 16 job and the full PostgreSQL 17.6 job all completed SUCCESS; both PostgreSQL logs contain the explicit QA397 PASS marker.
- Verify completed npm audit, TypeScript, Next.js build and 347/347 Playwright tests successfully. CodeQL [#1362](https://github.com/meridane/QimaTrade-MVP/actions/runs/43540736452) completed SUCCESS, and the Vercel Preview for the validated HEAD was Ready.
- The expected-failure prepared-transaction harness jobs and expected-skipped job were accepted by their dedicated assertion jobs; the overall workflow conclusion remained SUCCESS.
- QA397 is CLOSED. The result characterizes JSONB object-key-order equivalence on disposable PostgreSQL fixtures and does not establish a Production vulnerability.

## Safety and decision boundaries

- Tests use disposable PostgreSQL CI fixtures only.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a characterization of PostgreSQL JSONB equivalence, not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.
