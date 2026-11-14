# QIMA V1 Function Register — QA400

## QA400 — SQL NULL and empty-object p_attributes replay equivalence

**Status:** IMPLEMENTED — CI validation pending  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa400-null-empty-attributes-20261114-1342`  
**Base commit:** `8f2d413a855d77e23eeb27a7ae0ff3b9cc6fcb6e`

## Scope

- Exercise the existing `execute_create_offer_v1` function with one tenant-scoped idempotency key.
- The first request supplies SQL `NULL::jsonb` for `p_attributes`; the replay supplies `'{}'::jsonb`.
- Keep tenant, key, input, name, demand, product, provider actor, quantity, price and currency identical.
- Assert `coalesce(p_attributes, '{}'::jsonb)` produces the same JSONB value and canonical text for both requests.
- Require the replay to return the exact original result rather than `IDEMPOTENCY_KEY_REUSE`.
- Verify the persisted offer attributes are exactly an empty JSONB object.
- Verify the original request hash, idempotency row/result, completed execution/input/result/object, offer and success event remain unchanged.
- Require exactly one row in each of `idempotency_keys`, `action_executions`, `offers` and `action_events` after the first call, with identical counts after replay.
- Static coverage checks the migration hash normalization, disposable fixture persistence normalization, runner fixture loading, exact parameter equality, and Verify/PostgreSQL 16/17.6 wiring.

## Validation state

- The current migration hashes `coalesce(p_attributes, '{}'::jsonb)`; the disposable schema fixture also inserts `coalesce(p_attributes,'{}'::jsonb)` into `offers.attributes`.
- The scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-null-empty-attributes-replay-contract.sh`.
- The test characterizes SQL NULL only. JSONB literal `null` is distinct and is not covered. Numeric canonicalization remains outside scope and subject to MKT-1.3 approval.
- No application code or migration is changed.
- QA400 remains PENDING until the new CI run succeeds and both PostgreSQL runtime logs contain the explicit QA400 marker.

## Safety and decision boundaries

- Tests use disposable PostgreSQL CI fixtures only.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a characterization of explicit existing NULL normalization, not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.
