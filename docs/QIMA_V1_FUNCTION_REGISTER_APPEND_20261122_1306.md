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
