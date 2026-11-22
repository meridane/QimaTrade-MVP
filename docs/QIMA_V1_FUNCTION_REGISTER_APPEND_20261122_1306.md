# QIMA V1 function register — supplement 2026-11-22 13:06 KST

This append-only supplement records the current Auth status-contract regression and the dependency-maintenance evidence. The canonical register `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested through GitHub's file reader in UTF-8, base64, and a small line range; each read returned an empty content string with blob SHA `ad8d397dc1343b94c5cec90609b03f82b89cb52b`. It was not replaced because its full contents could not be recovered safely.

## State read before this change

- Pull request #26 is **OPEN** according to the issue endpoint. The PR search result identifies the title `fix: align CREATE_OFFER execution statuses`; current mergeability and draft flags are not exposed by the read response.
- Head before this run: `cfc30da4d8d3817f4c7fb2bb1e10123da628b505`.
- Compare `main...fix/create-offer-status-contract`: **2,246 ahead / 0 behind** before this run.
- The current route has a closed Auth rejection allowlist: only HTTP 400, 401, and 403 map to the public unauthenticated response; unknown upstream statuses map to `AUTH_SERVICE_UNAVAILABLE` (503).
- The existing regression matrix covered 404, 408, 429, 500, 501, 502, 503, 504, 505, 599, and a transport exception.

## Baseline validation on the previous HEAD

- QIMA CI [#1797](https://github.com/meridane/QimaTrade-MVP/actions/runs/44977234463): **SUCCESS**. Verify job: npm audit, TypeScript, Next.js build, Chromium, QIMA fixture, and **409/409 Playwright** passed (37.6 s). PostgreSQL 16 and PostgreSQL 17.6 integration jobs both **SUCCESS**.
- CodeQL [#1726](https://github.com/meridane/QimaTrade-MVP/actions/runs/44977234430): **SUCCESS**.
- Vercel Preview status on that HEAD: **SUCCESS**.
- The setup-failure and cleanup-failure harness jobs intentionally conclude `failure`; their control/restore assertions pass. The intentionally skipped harness remains `skipped`. These are expected harness outcomes, not unexpected CI failures.

## Regression added in this run

- Commit: `78dd09aa48bfc06203813d1c4d41211f843912c6`.
- File: `tests/e2e/create-offer-route-contract.spec.ts`.
- Added HTTP 422 to the existing parameterized non-credential Auth upstream failure matrix.
- Expected contract remains HTTP 503 with `{ error: "AUTH_SERVICE_UNAVAILABLE" }`, no `WWW-Authenticate` challenge, no private message disclosure, and no downstream profile, membership, or RPC access.
- This adds one matrix fixture inside an existing Playwright test; it does not add a new top-level test.

## Checks on the test commit

- QIMA CI [#1798](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702551): **IN PROGRESS** at the last check. The Verify job was in Next.js build; PostgreSQL 16 and 17.6 integration jobs were in progress. The new 422 case has no final Playwright result yet.
- CodeQL [#1727](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702482): **IN PROGRESS**.
- Vercel Preview: **SUCCESS**.
- No failed test is attributed to the new case at this snapshot.

## Dependency audit follow-up — Next.js 15.5.28

- `package.json` allows `^15.5.0`; `package-lock.json` currently resolves `next` to **15.5.28**.
- The archived npm audit JSON from CI #1797 reports one moderate `next` finding containing three advisories: GHSA-7qx7-33qx-rqx2, GHSA-f3mh-rxg3-f5g2, and GHSA-pc58-hwjq-p385. The audit reports `fixAvailable: true`.
- The official GitHub advisories now list **15.5.29** as patched for all three advisories: [GHSA-7qx7-33qx-rqx2](https://github.com/vercel/next.js/security/advisories/GHSA-7qx7-33qx-rqx2), [GHSA-f3mh-rxg3-f5g2](https://github.com/vercel/next.js/security/advisories/GHSA-f3mh-rxg3-f5g2), and [GHSA-pc58-hwjq-p385](https://github.com/vercel/next.js/security/advisories/GHSA-pc58-hwjq-p385). The [15.5.29 release](https://github.com/vercel/next.js/releases/tag/v15.5.29) lists these security fixes.
- Applicability remains configuration-dependent: the advisories describe self-hosted image optimization, Edge-runtime cookie-setting routes, and self-hosted response forwarding behind a pipelining HTTP/1.1 reverse proxy. The audit result alone does not prove that QimaTrade is exploitable.
- A local `npm view next@15.5.29` metadata request timed out after 120 seconds. No package or lockfile was changed; no integrity hash was fabricated. Regenerate the lockfile on a runner with working registry access, then run `npm ci`, `npm audit`, TypeScript, build, and the full CI suite before accepting the dependency update.

## Safety scope

No Supabase Production data, migration, secret, grant, or persistent RLS policy was changed. No Production deployment, PR merge, force-push, or branch-protection change was performed. The Auth fixtures are synthetic contract tests and do not establish a Production vulnerability.


## Post-publication status snapshot — 22 November 2026, 13:08 KST

- Test commit `78dd09aa48bfc06203813d1c4d41211f843912c6`: CodeQL [#1727](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702482) **SUCCESS**; QIMA CI [#1798](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702551) remains **IN PROGRESS**. At this check, Playwright browser tests were still running; PostgreSQL 16 and 17.6 jobs were at their final runner-privilege / legacy RLS checks. No final Playwright or PostgreSQL conclusion is attributed to the 422 fixture yet.
- Documentation HEAD `933997d04cf715f293365207da4ab86c6d23110a`: CodeQL [#1728](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983808892) **IN PROGRESS**; QIMA CI [#1799](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983808859) **PENDING**; Vercel Preview **PENDING**.
- The PR remains **OPEN**. Compare `main...fix/create-offer-status-contract` reports **2,248 ahead / 0 behind**. The work branch and PR branch compare as **identical (0 ahead / 0 behind)**.
- The canonical register remained unreadable through the connector (empty content for UTF-8, base64, and a 20-line range); this supplement is the safely readable append-only record. No attempt was made to overwrite the canonical file.


## Verify completion and current HEAD — 22 November 2026, 13:10 KST

- QIMA CI [#1798](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702551) Verify job is **SUCCESS**: npm audit, TypeScript, Next.js build, Chromium, QIMA security-contract fixture, and **409/409 Playwright passed (38.5 s)**. The existing parameterized Auth status test passed with HTTP 422 included.
- CI #1798 PostgreSQL 16 and PostgreSQL 17.6 jobs remain **IN PROGRESS**. No final PostgreSQL conclusion is claimed. The two expected setup/cleanup simulation jobs conclude `failure` with their assertions/restoration successful; the intentionally skipped harness remains `skipped`.
- CodeQL [#1727](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702482) on the test commit: **SUCCESS**.
- Current documentation HEAD `7191361953bd67fb1d0ddf1fcc6e20e8cbc8ee7f`: QIMA CI [#1800](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983876054) **PENDING**, CodeQL [#1729](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983876006) **IN PROGRESS**, and Vercel Preview **PENDING**.
- The work branch and PR branch remain identical; compare `main...fix/create-offer-status-contract` is **2,249 ahead / 0 behind**. PR #26 remains **OPEN**.


## Final post-push snapshot — 22 November 2026, 13:12 KST

- PR #26 remains **OPEN**. Current PR branch HEAD before this snapshot: `de1f76bc219f832056aeb19289971a8a139d77ca`; compare `main...fix/create-offer-status-contract`: **2,250 ahead / 0 behind**.
- On the Auth 422 test commit `78dd09aa`, CI #1798 Verify remains **SUCCESS** with 409/409 Playwright; PostgreSQL 16 and 17.6 jobs are still **IN PROGRESS** at runner write-privilege characterization. No final PostgreSQL result is claimed.
- The intermediate documentation-only CI #1800 on parent HEAD `71913619` was **CANCELLED** before jobs were published when a newer documentation commit arrived; no test outcome is attributed to it.
- On HEAD `de1f76bc`, QIMA CI [#1801](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983908834) is **PENDING**, CodeQL [#1730](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983908835) is **IN PROGRESS**, and Vercel Preview reports `build-rate-limit` / `api-deployments-free-per-day`. This is a Preview quota failure, not a confirmed Next.js build failure.
- The canonical register read limitation remains: UTF-8, base64, and a small line-range read returned empty content. This companion supplement is retained instead of overwriting the unreadable canonical file.


## Follow-up regression and live CI state — 22 November 2026, 13:14 KST

- Baseline PR #26 was re-read from GitHub before this change: **OPEN / DRAFT / not merged**, `mergeable=true`; branch `fix/create-offer-status-contract`, base `main`, HEAD `7ef0e6f2e54fd9a5754ee6abb735c162db022464`, **2,251 ahead / 0 behind**, 286 changed files (+90,112 / -264). No PR review submissions or inline review threads were returned.
- Latest PR commit `7ef0e6f2` is documentation-only. Its parent `de1f76bc` records Verify #1798; the test commit is `78dd09aa`.
- Added synthetic HTTP **499** to the existing non-credential Auth upstream failure matrix in `tests/e2e/create-offer-route-contract.spec.ts`. The existing assertions require HTTP 503 with `AUTH_SERVICE_UNAVAILABLE`, no `WWW-Authenticate` challenge, no private upstream detail disclosure, and no downstream profile, membership, or RPC calls. No application code or SQL was changed.
- Work-branch test commit: `a5689d15cd4ae413ffb28657d052b22e18a8f0c9`. The commit is on the isolated work branch at this snapshot; no CI result is attributed to it before synchronization to the PR branch.
- CI #1798 Verify is **SUCCESS**: npm audit, TypeScript, Next.js build, Chromium, QIMA fixture, and **409/409 Playwright passed**. PostgreSQL 16 remains at “Characterize full CREATE_OFFER runner write privileges” (step 26, **IN PROGRESS**); PostgreSQL 17.6 has advanced to “Run CREATE_OFFER wrapper-owner and membership regressions on PostgreSQL 17” (step 29, **IN PROGRESS**). No final PostgreSQL result is claimed.
- CodeQL #1727 is **SUCCESS**. On documentation HEAD `7ef0e6f2`, QIMA CI #1802 is **PENDING** with no jobs published at the last read; CodeQL #1731 is **SUCCESS**.
- Vercel Preview reports `build-rate-limit` / `api-deployments-free-per-day`; this is a Preview quota failure, not evidence of a failed application build.
- The canonical register fetch still returns an empty payload for UTF-8, base64, and a 1–30 line range despite a valid blob SHA. The existing append-only register is therefore extended rather than replacing unreadable canonical content.
- No Supabase Production data or migrations, secrets, grants, or persistent RLS policies were touched. No Production deployment, merge, force-push, or branch-protection change was made. Synthetic HTTP fixtures do not establish a Production vulnerability.


## Post-push validation update — 22 November 2026, 13:15 KST

- The isolated work branch was fast-forwarded to `fix/create-offer-status-contract` with expected old HEAD `7ef0e6f2`; the update used `force=false`. The test commit `a5689d15` and this documentation commit are now on the PR branch. Work branch and PR branch compare **0 ahead / 0 behind**.
- QIMA CI [#1798](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702551) has now completed **SUCCESS**. Verify passed with **409/409 Playwright**, npm audit, TypeScript, Next.js build, Chromium, and the isolated QIMA fixture. PostgreSQL 16 and PostgreSQL 17.6 integration jobs both completed **SUCCESS**; the previously active runner-privilege characterization and subsequent legacy-offer RLS, wrapper-owner/membership, function ACL, and participant self-enrollment steps all completed successfully.
- The two prepared-transaction setup/cleanup simulation jobs retain their intentionally negative `failure` conclusions; their assertion jobs passed. The intentionally skipped harness remains `skipped`. These expected harness outcomes do not change the overall CI #1798 **SUCCESS** conclusion.
- CodeQL [#1727](https://github.com/meridane/QimaTrade-MVP/actions/runs/44983702482) completed **SUCCESS**.
- On new PR HEAD `9e4695bcdad9049603462aabf91387eb874144aa`, QIMA CI [#1803](https://github.com/meridane/QimaTrade-MVP/actions/runs/44984298750) is **PENDING** with no jobs published at the last check; CodeQL [#1732](https://github.com/meridane/QimaTrade-MVP/actions/runs/44984298758) is **IN PROGRESS**. The new HTTP 499 fixture has no Playwright result yet.
- Vercel's combined status remains **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`, a Preview quota limit rather than a confirmed build failure.
- PR #26 remains **OPEN / DRAFT / not merged**; GitHub recalculated `mergeable=false` immediately after the push. This is a transient post-push mergeability value, not a merge action or a conclusion that the PR is merged.
- The canonical register remains unreadable through UTF-8, base64, and line-range fetches. This append-only companion is the verified record; no replacement of the canonical file was attempted.


