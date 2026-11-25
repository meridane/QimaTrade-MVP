# QIMA Function Register — QA465 append-only update

Date: 2026-11-26 (KST)

## Scope

This entry records the final QA464 result and the runtime evidence for QA465, a CI-only regression covering Docker PostgreSQL container-ID validation in the prepared-transaction restoration script. The tests use inert Docker/PostgreSQL command mocks; the operational restore script is not changed.

## QA464 — closed

- Corrected code commit: [e98c7df2303bce493cf45580b6c3b828e5382372](https://github.com/meridane/QimaTrade-MVP/commit/e98c7df2303bce493cf45580b6c3b828e5382372).
- QIMA CI #1976 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637515597
  - Verify: 77/77 steps SUCCESS; 423/423 Playwright passed; npm audit, TypeScript, Next.js build, Chromium, and QIMA security fixture SUCCESS.
  - PostgreSQL 16 integration: 48/48 steps SUCCESS.
  - PostgreSQL 17.6 compatibility: 33/33 steps SUCCESS.
  - Runtime log explicitly confirmed the QA464 empty/multiple/malformed Docker discovery output guard.
- QIMA CodeQL #1903 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45637516153
- The Vercel status on the preceding documentation-only HEAD was `upgradeToPro=build-rate-limit`; this is an account quota status, not a compilation failure.
- QA464 is fully closed.

## QA465 — Docker container-ID boundaries

Code/test commit: [04dc817c0f3d44d6a3db03c1059ff38596ce4eb6](https://github.com/meridane/QimaTrade-MVP/commit/04dc817c0f3d44d6a3db03c1059ff38596ce4eb6).

The restoration script accepts lowercase hexadecimal Docker IDs from 12 through 64 characters. QA465 extends the restore-path mock contract:

1. A 64-character lowercase hexadecimal ID is forwarded unchanged to both `docker exec` and `docker restart`; the full restore sequence reaches QA267.
2. An 11-character ID is rejected before readiness or mutation.
3. A 65-character ID is rejected before readiness or mutation.
4. A 12-character uppercase hexadecimal-looking ID is rejected.

The Docker mock uses `MOCK_DOCKER_EXPECTED_ID` for the exec/restart target assertion while retaining the existing 12-character default for all prior cases.

### Runtime evidence

- QIMA CI #1977: https://github.com/meridane/QimaTrade-MVP/actions/runs/45651860882
- The actual restore-script step completed SUCCESS and the log explicitly printed: `QA465 Docker container-ID boundary guard passed: a 64-character lowercase hexadecimal ID was forwarded unchanged; 11-character, 65-character, and uppercase IDs were rejected before readiness or mutation.`
- The same runtime step printed the QA462 and QA464 markers.
- The independent `Assert prepared-transaction always-cleanup runtime contract` job completed SUCCESS.
- The enclosing setup-failure job intentionally concludes FAILURE because its setup step exits 47; its actual restore-script step completed SUCCESS. The separate cleanup-failure job likewise exercises an intentional failure path and is not treated as a regression failure.

### Remaining validation / blockers

- QIMA CI #1977 remains IN PROGRESS at the last inspection. The Verify job completed SUCCESS (including npm audit, TypeScript, Next.js build, Chromium and browser tests). PostgreSQL 16 and PostgreSQL 17.6 jobs remain active at the full CREATE_OFFER runner write-privilege characterization step. No overall CI success is claimed.
- QIMA CodeQL #1904 completed FAILURE in the `Perform CodeQL analysis` step after query evaluation and SARIF export, during the code-scanning result upload phase. The available log did not expose a definitive upload error or a specific finding. This is recorded as an unresolved CodeQL workflow failure, not as a confirmed vulnerability.
- A retry through the connected GitHub Actions operation failed internally; no retry is claimed.
- The PR branch and work branch contain the QA465 code commit. A follow-up runtime-evidence snapshot exists on the work branch; the attempt to fast-forward that documentation-only commit to the PR branch encountered repeated GitHub GraphQL service errors. This new append file is therefore written directly to the PR branch.
- No local test execution is claimed.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- QA464/QA465 are synthetic CI contract tests with inert mocks. They do not establish a production vulnerability.
