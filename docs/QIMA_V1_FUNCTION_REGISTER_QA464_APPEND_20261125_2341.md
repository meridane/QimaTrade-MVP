# QIMA Function Register — QA464 append-only update

Date: 2026-11-25 (KST)

## Scope

This entry records QA464, a CI-only regression for successful Docker discovery that returns an unusable PostgreSQL container list. The restoration script is exercised only with inert command mocks.

## Baseline

- PR #26 remains OPEN and DRAFT, not merged: https://github.com/meridane/QimaTrade-MVP/pull/26
- Base `main`; head `fix/create-offer-status-contract`.
- Baseline head before QA464: `09d11fa9fa5a3822e981bb11cba69369d394bc0a`.
- QA463 was validated by QIMA CI #1973: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925855 — Verify 77/77 steps SUCCESS, 423/423 Playwright, npm audit, TypeScript, Next.js build, Chromium, cleanup isolation, and QIMA security fixture; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 steps SUCCESS.
- QIMA CodeQL #1900 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925439
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` reader returned an empty body with Blob SHA `cb3400116d33fb81650982600064454783aba218`; no replacement was attempted.

## QA464 — successful Docker discovery output boundaries

The restoration script already covered a non-zero `docker ps` exit (QA462). QA464 covers successful command execution whose output is unsafe to use.

The mock accepts `MOCK_DOCKER_PS_OUTPUT` while preserving the default valid ID when the variable is unset. Three cases are added:

1. Empty output: exit 1, exact diagnostic reports zero containers.
2. Two valid IDs: exit 1, exact diagnostic reports two containers.
3. One malformed ID: exit 1, exact invalid-ID diagnostic.

All cases assert that the event log contains only `docker-ps`, state remains `10`, and no readiness, RESET, restart, SQL postcondition, success marker, or credential disclosure occurs.

## First CI attempt and correction

- Initial code/test commit `79292973d3e3d3d7f02697a0dfb8e2d8ba414daa` triggered QIMA CI #1974: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637162637
- Verify failed in `test-prepared-transactions-harness-isolation.sh`. The job log showed the normal mock path returned an invalid container ID before the isolation scenario could complete.
- Root cause: the first generated mock format string contained a doubled backslash before `n`, so Bash printf emitted a literal backslash-n suffix instead of a line terminator. The restoration script correctly rejected that malformed ID.
- The first draft of the new QA464 cases also had over-escaped shell continuations. These were corrected before claiming QA464 validation.
- Corrected code and shell formatting were published in commit `e98c7df2303bce493cf45580b6c3b828e5382372`. A fresh read-back confirmed a single printf newline escape, one shell continuation per continued line, and the three intended ANSI-C quoted test inputs.
- The QA464 documentation was updated in the same follow-up commit to record the initial failure honestly and distinguish it from the corrected rerun.

## Validation status at this snapshot

- Baseline QA463 / CI #1973: SUCCESS, including PostgreSQL 16 and 17.6.
- CI #1974: Verify FAILURE due to the first-draft mock formatting; npm audit was skipped after Verify failed, so this run does not establish a dependency vulnerability finding. PostgreSQL 16 and 17.6 jobs were still running at the last inspection.
- Corrected QIMA CI #1975 on `e98c7df2303bce493cf45580b6c3b828e5382372`: PENDING, no jobs published at the last inspection: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637315028
- Corrected CodeQL #1902: IN PROGRESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637315075
- QA464 runtime and assertions: not yet validated; wait for CI #1975.
- No local test execution is claimed.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- These mocked CI cases verify fail-closed control flow; they do not establish a production vulnerability.