## CI cancellation reconciliation and next boundary case — 22 November 2026, 13:16 KST

- Follow-up check for test commit `a5689d15`: QIMA CI [#1803](https://github.com/meridane/QimaTrade-MVP/actions/runs/44984298750) is **CANCELLED** before any jobs were published. No Playwright result is attributed to HTTP 499. CodeQL [#1732](https://github.com/meridane/QimaTrade-MVP/actions/runs/44984298758) has completed **SUCCESS**.
- The preceding baseline CI #1798 is fully closed **SUCCESS**, including Verify **409/409 Playwright**, PostgreSQL 16 and PostgreSQL 17.6. CodeQL #1727 is **SUCCESS**.
- To make the next non-credential boundary explicit in the same parameterized contract test, added synthetic HTTP **451** (Unavailable For Legal Reasons) alongside 499 in `tests/e2e/create-offer-route-contract.spec.ts`. Both must map to HTTP 503 `AUTH_SERVICE_UNAVAILABLE`, with no `WWW-Authenticate` challenge, no upstream detail disclosure, and no downstream profile, membership, or RPC calls. Application code is unchanged.
- New isolated work-branch test commit: `3139b426838c976386bc26da9be76a6c68ec7efd`. The 451 and 499 cases remain **unvalidated by Playwright** until a non-cancelled QIMA CI run executes on the synchronized code commit.
- The last PR HEAD before this work was `a7a0040dfde55454ed9d6a7d865920e25eae6c01`, **OPEN / DRAFT / not merged**, `mergeable=true`, **2,254 ahead / 0 behind**. The preceding work branch was synchronized with the PR branch.
- Vercel combined status continues to report `build-rate-limit` / `api-deployments-free-per-day`; this remains a Preview quota issue, not a confirmed build failure.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` still returns an empty content payload despite a valid blob SHA. This append-only file remains the safely readable register supplement; the canonical file was not overwritten.
- No Supabase Production data, migrations, secrets, grants, or persistent RLS policies were changed. No Production deployment, merge, force-push, or branch-protection change was made. These synthetic HTTP cases do not establish a Production vulnerability.
