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


## Follow-up: transport-level profile and membership lookup failures (2026-11-21, 08:24 KST)

### Verified PR baseline and CI #1737 closeout

- PR #26 was re-read before this work: OPEN, DRAFT, not merged, base `main`, head `d5ad8f5966a082562c0bb0f6b340151020bde833`, 2,132 commits ahead of main, 0 behind, 272 changed files, 88,151 additions and 262 deletions. GitHub reported `mergeable=true`.
- The last commits inspected were `d5ad8f59` (this companion-register snapshot), `101ff975` (upstream HTTP 503 retry regression), and `135187af` (initial companion register).
- QIMA CI #1737 completed SUCCESS on the PR head `d5ad8f59`. Verify completed SUCCESS; the Playwright log reports **402 passed (23.4 s)**, including the HTTP 503 profile/membership retry test. npm install/audit, TypeScript, Next.js production build, Chromium, and the static workflow contracts completed successfully.
- The PostgreSQL 16 CREATE_OFFER integration job and PostgreSQL 17.6 compatibility job both completed SUCCESS. Their completed steps include the full runner privilege characterization and the associated legacy RLS/wrapper checks.
- The prepared-transaction setup/cleanup simulation jobs intentionally report failure; the dedicated assertion jobs completed SUCCESS. The skipped-harness job remained skipped and its assertion succeeded. These expected harness outcomes did not fail the workflow.
- CodeQL #1667 completed SUCCESS. The combined Vercel status for `d5ad8f59` was SUCCESS.
- The workflow-level conclusion is SUCCESS even though the job-list wrapper still displayed the expected cleanup-failure simulation job as `in_progress` with conclusion `failure`; all substantive CI jobs and the blocking assertion jobs were complete and successful.

### New transport-error regression on the work branch

- Work branch: `work/create-offer-lookup-transport-error-contract-20261121-0824`, based on `d5ad8f5966a082562c0bb0f6b340151020bde833`.
- Route commit: `b26682c863bb51796c0948cdfe54c8eeaf6454cf`, file `app/api/actions/create-offer/route.ts`.
- Test commit: `b8d590b890a0852972dae072910cff4bb4583923`, file `tests/e2e/create-offer-route-contract.spec.ts`.
- The route now normalizes both returned Supabase lookup errors and thrown transport exceptions for `profiles` to HTTP 500 `PROFILE_LOOKUP_FAILED), and for `dt_memberships` to HTTP 500 `TENANT_MEMBERSHIP_LOOKUP_FAILED`. A failed profile read stops before membership access; a failed membership read stops before the action-definition and CREATE_OFFER RPCs. Existing absent-profile and absent-membership 403 contracts remain unchanged.
- The test harness accepts a `network-error` outcome for each lookup and throws private transport sentinels from the mocked fetch. The new regression checks the generic public error, no private sentinel disclosure, that retries (if any) stay scoped to the failed endpoint, that the authenticated Bearer header is retained, and that no downstream membership/RPC operation occurs after the corresponding failure.
- The two commits are currently **2 ahead / 0 behind** the PR branch. They have not yet been published to PR #26, so no CI result is claimed for these new changes. The next publication should be a fast-forward after confirming the existing #1737 run is complete; then verify the new PR-triggered CI and CodeQL runs.

### Correlation ID contract review — decision required, no change made

- The CREATE_OFFER route places a trimmed caller-supplied `body.correlationId`, or a generated UUID when blank/absent, into `ActionContext.correlationId`.
- `executeAction` passes the original context object to the handler; the existing action-engine regression asserts that identity-preserving behavior.
- The CREATE_OFFER runtime handler does not read `actionContext.correlationId` and does not send a `p_correlation_id` RPC argument. It sends the tenant, idempotency key, input, and business parameters.
- Migration `20261027090000_fix_create_offer_action_status_contract.sql` independently assigns `v_correlation_id := gen_random_uuid()` and persists that database-generated value to `action_executions.correlation_id` and the event log.
- Consequently, the route-level caller correlation ID is currently not the persisted CREATE_OFFER correlation ID. This is a contract/architecture mismatch to clarify, not a confirmed vulnerability. Choosing whether the client value should be persisted or whether the database remains authoritative is a product/architecture decision. No runtime/RPC/migration change was made; production migrations are outside this task's allowed scope.

### Safety and validation status

- No local tests were run. The 402 Playwright and PostgreSQL results above belong only to CI #1737 on the prior PR head, not to the two new work-branch commits.
- No Supabase production data or migrations, secrets, persistent grants, RLS policies, production deployment, merge, force-push, or branch-protection setting was changed.
- The mocked transport-failure regression characterizes the route contract and does not establish a production incident or vulnerability.
