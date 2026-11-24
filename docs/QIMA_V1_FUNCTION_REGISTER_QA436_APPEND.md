# QIMA V1 Function Register — QA436

## Previous cycle closure — QA435

**Reviewed PR #26 HEAD:** `52c3343fdb1dda20dc9d541ecbdb927a2ff634d8`  
**Base comparison:** `main...fix/create-offer-status-contract` reported 2,376 commits ahead and 0 behind.

- QIMA CI [#1894](https://github.com/meridane/QimaTrade-MVP/actions/runs/45382216966): **SUCCESS**.
- Verify job: npm audit, TypeScript, Next.js production build, Chromium and **423/423 Playwright passed (37.4 s)**.
- PostgreSQL 16 integration job: **SUCCESS**. The CREATE_OFFER URL-guard step, integration/concurrency suite, committed-session geography replay, wrapper-owner/function ACL checks, legacy migration cleanup, and participant self-enrollment checks all succeeded.
- PostgreSQL 17.6 compatibility job: **SUCCESS**. CREATE_OFFER integration/concurrency, committed-session geography replay, wrapper-owner and function ACL checks succeeded.
- CodeQL [#1822](https://github.com/meridane/QimaTrade-MVP/actions/runs/45382216899): **SUCCESS**.
- Combined Vercel status on the reviewed HEAD: **SUCCESS**.
- The prepared-transaction simulation jobs intentionally report their simulated failures; their dedicated assertion jobs succeeded, and the skipped-result job remained intentionally skipped.

## QA436 — runtime guard coverage for committed-session geography replay

### Finding

The QA427 committed-session geography replay runner already uses an exact disposable database URL comparison before its first `psql` call. Its static contract checked that exact URL restriction, but there was no isolated runtime regression proving that unset, empty, malformed, remote, alternate-loopback, query-bearing, whitespace-only, and control-character-bearing values stop before the database client.

This is a test-coverage gap in a disposable CI runner. It is not evidence of a production vulnerability.

### Change

- Added `tests/sql/test-create-offer-geography-default-committed-replay-runner-guard.sh`.
- The test supplies an inert `psql` stub that never opens a socket.
- It checks unset and empty `DATABASE_URL` separately.
- It rejects 15 unsafe forms, including remote hosts, wrong database/port/scheme, query strings, whitespace-only input, unsupported loopback aliases, LF/CR/TAB/SOH in credentials, and a control character in the path.
- Each rejected input must return exit 1, emit the generic QA427 diagnostic, disclose neither credentials nor injected markers, and leave the stub call/argument logs empty.
- The exact documented `postgresql://postgres:postgres@localhost:5432/qima_test` value must reach the inert stub exactly once with the expected four arguments. The stub exits 99, so no real connection or fixture SQL is executed.
- Updated `.github/workflows/ci.yml` to run the new regression in Verify.
- Updated `tests/sql/test-create-offer-geography-default-committed-replay-contract.sh` to require the new test file and exactly one Verify workflow invocation.

### Files changed

- `tests/sql/test-create-offer-geography-default-committed-replay-runner-guard.sh` — new isolated runtime URL-guard regression.
- `.github/workflows/ci.yml` — new Verify step.
- `tests/sql/test-create-offer-geography-default-committed-replay-contract.sh` — static workflow-wiring assertion.
- `docs/QIMA_V1_FUNCTION_REGISTER_QA436_APPEND.md` — this append-only QA record.

### Validation status

- Work branch: `work/qima-qa436-geography-replay-runner-guard-20261124-2022`, created from reviewed HEAD `52c3343fdb1dda20dc9d541ecbdb927a2ff634d8`.
- Parent QA435 validation: CI #1894, CodeQL #1822 and Vercel **SUCCESS**.
- QA436 has not yet been executed by GitHub Actions. The Verify job must run the new stub-based regression and the existing static QA427 contract after the work branch is fast-forwarded to PR #26.
- No local full-shell-suite result is claimed.

### Limits and safety

The new regression uses only a temporary directory and an inert `psql` stub. It does not connect to PostgreSQL and does not alter fixture data, schema, privileges, or migrations.

No Supabase Production data or migrations, secrets, grants, persistent RLS policies, production deployment, merge, force-push, or branch-protection settings were changed.
