# QIMA Function Register — QA464 append-only update

Date: 2026-11-25 (KST)

## Scope

This entry records QA464, a CI-only regression for successful Docker discovery that returns an unusable PostgreSQL container list. The production restoration script is exercised only with inert command mocks.

## Baseline PR and completed checks

- PR #26 remains OPEN and DRAFT, not merged: https://github.com/meridane/QimaTrade-MVP/pull/26
- Base: `main`; head: `fix/create-offer-status-contract`.
- Baseline head: `09d11fa9fa5a3822e981bb11cba69369d394bc0a`; GitHub reports `mergeable=true`, 2,492 commits ahead and 0 behind; 304 changed files; no submitted reviews and no review threads.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was read at this head. The GitHub file reader returned an empty body with Blob SHA `cb3400116d33fb81650982600064454783aba218`; no destructive replacement was attempted.
- QIMA CI #1973 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925855
  - Verify: 77/77 steps SUCCESS, including npm audit, TypeScript, Next.js build, Chromium, 423/423 Playwright, cleanup harness isolation, and the QIMA security fixture.
  - PostgreSQL 16 integration: 48/48 steps SUCCESS.
  - PostgreSQL 17.6 compatibility: 33/33 steps SUCCESS.
  - Cleanup assertion job: SUCCESS; the two cleanup simulation jobs intentionally conclude FAILURE because their contract is to propagate injected setup/cleanup failures. Their independent assertions passed.
- QIMA CodeQL #1900 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925439
- QA463 isolation correction is therefore validated by the completed CI #1973.

## QA464 — Docker discovery output boundaries

The restoration script already handled a non-zero `docker ps` exit (QA462), but its successful-command output branches had not been directly covered. The mock now supports a controlled `MOCK_DOCKER_PS_OUTPUT` value while retaining the existing default container ID.

Three cases are added:

1. Empty output: exit 1, exact diagnostic reports zero containers, and no readiness or database/configuration operation occurs.
2. Two valid IDs: exit 1, exact diagnostic reports two containers, and no later operation occurs.
3. One malformed ID: exit 1, exact invalid-ID diagnostic, and no later operation occurs.

Each case asserts that the mock state remains `10`, the event log contains only `docker-ps`, no postcondition or success marker is emitted, and no connection credentials appear in diagnostics.

The valid single-container default remains unchanged, so all prior QA447 and QA452–QA463 scenarios continue to use the same normal mock path.

## Validation status

- Baseline QA463 / CI #1973: SUCCESS, including PostgreSQL 16 and 17.6.
- QA464 runtime and assertions: pending the new GitHub Actions run on the code/test commit.
- No local test execution is claimed.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- These mocked CI cases verify fail-closed control flow; they do not establish a production vulnerability.
