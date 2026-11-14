# QIMA V1 Function Register — QA350 append

Date: 2026-11-12 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa350-prepared-transaction-failure-restoration-20261112-0422`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, **MERGEABLE**, and unmerged.
- Starting PR HEAD: `e66b6fdb6352a833669f05b8d1af0a4ec3e9024d`.
- Compare `main...fix/create-offer-status-contract`: **1,452 commits ahead, 0 behind**; the PR reported **105 changed files**.
- Starting QIMA CI **#1259** ([run 43083166861](https://github.com/meridane/QimaTrade-MVP/actions/runs/43083166861)) — **SUCCESS, 3/3 jobs**. Its prepared-transaction restoration guard, setup-intent test, actual disposable-service setup, prepared-transaction cleanup regression, and always-run restoration step all completed successfully.
- Starting CodeQL **#1209** ([run 43083167168](https://github.com/meridane/QimaTrade-MVP/actions/runs/43083167168)) — **SUCCESS**.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` with empty content; the raw-content request also failed. The canonical file was not replaced. The QA349 append was read and retained as the preceding record.

## QA350 — prove cleanup after partial prepared-transaction setup failures

### Gap and scope

The existing setup regression proved that the setup script persists `restore_required=true` before its first mutation and retains that marker after SET, restart, post-restart SHOW, and readiness failures. The existing restoration regression separately exercised reset/restart/verification behavior. QA350 adds the missing combined failure-path check: after each setup failure, invoke the same restoration script wired to the workflow's `if: always()` cleanup and prove that the simulated partial change is removed.

Added `tests/sql/test-prepared-transactions-failure-restoration.sh` and one PostgreSQL 16 CI step immediately after the existing setup-intent regression and before the real disposable PostgreSQL service is modified.

The new test uses inert local mocks for docker, psql, pg_isready, and sleep. It opens no database socket and invokes no real Docker command. Three failure boundaries are covered:

1. **SET reports exit 47 after a simulated partial change.** The mock records max_prepared_transactions=10, then returns 47. The setup script must retain the exact baseline/restoration marker. The restoration script must RESET, restart, and verify baseline 0.
2. **Setup restart reports exit 48 after SET.** The marker and simulated value 10 remain; the restoration path must still RESET, restart, and verify baseline 0.
3. **Post-restart SHOW reports exit 49.** Setup must fail without clearing the marker; restoration must still return the simulated configuration to baseline 0.

For each case, the test checks the exact command order, the exact marker, the final configuration state, the restoration success diagnostic, zero remaining prepared transactions, zero leftover disposable migration databases, and absence of connection credentials from diagnostics.

The pre-existing setup test already asserts that the workflow's restoration step has `if: always()` and receives the setup step's restoration marker and baseline outputs. QA350 tests the actual setup and restore scripts against that contract.

### Initial CI failure and correction

- First QA350 code commit: `e9ba5a7c7147600df4fe6e9c7b571827b268dd6f`.
- QIMA CI **#1260** ([run 43087031192](https://github.com/meridane/QimaTrade-MVP/actions/runs/43087031192)) — **FAILURE** in the new QA350 test only. The test harness had literal backslashes before shell parameter expansions because the source was emitted through a raw template string. Consequently, BASH_SOURCE did not expand and the test resolved the setup script under `/home/runner/work/tests/sql`, where it did not exist; the harness exited 127 before reaching its intended assertions.
- In the same #1260 run, the browser/typecheck/build job and PostgreSQL 17.6 compatibility job succeeded. CodeQL **#1210** ([run 43087031190](https://github.com/meridane/QimaTrade-MVP/actions/runs/43087031190)) — **SUCCESS**.
- Corrected all **11** escaped shell parameter expansions in commit `c6c1f86d062fef906a2ad4bf8a7e0cf5b15a81d6`. The corrected file now expands BASH_SOURCE and mock environment variables normally. No application code, SQL migration, or production configuration was changed by this correction.

### Final validation on the corrected code commit

- QIMA CI **#1261** ([run 43087362220](https://github.com/meridane/QimaTrade-MVP/actions/runs/43087362220)) — **SUCCESS, 3/3 jobs**.
  - PostgreSQL 16 integration job: **29/29 steps**, no failed or skipped steps.
  - PostgreSQL 17.6 compatibility job: **14/14 steps**, no failed or skipped steps; server version guard and CREATE_OFFER integration/concurrency, wrapper-owner, and ACL regressions passed.
  - Browser/typecheck/audit/build job: **19/19 steps**, no failed or skipped steps. npm audit, TypeScript, Next.js build, Chromium installation, and browser smoke tests passed; Playwright reported **347 passed (12.4s)**.
- The PostgreSQL 16 log explicitly reports all three QA350 cases:
  - `QA350 set-failure passed` — setup exit 47 retained the marker; cleanup reset and verified baseline 0.
  - `QA350 restart-failure passed` — setup exit 48 retained the marker; cleanup reset and verified baseline 0.
  - `QA350 verify-failure passed` — setup exit 49 retained the marker; cleanup reset and verified baseline 0.
  - Final QA350 output confirms zero remaining prepared transactions, zero leftover migration databases, and no credential disclosure.
- CodeQL **#1211** ([run 43087362207](https://github.com/meridane/QimaTrade-MVP/actions/runs/43087362207)) — **SUCCESS**.
- Vercel combined status for the corrected code HEAD was **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`. No Preview success is claimed for QA350.
- The final documentation-only commit does not trigger another CI run because the workflow has `paths-ignore: docs/**`; CI #1261 and CodeQL #1211 validate the code/workflow commit `c6c1f86`.

### Commits and files

- `e9ba5a7c7147600df4fe6e9c7b571827b268dd6f` — add the QA350 failure-restoration harness and its CI step.
- `c6c1f86d062fef906a2ad4bf8a7e0cf5b15a81d6` — correct shell parameter expansion in the harness.
- This append records the final QA350 validation.

Unique files changed for QA350:

- `.github/workflows/ci.yml`
- `tests/sql/test-prepared-transactions-failure-restoration.sh`
- `docs/QIMA_V1_FUNCTION_REGISTER_QA350_APPEND.md`

The work branch was fast-forwarded to the PR branch after checking the expected prior HEAD. No force update was used.

## Interpretation boundary

The three failure modes are synthetic command failures exercised with inert local mocks. They prove the tested script contract and command ordering; they do not prove a production failure or vulnerability occurred. The real PostgreSQL CI job separately passed the ordinary setup, prepared-transaction cleanup regression, and always-run restoration path on the disposable PostgreSQL 16 service.

## Safety boundary

- No Supabase Production data, migration, function, schema, RLS policy, grant, secret, or persistent configuration was read for mutation or changed.
- The QA350 failure-path test uses only temporary files and inert local command mocks.
- The existing real PostgreSQL setup/restore steps remain restricted to the disposable CI service and completed successfully.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
