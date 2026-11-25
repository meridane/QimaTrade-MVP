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


## QA450 validation progress — 2026-11-25, 10:38 KST

- QIMA CI [#1928](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527358286), on code/test commit `d7c7fc70`, is **IN PROGRESS**.
- Both runtime paths executed all seven QA450 malformed pg_isready calls. The normal path log contains `QA450 pg_isready mock contract passed` followed by `QA353 runtime contract passed`; its dedicated `Assert prepared-transaction always-cleanup runtime contract` job is **SUCCESS**.
- The simulated RESET-failure path also contains the QA450 success line, then `QA354 runtime contract passed`. It preserved the expected exit 52 and did not restart or verify after failure; the dedicated `Assert prepared-transaction cleanup failures remain blocking` job is **SUCCESS**.
- The two runtime job conclusions **FAILURE** are intentional (setup exit 47 and cleanup exit 52). The skipped runtime job is intentionally **SKIPPED**, and its assertion job is **SUCCESS**.
- In Verify, npm audit and TypeScript completed **SUCCESS**, and the Next.js production build completed **SUCCESS**. Chromium installation and Playwright were still pending at the latest job poll; the browser test result is not yet claimed.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs remain **IN PROGRESS** in their CREATE_OFFER integration/concurrency steps. Their prepared-transaction configuration/setup/restore steps are still pending; no PostgreSQL integration completion is inferred from the runtime mocks.
- CodeQL [#1855](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527358151) is **IN PROGRESS** on the code/test commit. CodeQL [#1856](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527434525) is **IN PROGRESS** on the subsequent documentation HEAD.
- QIMA CI [#1929](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527434223) is **PENDING** on documentation HEAD `f07e2627`, with no jobs published at the latest poll.
- QA450 is **partially validated**: all seven negative pg_isready mock cases passed in both runtime paths, and the dedicated runtime assertions passed. Full Verify/Playwright, PostgreSQL 16/17.6, and CodeQL closure remain pending.


## QA451 — reject empty pg_isready target fields

### Changed file

`tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

QA450 already rejected missing/extra arguments, wrong host/port/user/database, and reordered options. QA451 adds four explicit empty-value cases so the exact eight-argument contract is covered when an option is present but its value is empty:

- empty host (`-h ""`);
- empty port (`-p ""`);
- empty user (`-U ""`);
- empty database (`-d ""`).

Each case must return exit 92, emit exactly `Unexpected pg_isready target or argument contract.`, and leave the mock event file empty. The existing seven QA450 negative cases and the normal valid readiness calls are retained. The four new cases execute in both runtime paths, adding eight rejection assertions.

### Publication and validation state

- Working branch: `work/qima-pg-isready-empty-args-qa451-20261125-1045`.
- Code/test commit: [`91364449`](https://github.com/meridane/QimaTrade-MVP/commit/91364449d324bb95cae565eebfe46f74ab27eb96).
- The code/test commit was fast-forwarded to `fix/create-offer-status-contract` from expected prior HEAD `204fe337`; branch comparison reports 2,447 commits ahead of `main`, 0 behind.
- The exact updated file was fetched back from GitHub. Each of the four new labels occurs exactly once, and the updated summary is present.
- No local Bash execution is claimed. QA451 remains pending until GitHub Actions executes the new cases in both runtime paths.
- The prior QA450 workflow, QIMA CI [#1928](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527358286), has Verify **SUCCESS** and both dedicated runtime assertion jobs **SUCCESS**. PostgreSQL 16 and PostgreSQL 17.6 integration jobs remain **IN PROGRESS** at their CREATE_OFFER runner privilege characterization steps.
- The documentation-only HEAD before QA451, `204fe337`, had QIMA CI [#1930](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527587808) **PENDING** with no jobs returned at the last poll, CodeQL [#1857](https://github.com/meridane/QimaTrade-MVP/actions/runs/45527587755) **SUCCESS**, and Vercel **FAILURE** due to `build-rate-limit`. The code/test commit's combined status also reports the Vercel quota limitation; this is not a confirmed compilation failure.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched at the current PR ref but returned an empty content payload with a valid blob SHA. It was not overwritten; this append-only companion remains the auditable record.

### Safety boundary

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.
- QA450/QA451 are CI mock-contract tests; they do not establish a production vulnerability.


## QA451 runtime validation progress — 2026-11-25, 10:46 KST

- QIMA CI [#1931](https://github.com/meridane/QimaTrade-MVP/actions/runs/45528212592), on code/test commit `91364449`, is **IN PROGRESS**.
- The normal-cleanup runtime log contains `QA450/QA451 pg_isready mock contract passed` and `QA353 runtime contract passed`. Its dedicated `Assert prepared-transaction always-cleanup runtime contract` job is **SUCCESS**.
- The simulated RESET-failure runtime log contains the same QA450/QA451 success line and `QA354 runtime contract passed`. It preserved expected cleanup exit 52, did not restart or run postconditions after the failed RESET, and its dedicated `Assert prepared-transaction cleanup failures remain blocking` job is **SUCCESS**.
- The two runtime jobs themselves conclude **FAILURE** intentionally because they inject setup exit 47 and cleanup exit 52. The skipped runtime job is intentionally **SKIPPED**; its skipped-result assertion job is **SUCCESS**.
- QA451's four empty-value cases (host, port, user, database), together with the seven QA450 malformed-argument cases, therefore passed in both runtime paths: 11 direct negative mock cases per path, 22 rejection assertions total.
- At this poll, the Verify job and PostgreSQL 16/17.6 integration jobs are still **IN PROGRESS**. Their complete Playwright, PostgreSQL integration, prepared-transaction setup/restore, and compatibility results are not yet claimed.
- CodeQL [#1858](https://github.com/meridane/QimaTrade-MVP/actions/runs/45528212583) is **IN PROGRESS** on code/test commit `91364449`.
- Vercel combined status on code/test and documentation HEADs remains **FAILURE** with `upgradeToPro=build-rate-limit`; this is an account deployment-quota limitation, not a confirmed compilation failure.
- QA451 is **runtime-validated** in both cleanup paths, but full CI/Verify/PostgreSQL/CodeQL closure remains pending.

### Safety boundary refresh

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.
- QA450/QA451 are CI mock-contract tests; they do not establish a production vulnerability.


## QA451 final closeout — 2026-11-25 (KST)

- QIMA CI [#1933](https://github.com/meridane/QimaTrade-MVP/actions/runs/45528325448), on documentation HEAD `a998f3c76fd395bb9594c3adba848f9c5096a4cd`, completed **SUCCESS**.
- Verify completed **SUCCESS**. Its log confirms **423 Playwright passed (38.7s)**; npm audit, TypeScript, Next.js production build, Chromium installation, workflow cleanup wiring/assertions, and the isolated QIMA security-contract fixture all passed.
- PostgreSQL 16 integration completed **SUCCESS**, including prepared-transaction configuration/setup/restore, disposable-resource postconditions, CREATE_OFFER integration/replay, ACL and RLS regressions.
- PostgreSQL 17.6 compatibility completed **SUCCESS**, including CREATE_OFFER integration/replay, wrapper-owner and EXECUTE ACL regressions.
- QA451's four empty-value `pg_isready` cases plus the seven QA450 malformed-argument cases passed in both runtime paths: 11 direct negative cases per path, 22 rejection assertions total. Both runtime logs contain `QA450/QA451 pg_isready mock contract passed`.
- The normal cleanup path reached `QA353 runtime contract passed`; its dedicated runtime assertion job completed **SUCCESS**. The simulated RESET-failure path preserved exit 52, did not restart or run postconditions after the failed RESET, reached `QA354 runtime contract passed`, and its dedicated blocking assertion job completed **SUCCESS**.
- The two runtime jobs themselves intentionally conclude **FAILURE** because they inject setup exit 47 and cleanup exit 52. The skipped runtime job is intentionally **SKIPPED**; its skipped-result assertion is **SUCCESS**. These are expected negative-contract outcomes, not unexpected suite failures.
- CodeQL [#1860](https://github.com/meridane/QimaTrade-MVP/actions/runs/45528325336) completed **SUCCESS**.
- QA451 is now **fully validated** by Verify/423 Playwright, PostgreSQL 16, PostgreSQL 17.6, both runtime assertion paths, and CodeQL. No local Bash execution is claimed.

## QA452 — fail closed when PostgreSQL never becomes ready before restoration

### Changed file

`tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

QA452 extends the inert `pg_isready` mock with an explicit `MOCK_READY_MODE` (`ready` by default, or `never` for the timeout case). The existing normal and simulated RESET-failure paths explicitly select `ready`, preserving their existing event sequence.

A new isolated invocation runs the actual `restore-prepared-transactions-config.sh` with `MOCK_READY_MODE=never`. It requires:

- exit status `1`;
- the exact fixed diagnostic `The disposable PostgreSQL service did not become ready before configuration restoration.`;
- exactly one Docker discovery event followed by 60 failed readiness probes, each followed by the mocked one-second sleep;
- no `docker exec` / `ALTER SYSTEM RESET`, no Docker restart, and no `psql` postcondition query.

This verifies that a disposable PostgreSQL service which never becomes ready blocks configuration/database mutation before the RESET step. It is a CI runtime-harness contract, not evidence of a production vulnerability.

### Branch and commit

- Working branch: `work/qima-restore-readiness-timeout-qa452-20261125-1114`.
- Code/test commit: [`56af7ecf`](https://github.com/meridane/QimaTrade-MVP/commit/56af7ecfe167f8042c613835d19bc21feca2b2ce).
- The code/test commit was fast-forwarded to `fix/create-offer-status-contract` from expected prior HEAD `a998f3c76fd395bb9594c3adba848f9c5096a4cd`; branch comparison confirmed 2,450 commits ahead of `main`, 0 behind.
- The updated file was fetched back from GitHub. Structural checks confirmed the default-ready and never-ready mock modes, the 60-probe expected event sequence, and the fixed timeout diagnostic.
- No local Bash execution is claimed. QA452 remains **PENDING GitHub Actions execution**: `fetch_commit_workflow_runs` returned no PR-triggered run for code commit `56af7ecf` at this snapshot; its combined status reports Vercel **PENDING**.
- The previous QA451 workflow #1933 validates the parent code/test state and does not validate QA452.

### Safety boundary refresh

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.

## QA452 runtime validation progress — 2026-11-25 (KST)

- QIMA CI [#1934](https://github.com/meridane/QimaTrade-MVP/actions/runs/45531723547), on code/test commit `56af7ecfe`, is **IN PROGRESS**.
- The normal-cleanup runtime job executed the new QA452 isolated timeout case. Its log contains `QA452 readiness-timeout guard passed: 60 failed readiness probes blocked ALTER SYSTEM RESET, restart, and postcondition queries.` The test verified exit 1, the exact timeout diagnostic, one Docker discovery, 60 failed readiness probes and 60 mocked sleeps, with no `docker exec`, restart, or `psql` postcondition event.
- The same normal runtime job also contains the QA449 psql contract, QA450/QA451 pg_isready contract, and `QA353 runtime contract passed`. Its dedicated `Assert prepared-transaction always-cleanup runtime contract` job completed **SUCCESS**.
- The separate simulated RESET-failure path continues to preserve exit 52, does not restart or run postconditions after the failed RESET, and its dedicated blocking assertion job completed **SUCCESS** (`QA354`). QA452's never-ready timeout case is intentionally exercised in the normal runtime path, not after the simulated RESET failure.
- In Verify, npm audit, TypeScript, and the Next.js production build completed **SUCCESS**. Chromium installation is complete and Playwright is currently **IN PROGRESS** at the latest poll; no Playwright total is claimed for QA452 yet.
- PostgreSQL 16 and PostgreSQL 17.6 jobs remain **IN PROGRESS** at CREATE_OFFER integration/concurrency steps. Their prepared-transaction setup/restore and full integration outcomes are not yet claimed for the QA452 commit.
- CodeQL [#1861](https://github.com/meridane/QimaTrade-MVP/actions/runs/45531723396) on code/test commit `56af7ecfe` is **IN PROGRESS**. On the preceding documentation HEAD `764c264d`, CodeQL [#1862](https://github.com/meridane/QimaTrade-MVP/actions/runs/45531780578) is **IN PROGRESS** and QIMA CI [#1935](https://github.com/meridane/QimaTrade-MVP/actions/runs/45531780560) is **PENDING** with no jobs published at the latest poll.
- Vercel Preview for code/test commit `56af7ecfe` is **PENDING**. The preceding documentation HEAD `764c264d` is rate-limited by `upgradeToPro=build-rate-limit`; this is a deployment-quota result, not a confirmed compilation failure.
- QA452 is **runtime-validated in the normal cleanup path**. Full Verify/Playwright, PostgreSQL 16/17.6, and CodeQL closure remain pending. No local Bash execution is claimed.

## QA452 closeout and QA453 transient-readiness regression — 2026-11-25 (KST)

### QA452 final validation

- The PR HEAD before QA453 was `ce842b69e790a2453162905fefc9b688bca3bd35`, OPEN / DRAFT / not merged. The PR targeted `main`; the branch was 2,452 commits ahead and 0 behind.
- QIMA CI [#1936](https://github.com/meridane/QimaTrade-MVP/actions/runs/45531891488) completed **SUCCESS** on that HEAD. Verify completed npm audit, TypeScript, Next.js production build, Chromium, the isolated QIMA security-contract fixture, and **423 Playwright tests passed (37.3s)**.
- PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs both completed **SUCCESS**. The prepared-transaction runtime assertion jobs for the normal cleanup path and blocking cleanup-failure path completed **SUCCESS**. The skipped-result assertion completed **SUCCESS**; its underlying cleanup-result job was intentionally **SKIPPED**.
- The two runtime jobs that inject setup failure (exit 47) and RESET failure (exit 52) intentionally conclude **FAILURE**. Their dedicated assertions passed; these expected negative outcomes are not unexpected CI failures.
- CodeQL [#1863](https://github.com/meridane/QimaTrade-MVP/actions/runs/45531891618) completed **SUCCESS**. QA452 is therefore fully closed for Verify, PostgreSQL 16/17.6, runtime assertions, and CodeQL.

### QA453 — transient PostgreSQL readiness recovery

Changed file:

- `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

The pg_isready mock now has a deterministic `after-three` mode. It records three failed readiness probes and their three mocked one-second sleeps, then returns ready on the fourth probe. The actual `restore-prepared-transactions-config.sh` is executed with inert Docker/PostgreSQL mocks.

The QA453 assertion requires the exact event sequence:

1. One Docker container discovery.
2. Three `pg_isready` failures, each followed by one `sleep 1`.
3. A successful readiness probe before any RESET.
4. The expected `docker exec` RESET and container restart.
5. A successful post-restart readiness probe.
6. The SHOW baseline and both disposable-resource postcondition queries.

It also requires exit 0, five total readiness probes, restored mock baseline `0`, the existing `QA267 passed` confirmation, and no credential text in diagnostics. The test therefore distinguishes transient startup delay from the QA452 never-ready timeout: transient failures must delay cleanup, not prevent a valid cleanup once the service becomes ready.

Code/test commit: [`f49a6c19`](https://github.com/meridane/QimaTrade-MVP/commit/f49a6c191c94cd1b23166f740d1e4b55b2aeac35).

### QA453 validation state at documentation time

- QIMA CI [#1937](https://github.com/meridane/QimaTrade-MVP/actions/runs/45540657320) is **IN PROGRESS** on code/test HEAD `f49a6c191c94cd1b23166f740d1e4b55b2aeac35`.
- The dedicated normal-cleanup runtime assertion and cleanup-failure blocking assertion are **SUCCESS**. Their underlying setup-failure and cleanup-failure jobs intentionally conclude **FAILURE**; the skipped-result job is intentionally **SKIPPED** and its assertion is **SUCCESS**.
- Verify and both PostgreSQL integration jobs (PostgreSQL 16 and PostgreSQL 17.6) are **IN PROGRESS**. No QA453 final CI or Playwright result is claimed yet.
- CodeQL [#1864](https://github.com/meridane/QimaTrade-MVP/actions/runs/45540657230) is **IN PROGRESS**.
- Vercel Preview is **PENDING** at [the deployment status](https://vercel.com/bmk1/qimatrade-mvp/Ek5L4DfP5H96XmgKywzfUbLmg41w). This is not a build failure.
- No local Bash execution is claimed. QA453 is a deterministic mock-based regression of the CI cleanup contract; it is not evidence of a production vulnerability.

### Safety boundary

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.
