# QIMA V1 Function Register — append-only execution supplement

Date: 2026-11-20 08:59 KST

Repository: `meridane/QimaTrade-MVP`  
Pull request: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`

## Verified starting state

- PR state: OPEN, DRAFT, not merged; GitHub reported `mergeable=true`.
- Starting PR HEAD: `03d193937d17f1c7f06b9a44b0e6265b971e04b9`.
- Base: `main`; comparison: 2,056 commits ahead, 0 behind.
- PR diff: 268 files, 86,850 additions, 261 deletions.
- Latest checks on the starting HEAD: QIMA CI #1669 SUCCESS, CodeQL #1600 SUCCESS, Vercel status SUCCESS.
- Code/test parent: `e74dcb6909eee0e0d1f37e4c344f4889f9c2cb80`; QIMA CI #1666 and CodeQL #1597 completed SUCCESS. The prior recorded Verify result for that code parent was 395/395 Playwright.

## Regression coverage added in this execution

File: `tests/e2e/create-offer-route-contract.spec.ts`

The existing test for explicit tenant selection with multiple memberships now runs both membership orders:
1. first tenant followed by second tenant;
2. second tenant followed by first tenant.

Both cases submit the same client-supplied `tenantId` and assert:
- HTTP 409;
- exact `TENANT_SELECTION_REQUIRED` JSON response;
- only Auth, profile, and membership reads occur;
- no `execute_create_offer_v1` RPC is called.

This is an order-invariance regression test for the already implemented rule that more than one distinct membership requires explicit tenant selection. It does not introduce or decide a new tenant-selection policy.

## Validation status

- No local test suite was run in this execution.
- A new QIMA CI and CodeQL run will be triggered by publishing the test commit to the PR branch; results must be recorded only after GitHub reports them.
- No application code, SQL, migrations, Supabase Production data, grants, RLS policies, secrets, or production deployment were changed.

## Registry retrieval limitation

The GitHub file-content connector returned a valid blob SHA but an empty content body for the 2.35-million-character canonical `docs/QIMA_V1_FUNCTION_REGISTER.md`, including when requesting line ranges and base64 encoding. Its PR patch was also unavailable (`patch=null`). To avoid replacing the canonical register with incomplete content, this execution is recorded in this append-only companion file. The canonical register itself was not modified.

## Next step

Verify the new Playwright run, PostgreSQL 16/17.6 jobs, CodeQL, and Preview checks for the new PR HEAD. Once full canonical register content is retrievable, fold this supplement into `docs/QIMA_V1_FUNCTION_REGISTER.md` without dropping its history.


---

## Update — 2026-11-20 09:38 KST

### Re-verified repository and PR state

- PR #26 remains OPEN, DRAFT, and not merged.
- Base branch: `main`, base SHA `0d35c13db81019867fe9929420b0a6916285fbf6`.
- Before this update, PR HEAD was `d5ad8aeccb964c26f8292ce3eb3600b98baf860d`; the branch had 2,058 commits ahead of `main`, 0 behind, and 269 changed files.
- The base branch now includes commit `0d35c13db81019867fe9929420b0a6916285fbf6` (`feat(automation): add QIMA 15-minute autonomous development loop`). This run did not modify any workflow or GitHub configuration.
- The canonical register still returns blob SHA `b4bdfb1ae2f2ba41c9619fe5298b04357da42f0c` but an empty body from the GitHub file-content connector, including UTF-8 and base64 reads. The canonical file was not replaced or rewritten.

### Closed validation for the previous PR HEAD

- QIMA CI #1670: SUCCESS.
- Verify job: npm audit, TypeScript, production build, Chromium, and Playwright all SUCCESS; the Playwright log explicitly reports **395 passed (12.8s)**.
- PostgreSQL 16 integration: SUCCESS.
- PostgreSQL 17.6 compatibility: SUCCESS.
- CodeQL #1601: SUCCESS.
- Vercel status on the previous HEAD: SUCCESS.
- The setup-failure and cleanup-failure harness jobs intentionally report failure; their dedicated assertions passed. The deliberately skipped harness remains skipped and is checked by a passing assertion job.

### New regression coverage published

File: `tests/e2e/create-offer-route-contract.spec.ts`

Commit: `fd131c2b3adbc8c09c315d22422935cfc1b0a6b9`

Added one independent test:

`CREATE_OFFER route trims required name and demand IDs before action execution`

The test submits surrounding spaces, tabs, and newlines for both required fields and verifies:
- exactly one CREATE_OFFER execution RPC;
- `p_name` and `p_input.name` contain the trimmed name;
- `p_demand_id` and `p_input.demandId` contain the trimmed demand ID;
- the expected Auth → profile → membership → action-definition → execution request sequence;
- the same authenticated Bearer token is forwarded.

The route already performs this normalization; no application behavior was changed. The route-contract file now contains 70 test declarations (previously 69). The full Playwright suite is expected to contain 396 tests, but that count is not considered validated until the new run completes.

### Validation for the new test commit

- The test commit was fast-forwarded to `fix/create-offer-status-contract` using `force=false` and an expected-old-SHA guard.
- At the first post-push check, the PR HEAD was `fd131c2b3adbc8c09c315d22422935cfc1b0a6b9`; PR remained OPEN/DRAFT/not merged. GitHub temporarily reported `mergeable=false` while checks were pending.
- Vercel Preview was PENDING.
- No new GitHub Actions run was yet visible for this SHA in the first workflow-run query. Therefore no result is claimed for the new test. Recheck CI, CodeQL, and Preview before treating it as validated.
- No local tests were run in this execution.

### Correlation ID contract remains unresolved

The current route receives or generates `correlationId` and passes it in `ActionContext`. The CREATE_OFFER runtime handler does not send it to the SQL RPC; the existing CREATE_OFFER migration generates a separate `v_correlation_id` with `gen_random_uuid()` for persisted execution/event records. This is a verified implementation difference, not a confirmed vulnerability. Do not change the SQL signature or migration until the intended correlation-ID contract is approved.

### Guardrails

No application code, SQL, migration, Supabase Production data, grant, RLS policy, secret, production deployment, merge, force-push, or branch-protection rule was changed. The only code change in this update is a regression test; this document is an append-only companion because the canonical register body remains unavailable.


---

## Validation refresh — 2026-11-20 09:38 KST

### Results for the new regression commit

- QIMA CI #1671 was created for test commit `fd131c2b3adbc8c09c315d22422935cfc1b0a6b9`.
- Verify job: **SUCCESS**.
  - npm audit: SUCCESS (audit threshold is `high`; the workflow log reports the audit step completed).
  - TypeScript: SUCCESS.
  - Next.js production build: SUCCESS.
  - Chromium installation: SUCCESS.
  - Playwright: **396 passed (8.6s)**.
  - The new test `CREATE_OFFER route trims required name and demand IDs before action execution` is explicitly shown as passed in the log.
- PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs were still **IN PROGRESS** at the latest check. The active PostgreSQL 16 step was the attributes-default replay regression; PostgreSQL 17.6 was still in its integration/concurrency tests. No final result is claimed for either job.
- CodeQL #1602: **SUCCESS**.
- Vercel Preview for the current documentation HEAD at the time of the check: **SUCCESS**.
- The push of the append-only documentation commit also caused a separate QIMA CI #1672 (PENDING, no jobs published at the latest check) and CodeQL #1603 (IN PROGRESS). These are checks for the documentation HEAD, not a second execution of the new Playwright test.

### PR coordination note

PR #25 (`chore/qima-free-autopilot-review`) is also open and changes `app/api/actions/create-offer/route.ts`. This execution did not modify that route and did not duplicate its application-code work; the new regression is isolated to `tests/e2e/create-offer-route-contract.spec.ts`. Review the route diff across PRs before any future integration.

### Current branch snapshot before this documentation refresh

- PR #26: OPEN, DRAFT, not merged; `mergeable=true`.
- Base: `main` at `0d35c13db81019867fe9929420b0a6916285fbf6`.
- Test commit: `fd131c2b3adbc8c09c315d22422935cfc1b0a6b9`.
- Documentation commit then at PR HEAD: `69bb6fd4286159da4b37f1f36e192b318974cf43`.
- PR comparison: 2,060 commits ahead, 0 behind; 269 changed files.
- The work branch and PR branch were identical (0 ahead / 0 behind) before this documentation refresh.

No application source, SQL, migration, Supabase Production data, grant, RLS policy, secret, workflow, or production deployment was changed. No merge, force-push, or branch-protection change was made.


---

## Post-publication status correction — 2026-11-20 09:38 KST

- Current PR HEAD before this final note: `0496fe9cff9278232101229e9ea7e30e6e885b37`; PR #26 OPEN / DRAFT / not merged, `mergeable=true`, 2,061 commits ahead of `main`, 0 behind, 269 changed files (87,042 additions / 261 deletions). Base remains `main` at `0d35c13db81019867fe9929420b0a6916285fbf6`.
- Work branch `work/create-offer-required-field-trimming-20261120-0938` and PR branch were identical at that HEAD (0 ahead / 0 behind).
- QIMA CI #1671: Verify job **SUCCESS**, including **396/396 Playwright**; the new required-field trimming test is explicitly PASS. npm audit, TypeScript, production build, and Chromium installation completed successfully.
- PostgreSQL 16 and PostgreSQL 17.6 jobs in CI #1671 remain **IN PROGRESS**, each at the full CREATE_OFFER runner write-privilege characterization. No final database-job conclusion is claimed.
- CodeQL #1602: **SUCCESS**.
- The earlier documentation-head QIMA CI #1672 was **CANCELLED before jobs were published** after the next push; this is not a test failure. CodeQL #1603: **SUCCESS**.
- The then-current final documentation HEAD had QIMA CI #1673 **PENDING** and CodeQL #1604 **IN PROGRESS**. Vercel Preview for that HEAD was **PENDING**. A further documentation-only commit follows this snapshot; verify the resulting HEAD checks separately.
- PR #25 also changes `app/api/actions/create-offer/route.ts`; this execution changes only the E2E contract test and this append-only note. No application-route changes were made.
- No local test suite was run. No production data, migration, RLS policy, grant, secret, workflow, deployment, merge, force-push, or protection rule was changed.
