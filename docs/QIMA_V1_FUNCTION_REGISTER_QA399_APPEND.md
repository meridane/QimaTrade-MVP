# QIMA V1 Function Register — QA399

## QA399 — JSONB array order remains significant for p_attributes idempotency

**Status:** PENDING full CI validation  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa399-jsonb-array-order-significant-20261114-1305`  
**Base commit:** `f95f1cbd837945de28eeccc12d7a30926dd2b221`

## Scope

- Exercise the existing `execute_create_offer_v1` function with one completed tenant-scoped idempotency key.
- The first request supplies `p_attributes = {"items":["alpha","beta"],"meta":{"region":"kr"}}`.
- The replay keeps every other effective parameter identical and changes only the array to `["beta","alpha"]`.
- Assert that the two JSONB values and their canonical `jsonb::text` representations are distinct before the replay.
- Require the replay to raise the exact `IDEMPOTENCY_KEY_REUSE` error.
- Require unchanged row counts in `idempotency_keys`, `action_executions`, `offers` and `action_events`.
- Verify the original request hash, completed idempotency result, execution, offer attributes and success event remain unchanged.
- Static coverage confirms the existing request hash includes `coalesce(p_attributes, '{}'::jsonb)`, the two calls differ only in `p_attributes`, and Verify plus both PostgreSQL 16/17.6 jobs remain wired.

## Validation state

- Source review confirms the existing migration hashes the complete `p_attributes` JSONB value; PostgreSQL JSONB preserves array element order while canonicalizing object key order.
- This scenario uses text-only array elements and does not test numeric lexical canonicalization or change MKT-1.3.
- No migration or application code is changed.
- Runtime SQL is appended to `tests/sql/create-offer-runtime.sql`; static contract is `tests/sql/test-create-offer-attributes-array-order-replay-contract.sh`.
- QIMA CI [#1416](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555179600) was triggered on code commit `9795c3328b113fd4a9aff7c0a9c357d82edfe4db`. The Verify step `Verify CREATE_OFFER JSONB array-order change rejects replay and preserves original state` completed SUCCESS. At the latest check, the PostgreSQL 17.6 CREATE_OFFER runtime step was in progress; the PostgreSQL 16 runtime step had not started; the Verify job had reached the production build and browser tests remained pending.
- CodeQL [#1364](https://github.com/meridane/QimaTrade-MVP/actions/runs/43555179638) was IN_PROGRESS and the Vercel status for this HEAD was PENDING at the same checkpoint. These are intermediate states, not final validation.
- Keep QA399 PENDING until Verify, both complete PostgreSQL jobs and the QA399 runtime marker in both logs succeed.

## Safety and decision boundaries

- Tests use disposable PostgreSQL CI fixtures only.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This characterizes JSONB array ordering; it is not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.
