# QA394 — changed-currency replay preserves original state

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa394-currency-mismatch-replay-20261114-0723
Parent HEAD: 2d10319b2db707027dccbc214c312f6e39aeec69
Status: CLOSED — QIMA CI #1408 SUCCESS

## Initial state verified

- PR #26 is OPEN, DRAFT, mergeable and unmerged; HEAD is 2d10319b2db707027dccbc214c312f6e39aeec69.
- QIMA CI [#1406](https://github.com/meridane/QimaTrade-MVP/actions/runs/43513682317) completed SUCCESS. Verify, PostgreSQL 16 and PostgreSQL 17.6 full jobs completed SUCCESS, including QA393 and QA381.
- QIMA CodeQL [#1354](https://github.com/meridane/QimaTrade-MVP/actions/runs/43513682166) and the Vercel status check completed SUCCESS.
- QA393 was confirmed CLOSED before starting QA394.

## Objective

The existing CREATE_OFFER request hash includes currency and the current accepted currency domain includes both USD and EUR. QA392 and QA393 already characterize changed price and changed quantity replays. QA394 adds the complementary changed-currency case: create a valid USD offer, then reuse the same tenant-scoped idempotency key with EUR while keeping all other effective parameters identical. The existing contract must reject the replay with IDEMPOTENCY_KEY_REUSE before any new persistence.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Creates one valid offer with quantity 1, price 12 and currency USD.
   - Captures the completed idempotency request hash, result and execution ID.
   - Repeats the same tenant/key request with currency changed to EUR; quantity, price and all other effective parameters remain identical.
   - Requires the exact IDEMPOTENCY_KEY_REUSE error.
   - Requires unchanged row counts in idempotency_keys, action_executions, offers and action_events.
   - Verifies the original request hash, result, completed execution, USD offer and ACTION_SUCCEEDED event remain exactly one and unchanged.
2. Added tests/sql/test-create-offer-currency-mismatch-replay-contract.sh.
   - Pins the existing currency-to-request-hash mapping, the accepted USD/EUR values and mismatch rejection before new action-execution persistence.
   - Requires one USD initial call, one EUR replay, unchanged quantity/price, exact runtime error and four-table persisted-state assertions.
   - Requires exactly one Verify invocation and shared PostgreSQL 16/17.6 runtime runner wiring.
3. Added the QA394 static contract to Verify. The shared runtime SQL remains executed by the disposable PostgreSQL 16 and 17.6 jobs.
4. Updated the canonical QIMA_V1_FUNCTION_REGISTER.md with the definitive QA393 closure and this QA394 pending record. Updated the QA393 append with the final CI evidence.

## Validation

- Source-level review confirms the new case uses only the existing disposable authenticated fixture and does not modify the migration or application code.
- Initial QIMA CI [#1407](https://github.com/meridane/QimaTrade-MVP/actions/runs/43519394194) failed in Verify at the QA394 static contract because the script incorrectly expected a trailing comma after the final named argument p_currency. The runtime SQL call correctly has no trailing comma; this was a test-harness assertion defect, not an application or migration failure.
- The downstream npm-audit enforcement step also failed because the earlier Verify assertion stopped the job before npm audit ran; no audit result was produced and no vulnerability is inferred from that skipped check.
- Corrected the QA394 static script to match the final p_currency arguments without commas. Runtime SQL and migration are unchanged. PostgreSQL 16 and 17.6 jobs from CI #1407 were still running at this checkpoint; At this initial checkpoint QA394 remained pending; final closure evidence is recorded below.
- The CI workflow ignores docs/** changes; the code and workflow commit triggers the PR validation.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No currency acceptance behavior, numeric canonicalization or authorization policy was introduced; USD and EUR are already in the existing allowlist.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
- The runtime test uses only disposable PostgreSQL fixtures; synthetic regression evidence is not a finding of a Production vulnerability.


## Final validation and closure (14 November 2026)

- QIMA CI [#1408](https://github.com/meridane/QimaTrade-MVP/actions/runs/43519543157) completed **SUCCESS** on HEAD 487531053648501e1dd8b08e40ecf36bc9068c28.
- Verify job 132212510706 completed SUCCESS. Its log contains the explicit QA394 PASS marker; npm audit, TypeScript, Next.js production build and **347/347 Playwright** passed.
- PostgreSQL 16 job 132212511193 and PostgreSQL 17.6 job 132212511050 both completed SUCCESS. Each log contains the QA394 runtime PASS marker and QA381 passed; all subsequent catalog, ACL, RLS, privilege and cleanup steps completed successfully.
- QIMA CodeQL [#1356](https://github.com/meridane/QimaTrade-MVP/actions/runs/43519543244) completed SUCCESS. The Vercel commit status completed SUCCESS.
- QA394 is **CLOSED**. This validates the existing currency-sensitive idempotency contract on disposable CI databases; it is not a Production validation or a finding of a Production vulnerability.
- CI [#1407](https://github.com/meridane/QimaTrade-MVP/actions/runs/43519394194) had a Verify-only static assertion defect (the final named argument was incorrectly expected to have a trailing comma). Its PostgreSQL jobs completed successfully, but the failed Verify stopped the audit/build/browser steps. CI #1408 is the definitive successful rerun after the assertion fix; no vulnerability is inferred from the skipped audit step in #1407.
- No application code, migration, Supabase Production data, secret, persistent PostgreSQL setting, branch protection, PR merge or Production deployment was changed.
