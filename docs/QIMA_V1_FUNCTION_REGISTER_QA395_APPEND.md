# QA395 — changed-name replay preserves original state

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa395-name-mismatch-replay-20261114-0907
Parent HEAD: 487531053648501e1dd8b08e40ecf36bc9068c28
Status: IMPLEMENTED — CI VALIDATION PENDING

## Initial state verified

- PR #26 is OPEN, DRAFT, mergeable and unmerged; HEAD is 487531053648501e1dd8b08e40ecf36bc9068c28.
- QIMA CI [#1408](https://github.com/meridane/QimaTrade-MVP/actions/runs/43519543157) completed SUCCESS. Verify, PostgreSQL 16 and PostgreSQL 17.6 full jobs completed SUCCESS, including QA394 and QA381.
- QIMA CodeQL [#1356](https://github.com/meridane/QimaTrade-MVP/actions/runs/43519543244) and the Vercel status check completed SUCCESS.
- QA394 was confirmed CLOSED before starting QA395.

## Objective

The existing CREATE_OFFER request hash includes name = p_name. QA392–QA394 already characterize changed price, quantity and currency replays. QA395 adds the next isolated effective-parameter case: create a valid offer using an original name, then reuse the same tenant-scoped idempotency key with only p_name changed. The existing contract must reject the replay with IDEMPOTENCY_KEY_REUSE before new persistence.

## Changes

1. Appended a disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Creates one valid offer with the original name, quantity 1, price 12 and currency USD.
   - Captures the completed idempotency request hash, result and execution ID.
   - Repeats the same tenant/key request with only the offer name changed; all other effective parameters remain identical.
   - Requires the exact IDEMPOTENCY_KEY_REUSE error.
   - Requires unchanged row counts in idempotency_keys, action_executions, offers and action_events.
   - Verifies the original request hash, result, completed execution, original-name offer and ACTION_SUCCEEDED event remain exactly one and unchanged; explicitly asserts no offer exists under the changed name.
2. Added tests/sql/test-create-offer-name-mismatch-replay-contract.sh.
   - Pins the existing name-to-request-hash mapping and mismatch rejection before new action-execution persistence.
   - Requires exactly one original name and one changed replay name, with identical quantity, price, currency and remaining request parameters.
   - Requires exact runtime error, four-table persisted-state assertions, one Verify invocation and shared PostgreSQL 16/17.6 runtime runner wiring.
3. Added the QA395 static contract to Verify. The shared runtime SQL is executed by the disposable PostgreSQL 16 and 17.6 jobs.
4. Updated the canonical function register and recorded QA394's definitive closure in its append.

## Validation

- Source-level review confirms QA395 uses the existing disposable authenticated provider fixture, existing accepted currency and existing SQL contract. No migration or application code is modified.
- QA395 is pending until the new Verify job and both full PostgreSQL 16 and PostgreSQL 17.6 jobs complete SUCCESS with the explicit QA395 runtime marker.
- The CI workflow ignores docs/** changes; the runtime, static script and workflow change triggers validation.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No new name normalization, acceptance rule, currency behavior, numeric canonicalization or authorization policy was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
- The runtime test uses only disposable PostgreSQL fixtures; synthetic regression evidence is not a finding of a Production vulnerability.


## Source review correction before final CI validation (14 November 2026)

- The first QA395 commit started QIMA CI [#1409](https://github.com/meridane/QimaTrade-MVP/actions/runs/43532381028). A post-commit source review caught two template-copy defects before accepting any validation result: the replay call still carried QA394's EUR value, and the closing dollar-quote tag retained the old currency-mismatch name.
- Corrected the replay currency to USD so p_name is the only changed effective parameter, and corrected the closing dollar-quote delimiter to match the QA395 DO block. Updated the static contract to assert the matching closing delimiter.
- Also corrected stale error/assertion text that referred to changed currency. No migration, application code or business behavior changed.
- CI #1409 is not accepted as QA395 validation; a fresh workflow on the corrected commit is required. No result from the first attempt is used to claim QA395 passed.
