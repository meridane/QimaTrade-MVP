# QIMA V1 Function Register — QA448 append-only snapshot

Date: 2026-11-25 (KST)
Repository: `meridane/QimaTrade-MVP`
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Target branch: `fix/create-offer-status-contract`

## Baseline inspected before QA448

- PR #26 is present in the open-PR search. The target branch was confirmed identical to HEAD `3857d7e6178f7baba85447099ad313e0e499a469` before the change; comparison against `main` showed 2,435 commits ahead and 0 behind.
- No submitted reviews or inline review threads were returned for PR #26 at inspection time.
- QA447 is now fully validated by QIMA CI [#1919](https://github.com/meridane/QimaTrade-MVP/actions/runs/45504557189) and CodeQL [#1846](https://github.com/meridane/QimaTrade-MVP/actions/runs/45504556452), both SUCCESS.
- CI #1919 Verify passed npm audit, TypeScript, Next.js production build, Chromium, 423/423 Playwright tests, and the isolated QIMA security-contract fixture.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs both completed SUCCESS. The prepared-transaction setup/restore steps and cleanup assertions passed.
- The two prepared-transaction runtime jobs intentionally report FAILURE because their scenarios deliberately exit 47 (simulated setup failure) and 52 (simulated RESET failure). Their dedicated assertion jobs completed SUCCESS. The skipped-result job is intentionally SKIPPED and its assertion passed.
- The runtime logs explicitly contain the QA353 and QA354 success messages. This is CI harness validation, not evidence of a production vulnerability.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` has a valid Blob SHA, but the GitHub file reader returns empty content for this large file. No destructive replacement or truncation was attempted; this append-only companion records the new evidence.

## QA448 — exact PostgreSQL readiness probe argument contract

### Changed file

`tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

The QA447 runtime harness already asserted exact arguments for Docker discovery, `docker exec`, and `docker restart`. Its `pg_isready` mock, however, accepted every invocation and recorded only an event marker.

QA448 now requires exactly eight arguments, in this order:

1. `-h`
2. `127.0.0.1`
3. `-p`
4. `5432`
5. `-U`
6. `postgres`
7. `-d`
8. `qima_test`

Any missing, extra, reordered, or changed argument makes the inert mock return exit 92 with a fixed diagnostic. The existing event-sequence assertions still verify that the normal cleanup path probes readiness before RESET and after restart, while the simulated RESET-failure path stops after its pre-reset readiness probe and does not restart or run postcondition queries.

No production PostgreSQL service is contacted by this mock contract. No workflow definition, application code, SQL migration, or database configuration was changed.

### Commit and branch synchronization

- QA448 code/test commit: `eaf7e2d47d7d0c1729fa1260a96920d30808bbb1` (`test(ci): assert exact pg_isready target arguments in cleanup harness`).
- Working branch: `work/qima-cleanup-readiness-probe-qa448-20261125-0850`.
- The working branch was fast-forwarded to `fix/create-offer-status-contract`; post-push comparison confirmed both refs identical.
- No force-push was used.

### Validation status at this snapshot

- The edited file was fetched again from the working branch and its generated `pg_isready` mock block was inspected. The exact eight-argument guard and fixed exit-92 diagnostic are present.
- No local Bash execution is claimed in this run.
- Immediately after the code commit was pushed, the commit-workflow-runs endpoint had not yet returned a new QIMA CI or CodeQL run. The Vercel status for the code commit was PENDING. QA448 therefore remains **PENDING GitHub Actions validation**; QA447's successful CI does not validate the new assertion.
- The next action is to inspect the workflow run triggered by QA448, verify both QA353 and QA354 runtime paths, and confirm the PostgreSQL 16/17.6 jobs plus Verify. Record exact run IDs and conclusions before closing QA448.

## Safety boundary

- No Supabase Production data or migrations were accessed or modified.
- No production secrets, grants, persistent RLS policies, or PostgreSQL production settings were changed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.


## Validation progress — 2026-11-25, 08:50 KST

- QA448's exact `pg_isready` argument guard is exercised by QIMA CI [#1920](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513529795) on code commit `eaf7e2d47d7d0c1729fa1260a96920d30808bbb1`.
- The normal always-cleanup runtime job's actual restore-script step completed **SUCCESS**; its separate assertion job `Assert prepared-transaction always-cleanup runtime contract` completed **SUCCESS**. Because the mock rejects any readiness probe that is not exactly the eight expected arguments, these results confirm the normal runtime path satisfied the QA448 probe contract.
- The expected cleanup-failure runtime job's actual restore-script step returned the deliberately injected exit 52; its separate `Assert prepared-transaction cleanup failures remain blocking` job completed **SUCCESS**. The log retains the QA354 success message, confirming the script did not restart or run postcondition checks after the injected RESET failure. The mock also accepted the readiness probe preceding RESET.
- The two runtime jobs themselves conclude **FAILURE** intentionally: the setup simulation exits 47, and the cleanup-failure scenario exits 52. Their dedicated blocking assertion jobs are **SUCCESS**. The skipped-result job is intentionally **SKIPPED**, and its assertion job is **SUCCESS**.
- In CI #1920, the Verify job's workflow-wiring check, npm audit, TypeScript check, and Next.js production build are **SUCCESS**. Chromium installation, Playwright, and the isolated QIMA security-contract fixture were still pending at the latest poll. PostgreSQL 16 and PostgreSQL 17.6 integration jobs were still **IN PROGRESS**; their prepared-transaction SQL steps had not yet been reached.
- CodeQL [#1847](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513529885) remains **IN PROGRESS**.
- Vercel Preview for code commit `eaf7e2d` is **SUCCESS** ([Preview](https://vercel.com/bmk1/qimatrade-mvp/dnEe8zJh3vGNMFzRjQraGEF4q2vp)).
- The documentation HEAD `3600667838bf035450b9b5f64b663f08bf376311` has QIMA CI [#1921](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513581691) **PENDING**, CodeQL [#1848](https://github.com/meridane/QimaTrade-MVP/actions/runs/45513581687) **IN PROGRESS**, and Vercel Preview **PENDING**. These are documentation-HEAD checks and do not replace the code/test validation on #1920.
- No local Bash test execution is claimed. QA448 is **partially validated** by the successful runtime harness and its assertion jobs; full CI/CodeQL closure remains pending.
