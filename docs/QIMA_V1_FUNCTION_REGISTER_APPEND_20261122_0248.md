# QIMA V1 Function Register — append-only update

## Auth user identity shape guard — 22 November 2026, 02:48 KST

### Baseline verified before the change

- PR #26 is OPEN / DRAFT / not merged, mergeable=true; head 5b5aa76efcb8b6ef9f755bc17318ddf91fd7a3ca, base main, branch fix/create-offer-status-contract.
- The PR contains 2,215 commits ahead / 0 behind, 280 changed files, 89,519 insertions and 264 deletions.
- QIMA CI #1777 (https://github.com/meridane/QimaTrade-MVP/actions/runs/44925502506) and #1778 (https://github.com/meridane/QimaTrade-MVP/actions/runs/44925562756) both completed SUCCESS. Verify reported 406 Playwright passed in each run; npm audit, TypeScript, Next.js build, Chromium and the local QIMA fixture succeeded. PostgreSQL 16 and PostgreSQL 17.6 integration jobs succeeded in both runs.
- The setup-failure and cleanup-failure harness jobs have their intentionally negative conclusions; their dedicated assertions succeeded. The skipped harness remains skipped and its assertion succeeded.
- CodeQL #1707 (https://github.com/meridane/QimaTrade-MVP/actions/runs/44925502491) and #1708 (https://github.com/meridane/QimaTrade-MVP/actions/runs/44925562818) completed SUCCESS. The combined Vercel status for the baseline HEAD was SUCCESS.
- The Verify logs explicitly show the null Auth user payload and malformed Auth JSON regression tests passing.

### Change

Review of app/api/actions/create-offer/route.ts found that a truthy Auth user object was accepted without validating user.id, even though the route immediately uses it as the key for profile and membership lookups.

The route now requires a canonical UUID string after a successful getUser() response. A missing, null, empty, malformed, or non-string ID is treated as an invalid upstream Auth response and returns HTTP 503 with the generic AUTH_SERVICE_UNAVAILABLE body before any profile, membership, or RPC request.

The Playwright helper gained a private-only __authUserIdOverride switch, removed before the mocked request is sent. One parameterized regression covers five invalid shapes: missing, null, empty string, non-UUID string, and number. Every case asserts the exact generic 503 response, no private sentinel disclosure, no WWW-Authenticate challenge, exactly one /auth/v1/user request with the expected bearer token, and no downstream request.

### Validation status

- This is a small route guard plus E2E regression only; no SQL, migration, Supabase production data, grant, persistent RLS policy, secret, or production deployment is involved.
- The new test and guard are not yet validated by CI. They have been committed to the work branch; the PR branch will be advanced by a non-force fast-forward only after the work-branch commits are verified.
- No local Playwright or PostgreSQL tests were run. The synthetic test does not establish a production vulnerability.
- Next step: publish the work-branch commits to the PR branch by fast-forward, then verify the new Playwright case, full CI, PostgreSQL 16/17.6, CodeQL, and Preview.
