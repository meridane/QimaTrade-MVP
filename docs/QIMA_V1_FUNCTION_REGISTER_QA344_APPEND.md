# QIMA V1 Function Register — QA344 append

Date: 2026-11-11 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa344-create-offer-runner-missing-url-guard-20261111-2247`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and GitHub initially reported it **mergeable**.
- Starting PR HEAD: `c261c3e16c54fd5f3e7de4bf18bde1acd38b72ce`.
- Starting PR metadata: 1,429 commits and 99 changed files; base `main`.
- Starting QIMA CI **#1243** ([run 43020213784](https://github.com/meridane/QimaTrade-MVP/actions/runs/43020213784)) — **SUCCESS, 3/3 jobs**.
- Starting CodeQL **#1194** ([run 43020213923](https://github.com/meridane/QimaTrade-MVP/actions/runs/43020213923)) — **SUCCESS**.
- Starting Vercel status on `c261c3e` — **FAILURE**, description `Deployment rate limited — retry in 24 hours`; this was a Preview quota status, not a GitHub Actions or CodeQL failure.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested at both the beginning and tail line ranges. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but empty content for both ranges. The canonical register was not modified or replaced.
- Reviewed the branch's MKT-1.2 independent-draft idempotency proposal, MKT-1.3 numeric-canonicalization note, and QA343 append before selecting this task.

## QA344 — fail-closed handling for missing database configuration

### Scope

Updated `tests/sql/test-create-offer-integration-runner-guard.sh`.

The existing guard regression already tested seven unsafe URL shapes and three explicitly supported loopback URL forms. It did not separately exercise the runner's required-environment-variable check when `DATABASE_URL` is unset or explicitly empty.

Added two checks:

1. Run `run-create-offer-integration.sh` with `DATABASE_URL` removed from the environment using `env -u DATABASE_URL`.
2. Run it with `DATABASE_URL=""`.

For each case the test asserts:

- the runner exits non-zero;
- the inert `psql` stub is never invoked;
- the diagnostic identifies the missing `DATABASE_URL` configuration.

The existing seven unsafe URL cases and three safe loopback cases remain unchanged. The test still uses a temporary stub executable that records any attempted `psql` invocation and exits with status 99; it never opens a database socket.

Expected summary from the updated test:

`7 unsafe URLs and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted.`

### Code commit and branch synchronization

- Work-branch code commit: `64dba052858296576b54103dc04043a16e073d55` — `test(sql): reject missing CREATE_OFFER database URLs`.
- The work branch was compared with the expected PR base and was **ahead by 1, behind by 0**.
- The target branch was advanced by a non-forced fast-forward using expected prior SHA `c261c3e16c54fd5f3e7de4bf18bde1acd38b72ce`.
- PR #26 now points to code HEAD `64dba052858296576b54103dc04043a16e073d55`; it remains open, draft, unmerged, and mergeable at the latest metadata read.

## Validation status

- **QIMA CI #1244** ([run 43032505601](https://github.com/meridane/QimaTrade-MVP/actions/runs/43032505601)):
  - PostgreSQL 16 integration job — **SUCCESS, 27/27 steps**. The new step “Verify CREATE_OFFER integration runner rejects unsafe database URLs” completed **SUCCESS**. The existing isolated CREATE_OFFER integration/concurrency suite and remaining PostgreSQL 16 regression steps also completed successfully.
  - PostgreSQL 17.6 compatibility job — **SUCCESS, 13/13 steps**. The existing CREATE_OFFER integration/concurrency and wrapper/ACL regression steps completed successfully.
  - Typecheck/audit/build/browser job — npm installation, dependency audit, TypeScript, and Next.js production build completed **SUCCESS**. At the time of this append, the Playwright Chromium installation step was still **IN PROGRESS**; the browser smoke-test step had not yet run. Therefore CI #1244 is not yet recorded as a complete success.
- **CodeQL #1195** ([run 43032505468](https://github.com/meridane/QimaTrade-MVP/actions/runs/43032505468)) — **SUCCESS**.
- Vercel Preview on code HEAD `64dba052` — **SUCCESS**, description `Deployment has completed`; [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/7Nsg5Se7MsKJh5VaKQE2M36esf3P).
- No failed CI steps were visible in the latest job inspection. The remaining browser installation and Playwright checks must be verified before claiming a complete CI pass.

## Safety boundary

- The change only strengthens a shell regression test around the existing fail-closed database URL guard.
- The test uses an inert local `psql` stub for missing/empty and URL cases; no database connection is attempted by those guard checks.
- No database URL, credential, Supabase Production data, migration, function, schema, RLS policy, grant, secret, or persistent configuration was changed or accessed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
