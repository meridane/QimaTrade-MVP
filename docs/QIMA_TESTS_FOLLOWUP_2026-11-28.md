# QIMA TESTS — follow-up 2026-11-28

## Scope and branch
- Branch: `work/qima-tests-publish-runtime-20261127-0441`
- Tested code head: `175ff9f5e7cf324379e76c80830d8cd36b3733f6`
- Mission PR: [#28](https://github.com/meridane/QimaTrade-MVP/pull/28), OPEN / DRAFT.
- Source base: PR #26 HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.

## New regression
- File: `tests/e2e/action-runtime-publish-product-request.spec.ts`.
- Commit: `175ff9f5e7cf324379e76c80830d8cd36b3733f6`.
- A successful HTTP 200 publish RPC response includes the valid `demandId` plus unknown `details`, `hint` and `tenant_id` fields.
- The public ActionResult must contain only the normalized request ID, demand ID and source; the synthetic internal fields must not be propagated.

This complements existing tests for empty HTTP 204, malformed/truncated JSON, 401/403/429/5xx, absent definitions, invalid UUIDs and no-retry behavior.

## Validation
- Previous snapshot `3d3041a3`: QIMA CI [run 46094833714](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094833714) SUCCESS, 461 Playwright tests, PostgreSQL 16 and 17.6 SUCCESS; CodeQL [run 46094833583](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094833583) SUCCESS.
- Current QIMA CI [run 46098391508](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098391508): IN PROGRESS. Verify is still building; PostgreSQL 16 and 17.6 jobs are active. No result is yet claimed for the new unknown-metadata test.
- CodeQL [run 46098391500](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098391500): IN PROGRESS.
- Vercel Preview: PENDING at the latest status read.

## Interpretation
The test checks response normalization and output minimization in a local synthetic HTTP server. It does not prove that a Production endpoint leaked data.

## Next step
Inspect the new test in the Verify log, then wait for PostgreSQL 16/17.6 and CodeQL conclusions.


## Verify closeout update
- Verify job `140834981554` in QIMA CI [run 46098391508](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098391508) completed SUCCESS: npm audit, TypeScript, production build, Chromium and the isolated security fixture passed; Playwright completed **462 tests**.
- The new `PUBLISH_PRODUCT_REQUEST runtime discards unrecognized publish RPC metadata` test is explicitly PASS (5 ms).
- PostgreSQL 16 and 17.6 jobs remained IN PROGRESS at the latest read, so the overall QIMA CI run is not yet closed.
- CodeQL [run 46098391500](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098391500) completed SUCCESS.
- Vercel Preview was PENDING at the latest status read.

 
## Publish RPC 5xx retry boundary — 2026-11-28

- Added parameterized HTTP 500, 502, 503 and 504 cases to tests/e2e/action-runtime-publish-product-request.spec.ts.
- Each case requires a null result, the normalized upstream-unavailable message, no details/hint disclosure, exactly one definition request followed by one publish request, and no redirect/retry.
- Commit: https://github.com/meridane/QimaTrade-MVP/commit/7d61b99f40ad0895c068eabc25d55d17ac30d19b.
- Previous head 175ff9f5 is fully validated by QIMA CI #46098391508: 462 Playwright passed, including the unknown-metadata allowlist regression; Verify succeeded; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 succeeded. CodeQL #46098391500 succeeded.
- New head 7d61b99f has QIMA CI #46106205447 QUEUED and CodeQL #46106205431 IN PROGRESS at this checkpoint. The new 5xx matrix is not yet marked PASS.
- All 5xx responses are synthetic local-server fixtures; this does not establish a Production RPC outage or data exposure.

 
## Publish RPC 5xx matrix — Verify closeout

- New code head 7d61b99f: QIMA CI [#46106205447](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106205447), Verify job 140859414003 **SUCCESS**, **466 Playwright passed**.
- All four new HTTP 500, 502, 503 and 504 publish-RPC cases explicitly passed. Each asserts no retry, no redirect, normalized upstream-unavailable error and no details/hint disclosure.
- TypeScript, dependency audit, production build and isolated QIMA security fixture all passed.
- CodeQL [#46106205431](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106205431) **SUCCESS**.
- PostgreSQL 16 and 17.6 remain IN PROGRESS at full runner write-privilege characterization. Overall QIMA CI is not yet closed.
- The two deliberately failing prepared-transaction harness jobs are expected; their separate blocking assertion jobs passed. The intentionally skipped harness and its assertion also behaved as expected.

 
## External preview

- Vercel Preview for code head 7d61b99f reports SUCCESS.
- QIMA CI overall remains IN PROGRESS only because PostgreSQL 16 and 17.6 runner-write-privilege characterization jobs have not completed yet; Verify and CodeQL are successful.


## Final PostgreSQL and CI closeout — 2026-11-28 14:10 KST

- Final tested code head: `7d61b99f40ad0895c068eabc25d55d17ac30d19b`.
- QIMA CI [#2230](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106205447) is **SUCCESS**. Verify job `140859414003` completed **SUCCESS** with **466 Playwright tests passed**. The four HTTP 500/502/503/504 publish-RPC cases explicitly passed, alongside dependency audit, TypeScript, Next.js production build, Chromium and the isolated QIMA security fixture.
- PostgreSQL 16 job `140859413974` completed **SUCCESS** (48 job steps); PostgreSQL 17.6 job `140859414069` completed **SUCCESS** (33 job steps). No unexpected failed integration step remains.
- CodeQL [#2154](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106205431) is **SUCCESS**. Vercel Preview for code head `7d61b99f` was **SUCCESS**.
- Prepared-transaction failure-injection jobs report their expected negative outcomes; their independent blocking assertions passed. The intentionally skipped harness is also checked by a successful assertion job.
- The later documentation-only branch HEAD `c60850f2` currently has combined Vercel status **FAILURE** with provider target `build-rate-limit`. This is an external preview quota issue, not a failed QIMA CI, PostgreSQL or CodeQL check. The code head above is the validated snapshot.
- These tests use synthetic HTTP responses and verify error normalization, no-retry/no-redirect behavior and output minimization. They do not establish a live Production RPC outage or data leak.
- No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made in this closeout. Documentation only; `[skip ci]` is used because the tested code head is unchanged.
