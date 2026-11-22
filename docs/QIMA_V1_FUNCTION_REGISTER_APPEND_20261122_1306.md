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
