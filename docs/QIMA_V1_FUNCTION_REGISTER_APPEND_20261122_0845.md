# QIMA V1 Function Register — append-only validation note

## Auth upstream timeout classification regression — 22 November 2026, 08:45 KST

### Baseline inspected before change

- PR #26 is OPEN, DRAFT, not merged, and GitHub reports `mergeable=true`; title: `fix: align CREATE_OFFER execution statuses`; base `main`, head branch `fix/create-offer-status-contract`.
- Baseline PR HEAD: `867d24ca07eece795a14435b0f5eb2ecf11e34b8`; compare against `main`: 2,235 commits ahead / 0 behind; 284 changed files (89,877 additions / 264 deletions).
- Latest commit at baseline: `867d24ca`, `docs(qima): record post-publication Auth 429 validation status`.
- QIMA CI #1791 on the baseline HEAD completed SUCCESS. The Verify job log reports **409 Playwright passed (37.0 s)**; dependency audit, TypeScript, Next.js production build, Chromium, and the QIMA security-contract fixture succeeded. PostgreSQL 16 and PostgreSQL 17.6 integration jobs both completed SUCCESS.
- The two prepared-transaction harness jobs have job-level FAILURE because they deliberately simulate setup/cleanup failures; their dedicated assertion jobs completed SUCCESS. The intentionally skipped harness remained SKIPPED. These are expected contract-test outcomes, not unexpected CI failures.
- CodeQL #1720 completed SUCCESS.
- The baseline combined commit status reports Vercel FAILURE due to `api-deployments-free-per-day` / free-tier `build-rate-limit`. This is a Preview quota issue, not an application test failure or Production deployment.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was read through GitHub Contents API. GitHub returned blob SHA `e9d2d55a34c791f86decc9eddf708c1cfad77c7d` but an empty content body. To avoid replacing the large register without its complete content, this run adds a companion append-only note.

### Finding and change

- Before this change, Auth errors with status 0, 429, or >=500 were mapped to HTTP 503 `AUTH_SERVICE_UNAVAILABLE`, but HTTP 408 fell through to HTTP 401 `UNAUTHENTICATED`.
- An upstream Auth HTTP 408 is a timeout response, not evidence that the caller's bearer token is invalid. Classifying it as 401 could incorrectly produce an authentication challenge for an upstream timeout.
- Updated `app/api/actions/create-offer/route.ts` to classify status 408 alongside status 0, 429, and >=500 as HTTP 503 `AUTH_SERVICE_UNAVAILABLE`.
- Extended the existing regression test `CREATE_OFFER route maps Auth upstream outages and transport exceptions to a generic 503` with HTTP 408. Its existing assertions require the generic 503 body, no `WWW-Authenticate` challenge, no private upstream error leakage, and no requests beyond `/auth/v1/user`.
- No retry policy, database query, SQL, migration, business status, or persistence behavior changed.

### Work branch and commits

- Work branch: `work/qima-auth-408-timeout-20261122-0845`, created from baseline PR HEAD `867d24ca07eece795a14435b0f5eb2ecf11e34b8`.
- Route commit: `79e5d8109ed6e3e4ddf9fcb28b875f816e613fbf` — `fix(create-offer): classify Auth timeout as unavailable`.
- Regression-test commit: `5c30abfb28be3d3107c3e15715999aa3dc4ea145` — `test(create-offer): cover Auth HTTP 408 timeout`.
- Both code commits were created on the isolated work branch. No PR-triggered workflow run was returned for those standalone commits before publication. No local test execution is claimed.
- After publication to the PR branch, only a workflow run associated with the resulting exact HEAD can validate this change. The baseline #1791 result is not attributed to the new HTTP 408 case.

### Safety boundary

- The regression uses a synthetic Auth HTTP 408 response and characterizes route error mapping only. It does not establish a production Auth outage or vulnerability.
- No Supabase Production data, migration, secret, grant, or persistent RLS policy was accessed or changed. No Production deployment, PR merge, force-push, or branch-protection change was performed.
