# QIMA V1 Function Register — QA462 append
Date: 2026-11-25 (KST)

## Scope

This append-only entry records a CI regression for the disposable PostgreSQL prepared-transaction restoration path. It does not change application behavior, Supabase Production data, migrations, persistent grants, RLS policies, or production PostgreSQL configuration.

## Starting state inspected

- Pull request: [#26 — fix: align CREATE_OFFER execution statuses](https://github.com/meridane/QimaTrade-MVP/pull/26).
- Target branch: `fix/create-offer-status-contract`.
- Verified starting HEAD: `4e189f13929ec2ddd92657c2838835c1efbc5428`.
- The branch compared identical to that SHA before the change.
- Previous code/test validation: QIMA CI [#1968](https://github.com/meridane/QimaTrade-MVP/actions/runs/45602960423) **SUCCESS**; all nine jobs completed. The two expected-failure fixture jobs returned their intentionally injected failures, their assertion jobs succeeded, and the skipped fixture was correctly skipped.
- Previous CodeQL [#1895](https://github.com/meridane/QimaTrade-MVP/actions/runs/45602960452) **SUCCESS**.
- The combined status for the starting HEAD showed Vercel `failure` with `upgradeToPro=build-rate-limit`; this is a quota status, not evidence of a compilation failure.
- The canonical register blob is `cb3400116d33fb81650982600064454783aba218`. The GitHub file reader returned an empty content body for this large file (UTF-8 and base64 requests), so this entry is a separate append-only record; the canonical file was not replaced or rewritten.

## QA462 — Docker discovery failure

Changed file: `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`.

The inert Docker mock now supports `MOCK_DOCKER_PS_EXIT`, defaulting to `0` so all existing scenarios retain their behavior. The new scenario injects exit code `78` from the Docker container-discovery command.

Expected and asserted contract:

1. The exact Docker discovery invocation is recorded once.
2. The restore script preserves exit code `78`.
3. The exact diagnostic states that no readiness, database, or configuration operation was attempted.
4. The partial setup state remains at `10`, proving that RESET was not invoked by this scenario.
5. No `pg_isready`, `docker exec`, `docker restart`, or `psql` event occurs.
6. No success marker is emitted and no credential-bearing connection string appears in the log.

The test invokes the real `tests/sql/restore-prepared-transactions-config.sh` script with inert command mocks. It does not connect to a database.

## Publication

- Work branch: `work/qima-docker-discovery-failure-qa462-20261125-2145`.
- Code/test commit: [`4e45b7df692b9cac51fbb5dd9fc35acde9830e6b`](https://github.com/meridane/QimaTrade-MVP/commit/4e45b7df692b9cac51fbb5dd9fc35acde9830e6b).
- The code diff adds the failure injection to the Docker mock and one QA462 regression case.
- The target PR branch was advanced by a non-forced fast-forward with expected previous SHA `4e189f13929ec2ddd92657c2838835c1efbc5428`.
- The work branch and target branch compared identical after synchronization.

## Validation status at this snapshot

- The prior code/test commit `4e189f13` has full QIMA CI #1968 and CodeQL #1895 success as recorded above.
- The new QA462 commit was published to the PR branch. Its new GitHub Actions workflow was not yet visible in the first post-push poll; no QA462 runtime or full-CI success is claimed here.
- Vercel Preview for the new code commit was **PENDING** at the first post-push poll.
- No local shell test was run in this execution. Validation must be taken from the new GitHub Actions run once it appears.

## Safety and interpretation

- No Supabase Production data or migrations were touched.
- No secrets, persistent grants, RLS policies, production database settings, branch protections, or deployment configuration were changed.
- No Production deployment, merge, or force-push was performed.
- This is a synthetic CI regression for error propagation and operation ordering. It is not evidence of a production vulnerability.
