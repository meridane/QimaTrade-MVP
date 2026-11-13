# QA392 — zero-price idempotency mismatch preserves original state

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa392-zero-price-mismatched-replay-20261114-0526
Parent HEAD: 04295f3f52ee4c85796a85d68e2ca5cba74ae081
Status: IMPLEMENTED — CI VALIDATION PENDING

## Initial state verified

- PR #26 is OPEN, DRAFT, mergeable and unmerged; head is 04295f3f52ee4c85796a85d68e2ca5cba74ae081.
- QIMA CI [#1404](https://github.com/meridane/QimaTrade-MVP/actions/runs/43494674726) completed SUCCESS. Verify and both full PostgreSQL jobs completed SUCCESS, including QA391 and QA381.
- QIMA CodeQL [#1352](https://github.com/meridane/QimaTrade-MVP/actions/runs/43494674793) and the Vercel status check completed SUCCESS.
- QA391 was confirmed CLOSED before starting QA392.

## Objective

QA391 proves that the existing SQL contract accepts a zero price and exactly replays the same completed request. The complementary boundary is that the same tenant-scoped idempotency key must not be reused with a changed effective price. The existing migration hashes p_price and raises IDEMPOTENCY_KEY_REUSE before creating another action execution. QA392 characterizes that behavior specifically after a zero-price success and verifies that the original persisted state is preserved.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Creates one valid offer with quantity 1 and price 0.
   - Captures the completed idempotency request hash, result and execution ID.
   - Repeats the same tenant/key request with price changed to 1.
   - Requires the exact IDEMPOTENCY_KEY_REUSE error.
   - Requires unchanged row counts in idempotency_keys, action_executions, offers and action_events.
   - Verifies the original request hash, result, completed execution, zero-price offer and ACTION_SUCCEEDED event remain exactly one and unchanged.
2. Added tests/sql/test-create-offer-zero-price-mismatch-replay-contract.sh.
   - Pins the existing price-to-request-hash mapping and mismatch rejection before new action-execution persistence.
   - Requires the exact runtime error, one zero-price initial call, one changed-price replay attempt and four-table persisted-state assertions.
   - Requires exactly one Verify invocation and shared PostgreSQL 16/17.6 runtime runner wiring.
3. Added the QA392 static contract to the Verify job. The shared runtime SQL remains executed by the disposable PostgreSQL 16 and 17.6 jobs.

## Validation

- Source-level review confirms the test uses only the existing disposable authenticated fixture and does not modify the migration or application code.
- QA392 remains PENDING until Verify emits QA392 PASS and both full PostgreSQL 16 and PostgreSQL 17.6 jobs complete SUCCESS with the runtime marker.
- The CI workflow ignores docs/** changes; the code and workflow commit triggers the PR validation.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No new price acceptance, numeric canonicalization or authorization policy was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
- The canonical docs/QIMA_V1_FUNCTION_REGISTER.md could not be safely read through the connected GitHub file/blob endpoints: the connector returned an empty content field for its large blob and rejected raw/blob retrieval as oversized. It was not overwritten. This QA392 append-only record and the QA391 closure appendix are committed; canonical-register synchronization remains a follow-up requiring a chunk-capable retrieval/edit path.
