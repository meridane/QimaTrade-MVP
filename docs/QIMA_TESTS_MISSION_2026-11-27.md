# QimaTrade — TESTS mission checkpoint

Date: 2026-11-27 (Asia/Seoul)

## Provenance

- Repository: `meridane/QimaTrade-MVP`
- PR under observation: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
- Verified base HEAD: `61002cb21aaa738a7f018794ab84bff41a2c6eb2`
- Mission branch: `work/qima-tests-publish-runtime-20261127-0441`
- Branch created directly from the verified PR HEAD

## Coverage review

The existing Playwright suite already has broad CREATE_OFFER input, auth, idempotency, malformed-result and replay coverage. The PUBLISH_PRODUCT_REQUEST runtime suite previously covered:
- action-definition redirect rejection;
- publish-RPC redirect rejection;
- successful publish execution.

It did not have a focused test for a non-redirect SQL/PostgREST domain error returned by the publish RPC, including whether the runtime makes only one publish attempt.

## Change

Updated `tests/e2e/action-runtime-publish-product-request.spec.ts`:
- extended the local HTTP fixture with a configurable non-200 publish-RPC response;
- added a regression asserting the exact `PRODUCT_REQUEST_NOT_FOUND` domain message is propagated by the runtime;
- asserted the action-definition and publish RPC each occur once, the publish payload is unchanged, and no redirect target is visited.

This is test-only. No application source, SQL, migration, production data, or workflow configuration changed.

## Validation

- The parent PR HEAD's QIMA CI #2036 is **SUCCESS** (Verify, PostgreSQL 16, PostgreSQL 17.6 and assertion jobs); CodeQL #1962 is **SUCCESS**; combined Vercel status is **SUCCESS**.
- The added test has **not yet executed** on this isolated branch. No local npm/Playwright command was available in this connector-only execution. Mark the new test **PENDING**, not PASS.
- No new SQL test was justified by this review: the current branch already has extensive CREATE_OFFER replay, concurrency, boundary and ACL fixtures. The uncovered non-redirect publish-RPC error path is narrower and non-duplicative.

## Risks and next step

- Confirmed gap: the runtime's PUBLISH_PRODUCT_REQUEST test file had redirect and success cases but no direct non-redirect RPC-error case.
- Hypothesis not promoted to a defect: no behavior change is proposed based on this coverage gap alone.
- Next: run this test and the full Verify job on the branch, then compare the diff against the independent SECURITY branch. The new security-route tests and this runtime test touch different files.

No Supabase Production data/schema, migration, secret, grant, RLS policy or persistent configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change was performed.

## Validation update — 2026-11-27

- QIMA Verify job in run [45891165262](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891165262): **SUCCESS**. TypeScript, dependency audit, production build and browser suite passed; Playwright reported **436 passed**, including the new non-redirect SQL domain-error regression.
- The new fixture also includes synthetic PostgREST details and hint values and asserts that only the exact public message is propagated, with one publish RPC attempt and no redirect. This is synthetic contract coverage, not proof of a Production issue.
- QIMA CodeQL run [45891165382](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891165382): **SUCCESS**.
- PostgreSQL 16 and 17.6 integration jobs in run #45891165262 are still in progress. Vercel Preview for the updated commit is blocked by the provider's 24-hour build-rate limit.
- No database or Supabase Production data was modified.

## Final CI result for this branch — 2026-11-27

- QIMA CI [45891165262](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891165262): **SUCCESS**.
- TypeScript, dependency audit, Next.js production build and Playwright: **PASS**; Playwright reported **436 passed**.
- PostgreSQL integration: **PASS** on PostgreSQL 16 (446 s) and PostgreSQL 17.6 (438 s).
- QIMA CodeQL [45891165382](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891165382): **SUCCESS**.
- The expected-failure/skip harness jobs show failure or skipped at job level by design; their dedicated blocking assertion jobs passed, and the overall workflow concluded SUCCESS.
- Vercel Preview remains rate-limited for this branch; GitHub Actions validation is complete independently of that provider status.

## Latest CI revalidation — 2026-11-27

- QIMA CI [45892188791](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892188791): **SUCCESS** on this branch's documentation closeout commit.
- Verify job 140159917243: **436 Playwright tests passed (35.9 s)**; TypeScript, dependency audit and Next.js production build passed.
- PostgreSQL 16 job 140159917421: **SUCCESS**. PostgreSQL 17.6 job 140159917436: **SUCCESS**.
- CodeQL [45892188778](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892188778): **SUCCESS**.
- This was a revalidation of the existing test-only change; no new test code was added by this documentation closeout.
- Vercel Preview is blocked by the provider's build-rate-limit response. GitHub Actions validation completed independently.
## Transient upstream recovery regression added — 2026-11-27

- Added a focused synthetic HTTP 503 case to `tests/e2e/action-runtime-publish-product-request.spec.ts`.
- The test requires one action-definition POST and one publish RPC POST, preserves the exact request body, rejects the upstream error without retrying, and verifies that no redirect target is contacted.
- The fixture uses a synthetic `UPSTREAM_TEMPORARILY_UNAVAILABLE` response with private `details` and `hint` fields. It does not assert a live Supabase outage or a Production failure.
- Commit `aa854a84ffe43d041881849c4f40ee40d1b3cb72` contains the test change.
- Validation of this new case is **PENDING** until the dedicated branch's next QIMA CI run completes. The previously completed 436-test run does not include this newly added case.


## HTTP 503 diagnostic-boundary closeout — 2026-11-27

- The previous branch HEAD `9d099db80a8cb288b573584aa2fb34969d411ce7` was validated by QIMA CI [#45904998333](https://github.com/meridane/QimaTrade-MVP/actions/runs/45904998333): **SUCCESS**. The Verify job reported **437 Playwright tests passed (34.9 s)**; the log explicitly shows the new synthetic upstream-503/no-retry/no-redirect case passing. PostgreSQL 16 and PostgreSQL 17.6 jobs both completed **SUCCESS**. CodeQL [#45904998270](https://github.com/meridane/QimaTrade-MVP/actions/runs/45904998270) completed **SUCCESS**.
- The Vercel status for this branch remains failed by the provider's deployment quota (`api-deployments-free-per-day`); this is separate from GitHub Actions validation.
- Added two further assertions to the HTTP 503 test: the public runtime error message must not contain the fixture's synthetic `details` or `hint` values. This complements the existing HTTP 400 diagnostic-boundary assertions.
- The additional assertions are a synthetic contract check only. They do not establish a live upstream disclosure or Production vulnerability. A new CI run is required before marking this follow-up validated.


## Preview status precision — 2026-11-27

- The provider quota failure described above belongs to the earlier code/test branch snapshot `9d099db80a8cb288b573584aa2fb34969d411ce7`.
- After the follow-up test and documentation commits, latest branch HEAD is `50adde999fe25d85da9b554baeabdfd2b83835af`; its Vercel status is **PENDING**, and its QIMA CI [#45913960558](https://github.com/meridane/QimaTrade-MVP/actions/runs/45913960558) and CodeQL [#45913960548](https://github.com/meridane/QimaTrade-MVP/actions/runs/45913960548) are **IN PROGRESS** at the time of this update.
