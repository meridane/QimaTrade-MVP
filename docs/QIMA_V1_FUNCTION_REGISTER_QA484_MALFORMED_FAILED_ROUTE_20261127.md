# QimaTrade — QA484 malformed FAILED route-result characterization

Date: 2026-11-27 (Asia/Seoul)

## Scope

- Repository: `meridane/QimaTrade-MVP`
- PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
- Base PR HEAD before this change: `3b633385fef892a850926c582d5634d1ddc6aa3f`
- Work branch: `work/qima-malformed-failed-route-result-qa484-20261127-0145`
- Test commit: [`8108adac`](https://github.com/meridane/QimaTrade-MVP/commit/8108adac4263536edb5d5d420371b29708fce69e)
- File changed: `tests/e2e/create-offer-route-contract.spec.ts`

## Change

Added one focused Playwright regression test for malformed RPC results whose claimed terminal status is `failed`. It covers:

- missing `executionId`;
- blank `executionId`;
- non-string `objectId`;
- explicit `result: null`.

For every malformed case, the route is expected to return HTTP 500 with only the generic public body `{ error: "ACTION_FAILED" }`. The test also verifies that `ACTION_RESULT_INVALID` and the private execution identifier do not leak, and that the expected authentication/profile/membership/definition/RPC request sequence occurs exactly once.

This complements the existing malformed-`succeeded` route test. The engine already validates both statuses through the same normalizer; QA484 locks down the route's generic-error boundary for the `failed` path. No application code or SQL was changed.

## Validation snapshot after the test commit

- QIMA CI run [#2033](https://github.com/meridane/QimaTrade-MVP/actions/runs/45862055414): **IN PROGRESS** at the recorded observation. The Verify job had completed the repository's static SQL/CI contract checks and was installing dependencies; PostgreSQL 16 and 17.6 jobs were initializing/running. No Playwright result is claimed yet.
- CodeQL run [#2033](https://github.com/meridane/QimaTrade-MVP/actions/runs/45862055471): **IN PROGRESS**.
- Vercel combined status for the test commit: **PENDING** at the recorded observation.
- Expected setup/cleanup failure-injection harness jobs are intentionally expected to conclude `failure`; their separate assertion jobs must pass. The skipped-result harness is expected to be skipped.
- No local test command was run in this automation turn.

The CI workflow declares `paths-ignore: docs/**`, so this companion documentation does not itself require a new QIMA CI run. The code-test commit is the commit under validation.

## Evidence boundary and safety

This is a synthetic route-contract regression. It does not establish a production vulnerability or prove that malformed FAILED rows/results occur in Supabase Production.

The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` currently has blob SHA `ac4b56aa31c5bab04784954ead01a134810752b5`, but the GitHub file reader returns an empty body (including ranged reads). Its full content was not available for a safe replacement. This append-only companion records QA484 without risking loss of the canonical register's history.

No Supabase Production data, schema, migration, grants, RLS policies, secrets, or persistent configuration were changed. No Production deployment, merge, force-push, or branch-protection change was performed.


## Updated validation snapshot — 2026-11-27 (Asia/Seoul)

- QIMA CI run [#2033](https://github.com/meridane/QimaTrade-MVP/actions/runs/45862055414), on test commit `8108adac4263536edb5d5d420371b29708fce69e`: Verify job **SUCCESS**.
  - Playwright: **435 passed (35.9s)**. The log explicitly records `CREATE_OFFER route masks malformed FAILED RPC results as generic internal failures` as passed.
  - Dependency audit (blocking threshold: high): **SUCCESS**. No claim is made here about lower-severity counts because the current job summary does not expose a complete count in the inspected excerpt.
  - TypeScript, Next.js production build, Chromium installation/browser smoke tests, and isolated QIMA security-contract fixture: **SUCCESS**.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs remain **IN PROGRESS** at the last observation, each on the full runner write-privilege characterization step. No PostgreSQL result is claimed for QA484 because the new change is an HTTP route test, not a SQL change.
- QIMA CodeQL run [#2033](https://github.com/meridane/QimaTrade-MVP/actions/runs/45862055471): **SUCCESS**.
- Vercel combined status on the test commit: **SUCCESS** — [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/HHGFAViX5A34SwBTDAh8R27ccigN).
- Expected failure-injection harness jobs concluded `failure` by design; their separate assertion jobs concluded **SUCCESS**. The skipped-result harness concluded **SKIPPED** as expected.

The overall QIMA CI run remains **IN PROGRESS** until both PostgreSQL jobs finish. This snapshot does not infer an overall CI conclusion from the successful Verify and CodeQL jobs.
