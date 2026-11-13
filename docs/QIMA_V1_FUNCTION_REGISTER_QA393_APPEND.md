# QA393 — changed-quantity replay preserves original state

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa393-quantity-mismatch-replay-20261114-0643
Parent HEAD: f0cb89b639f278d88cb23a373dda0f5874ca3296
Status: IMPLEMENTED — CI VALIDATION PENDING

## Initial state verified

- PR #26 is OPEN, DRAFT, mergeable and unmerged; HEAD is f0cb89b639f278d88cb23a373dda0f5874ca3296.
- QIMA CI [#1405](https://github.com/meridane/QimaTrade-MVP/actions/runs/43502149788) completed SUCCESS. Verify, PostgreSQL 16 and PostgreSQL 17.6 full jobs completed SUCCESS, including QA392 and QA381.
- QIMA CodeQL [#1353](https://github.com/meridane/QimaTrade-MVP/actions/runs/43502149723) and the Vercel status check completed SUCCESS.
- QA392 was confirmed CLOSED before starting QA393.

## Objective

QA392 characterizes rejection when a completed zero-price request is replayed with a changed price. The complementary effective business parameter is quantity. The existing migration includes p_quantity in the request hash and raises IDEMPOTENCY_KEY_REUSE before creating another action execution. QA393 verifies this after a successful quantity-one offer, with the replay changing only quantity to two, and requires the original persisted state to remain unchanged.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Creates one valid offer with quantity 1 and price 12 USD.
   - Captures the completed idempotency request hash, result and execution ID.
   - Repeats the same tenant/key request with quantity changed to 2 and all other effective parameters unchanged.
   - Requires the exact IDEMPOTENCY_KEY_REUSE error.
   - Requires unchanged row counts in idempotency_keys, action_executions, offers and action_events.
   - Verifies the original request hash, result, completed execution, quantity-one offer and ACTION_SUCCEEDED event remain exactly one and unchanged.
2. Added tests/sql/test-create-offer-quantity-mismatch-replay-contract.sh.
   - Pins the existing quantity-to-request-hash mapping and mismatch rejection before new action-execution persistence.
   - Requires the exact runtime error, one quantity-one initial call, one quantity-two replay attempt and four-table persisted-state assertions.
   - Requires exactly one Verify invocation and shared PostgreSQL 16/17.6 runtime runner wiring.
3. Added the QA393 static contract to Verify. The shared runtime SQL remains executed by the disposable PostgreSQL 16 and 17.6 jobs.
4. Synchronized the canonical QIMA_V1_FUNCTION_REGISTER.md by retrieving the complete existing Git blob and appending the definitive QA392 closure and QA393 pending record without replacing or truncating prior history.

## Validation

- Source-level review confirms the new case uses only the existing disposable authenticated fixture and does not modify the migration or application code.
- QA393 remains PENDING until Verify emits QA393 PASS and both full PostgreSQL 16 and PostgreSQL 17.6 jobs complete SUCCESS with the runtime marker.
- The CI workflow ignores docs/** changes; the code and workflow commit triggers the PR validation.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No new price acceptance, numeric canonicalization or authorization policy was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
- The runtime test uses only disposable PostgreSQL integration fixtures; synthetic regression evidence is not a finding of a Production vulnerability.
