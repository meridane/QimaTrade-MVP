# QIMA Function Register — QA464 append-only update

Date: 2026-11-25 (KST)

## Scope

This entry records QA464, a CI-only regression for successful Docker discovery that returns an unusable PostgreSQL container list. The restoration script is exercised only with inert command mocks.

## Baseline

- PR #26 remains OPEN and DRAFT, not merged: https://github.com/meridane/QimaTrade-MVP/pull/26
- Base `main`; head `fix/create-offer-status-contract`.
- Baseline head before QA464: `79292973d3e3d3d7f02697a0dfb8e2d8ba414daa`.
- QA463 was validated by QIMA CI #1973: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925855 — Verify 77/77 steps SUCCESS, 423/423 Playwright, npm audit, TypeScript, Next.js build, Chromium, cleanup isolation, and QIMA security fixture; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 steps SUCCESS.
- QIMA CodeQL #1900 SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925439
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` reader returned an empty body with Blob SHA `cb3400116d33fb81650982600064454783aba218`; no replacement was attempted.

## QA464 — successful Docker discovery output boundaries

The restoration script already covered a non-zero `docker ps` exit (QA462). QA464 covers successful command execution whose output is unsafe to use.

The mock accepts `MOCK_DOCKER_PS_OUTPUT` while preserving the default valid ID when the variable is unset. Three cases are added:

1. Empty output: exit 1, exact diagnostic reports zero containers.
2. Two valid IDs: exit 1, exact diagnostic reports two containers.
3. One malformed ID: exit 1, exact invalid-ID diagnostic.

All cases assert that the event log contains only `docker-ps`, state remains `10`, and no readiness, RESET, restart, SQL postcondition, success marker, or credential disclosure occurs.

A read-back review caught an escaping defect in the first draft of the new harness block before a validation result was claimed. The block and printf format were corrected in the follow-up commit; the corrected file was fetched again and its final lines inspected.

## Validation status

- Baseline QA463 / CI #1973: SUCCESS, including PostgreSQL 16 and 17.6.
- QA464 on the corrected commit: pending GitHub Actions.
- No local test execution is claimed.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- These mocked CI cases verify fail-closed control flow; they do not establish a production vulnerability.
