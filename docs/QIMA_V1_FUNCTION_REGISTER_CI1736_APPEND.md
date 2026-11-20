# QIMA V1 Function Register — CI #1735 closeout and upstream 503 retry contract

Date: 2026-11-21 (KST)

## Verified baseline before this change

- Pull request #26 remains OPEN and targets `main`; its head before this work was `3ea03ba1092ffef5efe4f22a5ebaeadc8c6d744f`.
- `main...fix/create-offer-status-contract` comparison: 2,129 commits ahead, 0 behind.
- The head commit `3ea03ba` is documentation-only and records the preceding profile lookup contract.
- QIMA CI #1735 completed SUCCESS on that exact head. Verify completed successfully with 401 Playwright tests passed (12.8 s), npm audit, TypeScript, Next.js production build, and Chromium installation.
- PostgreSQL 16 integration and privilege-characterization job: SUCCESS.
- PostgreSQL 17.6 integration and privilege-characterization job: SUCCESS.
- The expected setup-failure and cleanup-failure harness jobs reported their intentional failures; their blocking assertion jobs succeeded. The deliberately skipped harness remained skipped and its assertion succeeded.
- CodeQL #1665: SUCCESS.
- Vercel status on the baseline head: SUCCESS.
- npm audit summary: 1 moderate, 0 high, 0 critical. This is below the workflow's blocking high threshold; it is not a statement that the dependency tree is free of advisories.

## New regression: upstream HTTP 503 retries

- Work branch: `work/create-offer-503-retry-contract-20261121-0807`.
- Test commit: `101ff9757d0b2169fd4e7b52b589997798944728`.
- File: `tests/e2e/create-offer-route-contract.spec.ts`.
- Adds one dedicated test covering profile and tenant-membership REST reads that return HTTP 503.
- The test expects the existing generic server contracts (`PROFILE_LOOKUP_FAILED` and `TENANT_MEMBERSHIP_LOOKUP_FAILED`), checks that private upstream message/code/details/hint values are not returned, and verifies that no later membership lookup or CREATE_OFFER RPC occurs after a failed profile read, and no RPC occurs after a failed membership read.
- Retry counts are deliberately not asserted exactly. Supabase/PostgREST clients may retry 503 responses; the test instead verifies the request-path sequence and that every retry remains scoped to the failing read.
- The test is a route-contract regression using the existing mocked Supabase fetch harness. It is not a live Supabase test and does not establish a production incident or vulnerability.

## CI status for the new test

- The test and companion record were fast-forwarded to PR #26; the PR branch and work branch now point to the same HEAD. At the post-push check, no PR-triggered QIMA CI or CodeQL run had yet been returned for the new HEAD. The Vercel combined status was PENDING.
- Continue polling the new PR HEAD and report exact Playwright/PostgreSQL results only when the corresponding runs appear. The 401/401 result above belongs only to the parent baseline `3ea03ba`, not to the new 503 test.

## Canonical register retrieval limitation

- `docs/QIMA_V1_FUNCTION_REGISTER.md` is a very large existing file. GitHub `fetch_file` returned a valid blob SHA but an empty content payload in both UTF-8 and base64 modes; the PR file-patch endpoint returned `patch: null`.
- To avoid replacing the canonical register with incomplete content, this append-only companion record is used for this run. The canonical file was not modified or truncated.

## Safety scope

- No Supabase production data, production migration, secret, persistent grant, RLS policy, production deployment, merge, force-push, or branch-protection setting was changed.
- No local tests were run. All CI claims above are taken from the GitHub Actions logs for run #1735.
