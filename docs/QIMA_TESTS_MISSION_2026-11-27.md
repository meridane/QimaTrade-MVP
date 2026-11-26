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
