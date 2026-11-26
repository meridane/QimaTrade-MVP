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


## QA464 — final verification

- Corrected code commit: `e98c7df2303bce493cf45580b6c3b828e5382372`; documentation snapshot: `55ad3464a2772c0017336bba4c4646f8c23aab6e`.
- QIMA CI #1976 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637515597
  - Verify: 77/77 steps SUCCESS; 423/423 Playwright passed (38.6 s); npm audit, TypeScript, Next.js build, Chromium and QIMA security fixture SUCCESS.
  - PostgreSQL 16 integration: 48/48 steps SUCCESS.
  - PostgreSQL 17.6 compatibility: 33/33 steps SUCCESS.
  - Runtime log explicitly printed the QA464 Docker-discovery output guard marker after rejecting empty, multiple and malformed container IDs.
  - The two simulated setup/cleanup failure jobs intentionally concluded FAILURE; their independent blocking assertions succeeded. The skipped-result job was expected and its assertion succeeded.
- QIMA CodeQL #1903 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637516153
- Vercel status on the documentation-only HEAD was `failure` with `upgradeToPro=build-rate-limit`; this is an account build quota status, not evidence of a failed application build.
- QA464 is fully closed by CI #1976 and CodeQL #1903.

## QA465 — Docker container-ID boundary coverage

The restoration script accepts a lowercase hexadecimal container ID from 12 through 64 characters. QA465 adds explicit restore-path boundary coverage without changing the operational restore script:

1. A 64-character lowercase hexadecimal ID must be forwarded unchanged to both `docker exec` and `docker restart`; the full mocked restore sequence must reach QA267.
2. An 11-character ID must be rejected before readiness or mutation.
3. A 65-character ID must be rejected before readiness or mutation.
4. A 12-character uppercase hexadecimal-looking ID must be rejected because the accepted Docker ID contract is lowercase hexadecimal.

The Docker mock now accepts an explicit `MOCK_DOCKER_EXPECTED_ID` for exec/restart assertions; its default remains the existing 12-character ID, preserving earlier cases. Negative cases require only the `docker-ps` event and unchanged state `10`; the positive 64-character case requires the complete existing restoration event sequence, baseline `0`, and the QA267 success marker.

- Code/test commit: `04dc817c0f3d44d6a3db03c1059ff38596ce4eb6`.
- Corrected work branch and PR branch are fast-forward synchronized at this commit; no force-push.
- QIMA CI #1977: IN PROGRESS at this snapshot: https://github.com/meridane/QimaTrade-MVP/actions/runs/45651860882. The new QA465 runtime assertion has not yet been observed; do not claim it passes until the run log confirms the marker and all required jobs finish.
- QIMA CodeQL #1904: IN PROGRESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45651861011.
- The PR currently reports `mergeable=false` while checks are active; this is not interpreted as a code defect.
- No local test execution is claimed.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- QA464/QA465 are synthetic CI contract tests with inert mocks; they do not establish a production vulnerability.
