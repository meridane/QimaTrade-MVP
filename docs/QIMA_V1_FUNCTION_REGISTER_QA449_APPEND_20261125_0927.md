# QIMA V1 Function Register — QA449 append-only snapshot

Date: 2026-11-25 (KST)
Repository: `meridane/QimaTrade-MVP`
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Target branch: `fix/create-offer-status-contract`

## Baseline inspected before QA449

- PR #26 was **OPEN / DRAFT / not merged**, targeting `main`, with HEAD `26493645c6b96645873825fd42108184a8c37468`, 2,439 commits ahead and 0 behind, and 300 changed files.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched at the PR head. GitHub returned a valid blob SHA (`5a09f32c2a27500e4b80f47ac9ac9091d96dcc39`) but empty UTF-8 content. No replacement of the large canonical file was attempted; this companion is append-only.
- QA448 is now fully validated by QIMA CI [#1920](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513529795): Verify passed npm audit, TypeScript, Next.js build, Chromium, 423/423 Playwright tests and the QIMA security-contract fixture. PostgreSQL 16 and PostgreSQL 17.6 integration jobs both completed SUCCESS; setup, restore and disposable-resource checks passed.
- The QA448 runtime harness passed in both normal cleanup and simulated RESET-failure paths. Dedicated assertion jobs passed. The runtime jobs themselves intentionally conclude FAILURE because the scenarios inject setup exit 47 and cleanup exit 52; the skipped-result job is intentionally SKIPPED and its assertion passed.
- CodeQL [#1847](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513529885) succeeded on the QA448 code commit. The subsequent documentation HEAD `26493645` has QIMA CI [#1923](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513871413) SUCCESS and CodeQL [#1850](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513871428) SUCCESS.
- Vercel status for documentation HEAD `26493645` is rate-limited (`upgradeToPro=build-rate-limit`). This is a deployment quota result, not a build or application compilation failure.

## QA449 — exact psql target and argument contract in the cleanup runtime harness

### Changed file

`tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

The runtime harness already checked the exact Docker command arguments and the eight-argument `pg_isready` target. Its `psql` mock previously classified calls using substring matches on `$*`, which could accept extra, missing, reordered, or redirected arguments if the expected query text remained present.

QA449 replaces that permissive matching with an exact six-argument contract:

1. Disposable URL: `postgresql://postgres:postgres@localhost:5432/qima_test`
2. `-X`
3. `-v`
4. `ON_ERROR_STOP=1`
5. `-Atqc`
6. Exactly one allowlisted query:
   - `SHOW max_prepared_transactions`
   - QA266 prepared-transaction count query
   - disposable migration-database count query

All other targets, argument layouts, or queries return exit 93 with the fixed diagnostic `Unexpected psql target or argument contract.` before recording an event.

Five direct negative self-checks were added to the harness:
- missing argument;
- extra argument;
- wrong database URL;
- reordered options;
- unknown query.

Each self-check requires exit 93, the exact fixed diagnostic, and an empty event file. The normal runtime execution that follows exercises the three valid query forms and existing cleanup assertions.

This is a CI mock-contract improvement. It does not establish a production vulnerability and does not contact a production database.

### Branch and commit

- Working branch: `work/qima-cleanup-psql-argument-contract-qa449-20261125-0927`.
- Code/test commit: [`09118e98`](https://github.com/meridane/QimaTrade-MVP/commit/09118e983155822efb320aa4b0e100312338bd54).
- The code/test commit was fast-forwarded to `fix/create-offer-status-contract` with expected previous HEAD `26493645`; post-push comparison confirmed the working branch and PR branch identical (0 ahead / 0 behind).
- No force-push was used.

### Validation status at this snapshot

- The edited file was fetched back from GitHub and structurally inspected: exact six-argument guard present; five negative self-check calls present; the old `case "$*"` substring matcher absent.
- No local Bash execution is claimed.
- QIMA CI [#1924](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518420085) is **QUEUED** on code commit `09118e98`; CodeQL [#1851](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518420023) is **IN PROGRESS**. Vercel Preview for the code commit is **PENDING** at the last status check.
- QA449 remains **PENDING GitHub Actions validation**. QA448's successful CI does not validate the new psql mock contract.
- Next: inspect the Verify runtime harness and both PostgreSQL 16/17.6 jobs for QA449; record the exact run/job conclusions before closing QA449.

## Safety boundary

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.


## Validation progress — 2026-11-25, 09:27 KST

- QIMA CI [#1924](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518420085) started on code/test commit `09118e983155822efb320aa4b0e100312338bd54`.
- The QA449 psql mock's five direct negative self-checks ran successfully in both runtime paths. Both job logs contain: `QA449 psql mock contract passed: missing, extra, wrong-target, reordered-option, and unknown-query invocations were rejected before recording an event.`
- In the normal always-cleanup runtime job, the actual restore-script step completed SUCCESS and the dedicated `Assert prepared-transaction always-cleanup runtime contract` job completed SUCCESS; the script reached its normal baseline/resource postconditions.
- In the simulated cleanup-failure runtime job, the actual restore-script step returned the deliberately injected exit 52; the dedicated `Assert prepared-transaction cleanup failures remain blocking` job completed SUCCESS. The script did not restart or run postcondition queries after the failed RESET. These overall runtime-job FAILURE conclusions are expected test outcomes, not unexpected suite failures.
- The skipped-result assertion job completed SUCCESS; the corresponding intentionally skipped runtime job remains SKIPPED.
- Verify has passed the cleanup workflow wiring and cleanup assertion checks, npm audit, TypeScript, and the Next.js production build. Playwright and the isolated security-contract fixture were still pending at the latest poll.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs are still IN PROGRESS. The prepared-transaction configuration, setup-intent, and restoration steps remain pending in both jobs; no PostgreSQL integration outcome is inferred from the mock runtime harness.
- CodeQL [#1851](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518420023) is IN PROGRESS; CodeQL initialization and autobuild succeeded, analysis is still running.
- Vercel Preview for code/test commit `09118e98` is SUCCESS. The subsequent documentation HEAD is rate-limited by the Vercel deployment quota; this is not a compilation result.
- QA449 is **partially validated**: its exact psql mock contract and both runtime assertions passed, while the complete CI run and CodeQL analysis remain open. No local Bash execution is claimed.


## Verification refresh — 2026-11-25, 09:27 KST

- QIMA CI [#1924](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518420085), on code/test commit `09118e98`, Verify completed **SUCCESS**. Its log confirms **423 Playwright passed (37.2s)**; npm audit, TypeScript, Next.js production build, Chromium installation, workflow cleanup wiring/assertions, and the isolated QIMA security-contract fixture all completed successfully.
- The two QA449 direct negative self-check batches ran in both runtime jobs. Both logs contain the QA449 success message. The normal cleanup path's actual restore-script step and its dedicated assertion job completed SUCCESS; the simulated cleanup-failure path returned the expected exit 52 and its dedicated blocking assertion job completed SUCCESS.
- The two runtime job conclusions FAILURE are intentional: the scenarios inject setup failure 47 and RESET failure 52. The corresponding assertion jobs pass. The skipped-result job is intentionally SKIPPED and its assertion passes.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs remain **IN PROGRESS** at the full CREATE_OFFER runner write-privilege characterization step. Their prepared-transaction setup, blocker, and restore steps are still pending; no PostgreSQL 16/17.6 completion is claimed.
- CodeQL [#1851](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518420023) completed **SUCCESS**.
- Vercel Preview for code/test commit `09118e98` is **SUCCESS**. The latest documentation HEAD is rate-limited by the Vercel deployment quota; this is not a compilation result.
- QA449 is **partially validated**: all five malformed psql argument cases were rejected in both runtime scenarios, and Verify/Playwright/CodeQL passed. Full CI closure remains pending on PostgreSQL 16 and PostgreSQL 17.6. No local Bash execution is claimed.


## QA449 final closeout — 2026-11-25, 10:38 KST

- QIMA CI [#1927](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518815449), associated with documentation HEAD `f961b527`, completed **SUCCESS**.
- Verify job `Typecheck, audit, build and browser tests` completed **SUCCESS**. Its log confirms **423 Playwright passed (37.7s)**; dependency audit, TypeScript, Next.js production build, Chromium installation, workflow cleanup wiring/assertions, and the isolated QIMA security-contract fixture all completed successfully.
- PostgreSQL 16 integration job completed **SUCCESS**. The prepared-transaction configuration guard, setup restoration-intent check, setup-failure cleanup, disposable prepared-transaction blocker, restore/postcondition checks, and all CREATE_OFFER integration, replay, ACL, and RLS steps completed successfully.
- PostgreSQL 17.6 compatibility job completed **SUCCESS**, including the version assertion, CREATE_OFFER integration/replay coverage, wrapper-owner and EXECUTE ACL regressions.
- QA449's five malformed psql argument self-checks ran in both runtime scenarios. Both logs contain `QA449 psql mock contract passed`. The normal path reached the baseline/resource postconditions and its QA353 assertion job passed. The simulated RESET-failure path preserved exit 52, did not restart or run postconditions, and its QA354 assertion job passed.
- The two runtime jobs intentionally conclude **FAILURE** because they inject setup exit 47 and cleanup exit 52. Their dedicated assertion jobs are **SUCCESS**. The skipped runtime job is intentionally **SKIPPED** and its skipped-result assertion is **SUCCESS**. These are expected negative-contract outcomes, not unexpected suite failures.
- CodeQL [#1854](https://github.com/meridane/QimaTrade-MVP/actions/runs/45518815502) completed **SUCCESS**.
- The combined status for documentation HEAD `f961b527` reports Vercel **FAILURE** with `upgradeToPro=build-rate-limit`. This is an account deployment-quota limitation, not a confirmed build or compilation failure.
- QA449 is now **fully validated** by Verify, PostgreSQL 16, PostgreSQL 17.6, the two runtime assertion paths, and CodeQL. No local Bash execution is claimed.

## QA450 — strict pg_isready mock negative cases

### Changed file

`tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

The pg_isready mock already enforced an exact eight-argument target contract (host `127.0.0.1`, port `5432`, user `postgres`, database `qima_test`) and returned exit 92 with a fixed diagnostic for mismatches. Before QA450, the runtime harness exercised only the valid call made by the restore script; it did not directly prove that the mock rejected malformed invocations.

QA450 adds seven direct negative self-checks:
- missing argument;
- extra argument;
- wrong host;
- wrong port;
- wrong user;
- wrong database;
- reordered options.

Each case requires exit 92, the exact fixed diagnostic `Unexpected pg_isready target or argument contract.`, and an empty event file, proving rejection occurs before the mock records a readiness event. The checks run in both the normal-cleanup and simulated-cleanup-failure runtime paths.

### Branch and commit

- Working branch: `work/qima-pg-isready-mock-contract-qa450-20261125-1038`.
- Code/test commit: [`d7c7fc70`](https://github.com/meridane/QimaTrade-MVP/commit/d7c7fc70be5fcfe039a2c9ba688650d346ee2866).
- The code/test commit was fast-forwarded to `fix/create-offer-status-contract` from expected prior HEAD `f961b527`; branch comparison after publication reported 2,444 commits ahead of `main`, 0 behind.
- The exact inserted diff was fetched back from GitHub and inspected. It adds seven direct negative calls and one success summary; no runtime production script or workflow was changed.
- No local Bash execution is claimed.
- At this documentation snapshot, `fetch_commit_workflow_runs` for code/test commit `d7c7fc70` returned no PR-triggered runs yet. Its combined status showed Vercel **PENDING**. QA450 remains **PENDING GitHub Actions validation** until a run for this commit or its descendant executes the new self-checks.
- Next: inspect Verify logs for the QA450 success line in both runtime paths, then inspect PostgreSQL 16/17.6 and CodeQL on the final documentation HEAD before closing QA450.

## Safety boundary refresh

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.
- QA449/QA450 are CI harness contract tests; synthetic mocks do not establish a production vulnerability.
