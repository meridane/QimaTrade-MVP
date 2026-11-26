# QIMA V1 Function Register — QA459 append-only snapshot

Date: 2026-11-25 (KST)  
Repository: `meridane/QimaTrade-MVP`  
Pull request: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`

## Verified baseline and QA458 closeout

- PR #26 was read before this change: **OPEN**, **DRAFT**, not merged, base `main`, head `4977a63e3e9a8d42c13c88e8023211358e785e1b`, 2,477 commits ahead of `main`, 0 behind, 301 changed files; GitHub reported `mergeable=true`.
- The latest PR-head commit `4977a63e` is documentation-only and has parent `399ac343`; the QA458 runtime test is in the preceding code/test history.
- QIMA CI [#1960](https://github.com/meridane/QimaTrade-MVP/actions/runs/45574783033) completed **SUCCESS** on the PR HEAD. Verify completed npm audit, TypeScript, Next.js build, Chromium and **423/423 Playwright** successfully. PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs both completed **SUCCESS**.
- The runtime cleanup assertion jobs completed **SUCCESS**. The two injected-failure harness jobs intentionally concluded **FAILURE** for setup exit 47 and cleanup exit 52; their dedicated assertions succeeded. The skipped-result harness was intentionally **SKIPPED** and its assertion succeeded.
- CodeQL [#1887](https://github.com/meridane/QimaTrade-MVP/actions/runs/45574783129) completed **SUCCESS**.
- The combined status for the current documentation HEAD reports Vercel `failure` with `upgradeToPro=build-rate-limit`. This is a quota limitation, not evidence of a source build failure. The earlier QA458 code/test Preview status is tracked separately.
- QA458 is closed based on these completed checks and the runtime log recorded in the preceding register entry.

## QA459 — Docker restart failure propagation

### Change

File changed: `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`.

The inert Docker mock now supports `MOCK_RESTART_EXIT` for the `restart` command. Its default remains `0`, preserving all existing scenarios.

A new QA459 case invokes the actual `tests/sql/restore-prepared-transactions-config.sh` with `MOCK_RESTART_EXIT=74`. The expected event sequence is exactly:

1. `docker-ps`
2. Initial `pg_isready`
3. `docker-exec-reset`
4. `docker-restart`

The test requires all of the following:

- The restore script preserves exit status **74**.
- The exact diagnostic is `::error::PostgreSQL service restart failed (docker restart exit 74); configuration restoration is not confirmed.`.
- The mock state reflects that RESET ran before the restart attempt; this does not imply that restoration completed.
- No post-restart readiness probe, `psql` postcondition, or `QA267 passed` success marker occurs.
- No database credential is written to the log.

This covers the explicit `docker restart` failure branch in the existing restore script. It does not change the production restore script or PostgreSQL configuration.

### Validation state

- Implementation was committed on a dedicated work branch first.
- **GitHub Actions validation for QA459 is pending** until the code and append-only snapshot are fast-forwarded to the PR branch and the resulting workflow runs.
- No local Bash execution is claimed. The next update must use the actual GitHub Actions runtime log and final job conclusions before QA459 is marked closed.

## Safety and interpretation

- This is a synthetic regression for the disposable CI restore harness. It is not evidence of a production vulnerability.
- No Supabase Production data or migrations, secrets, persistent grants, persistent RLS policies, or production PostgreSQL settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.


### Post-push runtime update — 2026-11-25 (KST)

- After the code and snapshot were fast-forwarded to the PR branch at `f512ac0af4120a2162f71a76fdf238844cfa51a8`, QIMA CI [#1961](https://github.com/meridane/QimaTrade-MVP/actions/runs/45583824548) and CodeQL [#1888](https://github.com/meridane/QimaTrade-MVP/actions/runs/45583824558) started for this exact HEAD.
- The runtime job log explicitly reports: `QA459 restart-failure guard passed: Docker restart exit 74 was preserved and no post-restart readiness or psql postconditions ran.`
- The setup-failure harness job's overall **FAILURE** is expected because the fixture deliberately exits 47 after exercising the always-cleanup path. The dedicated runtime assertion job completed **SUCCESS**; the cleanup-failure fixture's expected exit 52 is also separately asserted.
- At this update, Verify is still **IN PROGRESS** (dependency installation active; audit, TypeScript, build and Playwright not yet concluded), PostgreSQL 16 and PostgreSQL 17.6 jobs are **IN PROGRESS**, and CodeQL #1888 is **IN PROGRESS**. No final Playwright count or PostgreSQL conclusion is claimed.
- Vercel Preview for this HEAD is **PENDING**. No compilation failure is inferred from a pending status.
- QA459 is therefore **runtime-validated**, but the full CI/CodeQL cycle remains open until the main Verify, PostgreSQL 16/17.6 and CodeQL jobs finish successfully.
