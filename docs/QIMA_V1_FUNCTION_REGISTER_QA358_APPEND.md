# QIMA V1 Function Register — QA358 append

Date: 2026-11-12 (UTC)

## Scope

QA358 completes the negative-output matrix for the prepared-transaction cleanup assertion. The change is limited to CI test coverage; it does not change application behavior, SQL, PostgreSQL setup/restore scripts, Supabase configuration, or production data.

## Initial repository state

- Repository: `meridane/QimaTrade-MVP`.
- Pull request: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26).
- Base: `main`, base SHA `0d35c13db81019867fe9929420b0a6916285fbf6`.
- Head branch: `fix/create-offer-status-contract`.
- Initial head SHA: `84c9cd391a62c094053df736e24a4e2ff1d501a7` (`docs(qima): record QA357 skipped and cancelled outcomes`).
- PR state: open, draft, mergeable at initial inspection, not merged.
- Initial PR comparison: 1,503 commits ahead of `main`, 0 behind.
- Reviews: none; inline review threads: none.
- Latest initial PR workflows: QIMA CI #1288 and CodeQL #1238, both completed successfully.
- Initial combined status included Vercel success for the QA357 head.

The recent commit list was read from the PR head branch. The default-branch commit search was not used as a substitute for PR-head history.

## Canonical register retrieval

The canonical file `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested at the PR head. GitHub returned blob SHA `199476ceb047db3b443ec9f6a2120e91d4e6df10`, but the file-content endpoint returned an empty body (0 characters), including when a line range was requested. The raw-file endpoint also rejected the oversized response.

The canonical register was therefore **not replaced or rewritten**. This QA358 append is kept as a separate, reviewable document until the full canonical file can be retrieved safely.

The existing QA357 append was read successfully (blob SHA `dc27c0f9d9e39c27ef24438efca1ce79ab9ff667`).

## Change

File modified:

- `tests/ci/test-prepared-transactions-cleanup-assertions.sh`

The existing valid success, failure, and skipped contracts remain accepted. The eight QA356 negative cases remain intact.

Six additional negative cases close gaps in the skipped/cancelled matrix:

1. A skipped harness unexpectedly exposes `SETUP_OUTCOME`.
2. A skipped harness unexpectedly exposes `CLEANUP_EXIT_CODE`.
3. A skipped harness unexpectedly exposes `CLEANUP_FAILURE_OBSERVED`.
4. A cancelled harness with all cleanup outputs empty is still rejected.
5. The skipped assertion mode rejects a non-skipped harness result.
6. An unknown assertion mode is rejected.

The test now expects 20 negative cases in total: eight QA356 cases plus twelve skipped/cancelled/unknown-state cases. Three valid contracts (success, failure, skipped) are accepted.

The test emits a deterministic `ERROR:` diagnostic for each rejected combination and cleans up its temporary directory through an EXIT trap.

## Commit and CI trigger

- Code commit: `5d2ae401b9a33bded21268be6d80bcb41e54c567`.
- Commit message: `test(ci): complete skipped and cancelled cleanup output matrix`.
- Work branch: `work/qa358-skipped-output-completeness-20261112-1220`.
- The code commit was fast-forwarded to `fix/create-offer-status-contract` using the expected previous head SHA. No force update was used.
- New PR-head CI: [QIMA CI #1289](https://github.com/meridane/QimaTrade-MVP/actions/runs/43147744342).
- New PR-head CodeQL: [CodeQL #1239](https://github.com/meridane/QimaTrade-MVP/actions/runs/43147744350).

At the time this append was written:

- The Verify job had completed the workflow-concurrency check, the prepared-transaction workflow-wiring check, the cleanup assertion matrix (including the new QA358 cases), the parallel-harness isolation check, and the PostgreSQL 17.6 version guard successfully.
- The two dependent runtime assertion jobs for QA353 and QA354 had completed successfully.
- The expected-failure QA353/QA354 harness jobs had their expected individual `failure` conclusions.
- The skipped-result harness had its expected `skipped` conclusion, and its dependent assertion had succeeded.
- PostgreSQL 16 integration, PostgreSQL 17.6 compatibility, the Verify build/browser job, and CodeQL were still in progress. No final conclusion is claimed here for CI #1289 or CodeQL #1239.
- The combined Vercel status for the new code head reported the daily deployment quota failure (`api-deployments-free-per-day`). This is a deployment quota result, not a failed Next.js build result.

The previous code head's successful CI #1288 and CodeQL #1238 are historical baseline evidence only; they do not validate the new QA358 commit.

## Evidence boundary

- The new QA358 cases are deterministic shell-level contract tests. They verify rejection behavior for supplied output combinations; they do not prove that a production cleanup incident or vulnerability exists.
- A real GitHub Actions `skipped` job was already observed and checked by QA357.
- No real job cancellation was triggered. The `cancelled` cases remain synthetic assertion tests; cancelling a full workflow merely to produce that state would interrupt unrelated validation.
- PostgreSQL integration services remain disposable CI services.
- No Supabase production data, migration, schema, SQL function, RLS policy, grant, secret, or persistent configuration was touched.
- No production deployment, PR merge, force-push, or branch-protection change was performed.

## Next step

Recheck CI #1289 and CodeQL #1239. If both complete successfully, record their final job-level results and the exact QA358 test summary. If either fails, inspect the failing job logs and make only a minimal regression fix. Keep the PR open and in draft; do not merge it.
