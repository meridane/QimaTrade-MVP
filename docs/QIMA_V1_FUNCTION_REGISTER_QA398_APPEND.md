# QIMA V1 Function Register — QA398

## QA398 — semantically equivalent JSONB attributes key order replays the original result

**Status:** PENDING full CI validation  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa398-attributes-key-order-20261114-1152`  
**Base commit:** `47a568615e3e2bc0bacabcac8dd413d7bfe91b78`

## Scope

- Exercise the existing `execute_create_offer_v1` contract with one completed tenant-scoped idempotency key.
- The first call supplies `p_attributes = {"alpha":"one","meta":{"x":"1","y":"2"},"beta":"two"}`.
- The replay supplies the same JSONB object with root and nested object key order reversed.
- Assert PostgreSQL JSONB semantic equality and identical canonical `jsonb::text` output before calling the function.
- Require the replay to return the exact original JSON result; this case must not raise `IDEMPOTENCY_KEY_REUSE`.
- Require unchanged counts in `idempotency_keys`, `action_executions`, `offers` and `action_events`.
- Verify the original request hash, idempotency result, completed execution, persisted offer attributes and success event remain unchanged.
- Static coverage pins the existing `'attributes', coalesce(p_attributes, '{}'::jsonb)` request-hash field and confirms all non-attributes effective parameters are identical between calls.
- Integrate the static check in Verify and reuse the disposable PostgreSQL 16 and 17.6 runtime jobs.

## Validation state

- Source review confirms `p_attributes` is typed as JSONB and is normalized with `coalesce(p_attributes, '{}'::jsonb)` in the existing request hash.
- This scenario uses string-valued JSON properties only; it does not test numeric lexical canonicalization or change MKT-1.3.
- No migration or application code is changed.
- The runtime scenario is appended to `tests/sql/create-offer-runtime.sql`; the static contract is `tests/sql/test-create-offer-attributes-key-order-replay-contract.sh`.
- Do not mark QA398 CLOSED until Verify, the full PostgreSQL 16 job and the full PostgreSQL 17.6 job succeed and both runtime logs contain the QA398 marker.

## Safety and decision boundaries

- Tests use disposable PostgreSQL CI fixtures only.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a characterization of PostgreSQL JSONB equivalence, not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.
