# QIMA V1 Function Register — QA401

## QA401 — SQL NULL versus JSONB literal null attributes replay distinction

**Status:** CLOSED — QIMA CI #1425 passed on PostgreSQL 16 and PostgreSQL 17.6  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa401-sql-null-jsonb-null-attributes-20261114-1445`  
**Base commit:** `88fcf8c5475fd9398b1bc8a358d726c35e244e6f`

## Scope

- Characterize the distinction between SQL `NULL::jsonb` and the JSONB literal `'null'::jsonb` for `p_attributes`.
- The first request supplies SQL NULL. The existing hash normalization maps it to an empty JSONB object through `coalesce(p_attributes, '{}'::jsonb)`.
- The replay supplies JSONB literal null. This is a non-SQL-NULL JSONB value and must remain distinct after the same COALESCE expression.
- Keep tenant, idempotency key, input, offer name, demand, product, provider actor, quantity, price and currency identical.
- Require the replay to fail with the exact `IDEMPOTENCY_KEY_REUSE` error.
- Verify that the first offer remains persisted with empty-object attributes.
- Verify the original request hash, idempotency row/result, completed execution/input/result/object, offer and success event remain unchanged.
- Require exactly one row in each of `idempotency_keys`, `action_executions`, `offers` and `action_events` after the first call, with identical counts after the rejected replay.
- Static coverage checks the existing migration hash normalization, disposable fixture normalization, hash/mismatch/persistence ordering, exact parameter equality, read-only test body, and Verify/PostgreSQL 16/17.6 wiring.

## Validation state

- The existing migration normalizes SQL NULL attributes to `'{}'::jsonb`; JSONB literal null remains JSONB `null` because COALESCE only replaces SQL NULL.
- The disposable fixture persists SQL NULL attributes as an empty object. JSONB literal null is used only on the replay path, which must be rejected before a second offer insert.
- The scenario is appended to `tests/sql/create-offer-runtime.sql`; its static contract is `tests/sql/test-create-offer-sql-null-jsonb-null-attributes-replay-contract.sh`.
- No application code or migration is changed.
- QIMA CI [#1425](https://github.com/meridane/QimaTrade-MVP/actions/runs/43563313321) completed successfully. Verify passed the QA401 static contract, npm audit, TypeScript, Next.js production build and all 347 Playwright tests.
- The complete PostgreSQL 16 and PostgreSQL 17.6 jobs both succeeded; each runtime log contains the explicit `QA401 PASS` marker.
- CodeQL [#1373](https://github.com/meridane/QimaTrade-MVP/actions/runs/43563313314) completed successfully.
- Vercel Preview remains unavailable because the provider returned `build-rate-limit`; no Preview Ready status is claimed.
- QA401 is CLOSED. This confirms the existing SQL NULL versus JSONB literal null distinction for `p_attributes`; it does not establish a Production vulnerability.

## Safety and decision boundaries

- Tests use disposable PostgreSQL CI fixtures only.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a characterization of the existing SQL NULL normalization boundary, not a finding of a Production vulnerability.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain subject to business approval.

## QA400 prerequisite closure

- QIMA CI [#1424](https://github.com/meridane/QimaTrade-MVP/actions/runs/43558563649) completed successfully. Verify passed the QA400 static contract, npm audit, TypeScript, Next.js production build and all 347 Playwright tests.
- The complete PostgreSQL 16 and PostgreSQL 17.6 jobs both succeeded; each runtime log contains the explicit `QA400 PASS` marker.
- CodeQL [#1372](https://github.com/meridane/QimaTrade-MVP/actions/runs/43558563679) completed successfully.
- Vercel Preview was not produced because the provider returned `build-rate-limit`; no Preview Ready status is claimed.

## Canonical register synchronization — resolved

- The complete canonical register blob was retrieved successfully by SHA `65154dbfb4f4a7dabb2cc5e7e685209dc62be92f` (1,831,630 UTF-8 characters).
- The register is updated in the QA402 commit with the definitive QA401 CI #1425 and CodeQL #1373 results, plus the new QA402 pending record.
- The earlier empty contents payload / oversized raw response limitation is resolved by using the Git blob endpoint.
