# QIMA V1 Function Register — QA339 append

Date: 2026-11-11
Repository: `meridane/QimaTrade-MVP`
PR: #26 — `fix/create-offer-status-contract`
Scope: authenticated supplier draft submission after a browser-side network interruption, followed by an explicit user retry. The network fault and Auth/PostgREST services are synthetic local test fixtures only.

## Starting-state inspection

- PR #26 was **OPEN**, **DRAFT**, **UNMERGED**, and **MERGEABLE**.
- Starting PR HEAD: `edcc3a36ae98e5ce1c7781907d3ce53c221ce7ab`.
- Comparison with `main`: **1,408 commits ahead**, **0 behind**, **91 changed files**.
- Starting-head **QIMA CI #1228** (run [42986167425](https://github.com/meridane/QimaTrade-MVP/actions/runs/42986167425)) completed **SUCCESS, 3/3 jobs**.
- Starting-head **CodeQL #1179** (run [42986167209](https://github.com/meridane/QimaTrade-MVP/actions/runs/42986167209)) completed **SUCCESS**.
- Starting-head Vercel combined status was **FAILURE**, target `build-rate-limit`; this is separate from GitHub Actions and CodeQL.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was read first through a bounded line request. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but an empty content payload. The canonical file was not overwritten. QA338 history was read from its append-only register.

## QA339 — network interruption and retry

### Change

Only one code/test file changed:

- `tests/e2e/offer-creation-confirmation.spec.ts`

Added an authenticated browser scenario named:

`an authenticated supplier can retry a draft after a browser network interruption without losing form data`

The test:

1. Resets only the exact QA339 offer name in the local synthetic fixture.
2. Authenticates through the existing local OAuth PKCE/Auth test flow.
3. Opens the independent supplier draft form and fills the offer name, quantity, target market, and supplier geography.
4. Installs a one-shot Playwright route for `/api/offers` and aborts the first browser request with `connectionreset`.
5. Waits for the browser `requestfailed` event and verifies the generic retry alert.
6. Verifies that offer name, quantity, market, and geography remain in the form; the submit button is enabled; no success status/reference appears; and the URL remains the unsubmitted form URL.
7. Inspects the synthetic PostgREST fixture and verifies that the interrupted request did not reach the API and created neither an offer row nor an upstream failure record.
8. Removes the one-shot route fault and retries without reloading or re-entering the form.
9. Verifies HTTP 201, a canonical UUID-v4 confirmation, cleared error alert, and exactly one fixture offer with the authenticated provider actor and draft lifecycle.
10. Removes the exact QA339 fixture record after the assertions.

No application code, database migration, RLS policy, grant, or production configuration changed.

### Commit and branch

- Code/test commit: `7a12fb03a9a0bb425396b8d0b8c2242c297cd6f8`.
- Work branch: `work/qa339-network-interruption-retry-20261111-1749`.
- Created from the exact starting PR HEAD above.
- Fast-forwarded to the PR branch with expected HEAD `edcc3a36ae98e5ce1c7781907d3ce53c221ce7ab`; no force update was used.

### Validation

- **QIMA CI #1229** (run [42990339839](https://github.com/meridane/QimaTrade-MVP/actions/runs/42990339839)) on code HEAD `7a12fb03a9a0bb425396b8d0b8c2242c297cd6f8`: **SUCCESS, 3/3 jobs**.
  - Browser/build job: **346 Playwright tests passed, 0 failed**. The new QA339 test passed (logged as test 336 in the interleaved worker output).
  - npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and audit artifact upload succeeded.
  - PostgreSQL 16 CREATE_OFFER integration, RLS, ACL, migration cleanup, prepared-transaction restoration, and participant self-enrollment steps succeeded.
  - PostgreSQL 17.6 compatibility succeeded; the log confirms `server_version_num=170006`, CREATE_OFFER integration, legacy offer RLS, wrapper/membership, and seven-function EXECUTE ACL checks.
- **CodeQL #1180** (run [42990339771](https://github.com/meridane/QimaTrade-MVP/actions/runs/42990339771)) on the same code HEAD: **SUCCESS**.
- Vercel combined status on the code HEAD: **SUCCESS**, Preview deployment [6kfMzduw8CeRp5or1fKYQg9gdwPs](https://vercel.com/bmk1/qimatrade-mvp/6kfMzduw8CeRp5or1fKYQg9gdwPs). Preview only; no Production deployment.
- The browser log also contains an `ECONNRESET: Auth network connection reset` stack trace from a separate existing CREATE_OFFER Auth transport-failure test; that test is reported as passed. It is not a QA339 failure.

### Interpretation and safety boundary

The browser network reset is deliberately synthetic through Playwright routing. The test verifies the client catch path, preservation of form state, absence of a false confirmation, and successful explicit retry against the local synthetic Auth/PostgREST fixture. It does not establish live network reliability, live Supabase persistence, server-side idempotency, or exactly-once behavior under ambiguous timeouts where the server may have committed before the response was lost.

A browser-side aborted request cannot prove what a real upstream server would have done after a mid-flight disconnect. The test intentionally checks that the request never reaches the local synthetic API in this deterministic scenario. A separate server-side idempotency contract remains necessary before claiming duplicate prevention for ambiguous outcomes.

No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change was performed.
