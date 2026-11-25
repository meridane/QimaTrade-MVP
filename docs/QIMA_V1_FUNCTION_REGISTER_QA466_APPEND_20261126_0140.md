# QIMA Function Register — QA466 append-only update

Date: 2026-11-26 (KST)

## Scope

This entry closes QA465 from the completed CI run and records the CodeQL upload failure and retry state observed on the documentation HEAD. The tests are CI-only contract tests using inert command mocks. They do not establish a production vulnerability.

## QA465 — closed

- Code/test commit: [04dc817c0f3d44d6a3db03c1059ff38596ce4eb6](https://github.com/meridane/QimaTrade-MVP/commit/04dc817c0f3d44d6a3db03c1059ff38596ce4eb6).
- QIMA CI #1979 completed SUCCESS on documentation HEAD `a224d0293fbf19e609f5c648de8948ad56dfb3c7`: https://github.com/meridane/QimaTrade-MVP/actions/runs/45652418898
  - Verify job SUCCESS: npm audit, TypeScript, Next.js build, Chromium, browser tests and QIMA security fixture passed.
  - Playwright: 423/423 passed.
  - CREATE_OFFER PostgreSQL integration job SUCCESS.
  - PostgreSQL 17.6 compatibility job SUCCESS.
  - The QA465 runtime marker was emitted by the actual restore-script test step; the independent cleanup runtime assertion job also completed SUCCESS.
  - The two harness jobs whose setup/cleanup steps deliberately return codes 47/52 have conclusion FAILURE by design; their blocking assertion jobs completed SUCCESS. The skipped-result harness was SKIPPED as designed.
- QA465 is fully closed. No local test execution is claimed.

## CodeQL #1906 — first attempt failed; retry running

- Run: https://github.com/meridane/QimaTrade-MVP/actions/runs/45652418998
- Attempt 1 completed FAILURE in `Perform CodeQL analysis` after database build, query evaluation and SARIF export.
- The available log shows the upload phase began (`Uploading results`) but contains no explicit HTTP status or definitive upload error. It is not possible to attribute the failure to a finding, permission, repository setting or service outage from the available evidence.
- The workflow declares `security-events: write`, `contents: read` and `actions: read`; no permission or repository setting was changed.
- A failed-jobs-only retry was accepted by GitHub. Attempt 2 was observed QUEUED and then IN_PROGRESS at the time of this entry. No retry success is claimed.
- This workflow failure is not evidence of a confirmed vulnerability. The SARIF export completed, but no conclusion about its findings or successful publication is drawn.

## Branch and repository state

- Pull request #26 remains OPEN, DRAFT, not merged; head branch `fix/create-offer-status-contract`; HEAD at this snapshot: `a224d0293fbf19e609f5c648de8948ad56dfb3c7`.
- This file is an append-only work-branch snapshot. It does not replace the canonical register, whose GitHub contents reader currently returns an empty body despite a valid blob SHA.
- The code/test parent is unchanged; this entry is documentation only.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- QA465 uses synthetic CI mocks and does not prove a production vulnerability.
