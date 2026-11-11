# QIMA V1 Function Register — QA337 append-only record

Date: 2026-11-11
Repository: `meridane/QimaTrade-MVP`
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Target branch: `fix/create-offer-status-contract`
Work branch: `work/qa337-draft-insert-failure-ux-20261111-1642`

## Starting-state inspection

- PR #26 was **OPEN**, **DRAFT**, **UNMERGED**, and **MERGEABLE** at the start of this run.
- Starting HEAD: `ae5b1c401b54ebcc77117a086888950a0a7c5f46`.
- PR snapshot: 1,393 commits, 89 changed files; base `main`, zero commits behind.
- Starting QIMA CI #1214 ([run 42976379598](https://github.com/meridane/QimaTrade-MVP/actions/runs/42976379598)): **SUCCESS**.
- Starting CodeQL #1165 ([run 42976379605](https://github.com/meridane/QimaTrade-MVP/actions/runs/42976379605)): **SUCCESS**.
- Starting Vercel combined status: **FAILURE**, target `build-rate-limit` (Preview quota).
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was read by path at the target branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but zero content characters. Its history was not overwritten or reconstructed; this record is additive.

## QA337 — independent draft INSERT failure UX

### Finding

The QA336 browser flow used a native HTML form POST and a 303 redirect. QA337 first moved the form to a client-side fetch so that an INSERT error could be shown inline without navigating to a raw JSON error page. The first implementation followed the 303 from fetch, but browser evidence showed the page URL remained at the form. The implementation was changed to an explicit content-negotiated JSON success response.

A second integration issue came from the existing `GlobalActionLoader`: its capture-phase form submit listener starts a full-screen overlay intended for native navigations. That overlay blocked retry clicks after an asynchronous insert failure. The independent draft form now opts out of that global loader and owns its pending state.

### Changes

1. `app/offers/new/page.tsx`
   - Prevents native navigation and submits `FormData` with `Accept: application/json` and same-origin credentials.
   - Disables the submit button and displays `Creating...` while the request is pending.
   - Accepts only a successful JSON response containing a canonical UUID-v4 id, then navigates to `/offers/new?created=<uuid>`.
   - For non-success, malformed success response, or network exception, keeps the form visible and shows one generic retry message.
   - Does not render upstream error details.
   - Adds `data-no-loading="true"` so the global native-submit overlay cannot block the async error/retry path.

2. `lib/offers/create-legacy-offer.ts`
   - Keeps the preassigned UUID and plain INSERT without SELECT/RETURNING.
   - Returns HTTP 201 JSON `{ id }` only when the request Accept header asks for `application/json`.
   - Preserves HTTP 303 redirect behavior for callers that do not request JSON.
   - Continues mapping INSERT failures to the generic `Unable to create the offer.` response.

3. `tests/fixtures/mock-supabase-auth-server.mjs`
   - Adds narrowly scoped synthetic PostgREST failure scenarios for upstream statuses 400, 403, and 500.
   - Records only the synthetic failure name/status/code for test inspection and returns a synthetic internal-detail marker in the upstream response.
   - Does not record a successful offer insert for these failure cases.
   - Keeps the failure-name inspection endpoint scoped to an exact test offer name and clears matching failure records during test cleanup.

4. `tests/e2e/legacy-offers-route-contract.spec.ts`
   - Adds a route-contract test for JSON Accept: HTTP 201, preassigned UUID in JSON, no Location header.
   - Existing no-JSON test continues to assert the HTTP 303 redirect contract.

5. `tests/e2e/offer-creation-confirmation.spec.ts`
   - Updates the successful browser submission to expect HTTP 201 JSON and obtain the created reference from the final browser URL (rather than reading a response body after navigation).
   - Adds one authenticated browser regression that iterates upstream PostgREST 400, 403, and 500.
   - Verifies the form remains visible, the generic alert is shown, the submit button is re-enabled, no `created` reference or success status appears, no synthetic database detail/code is visible, and no offer row is recorded.
   - Asserts that no `aria-busy="true"` global loader overlay remains after a failed submission.

### Validation history and corrections

- **CI #1215** ([run 42981741129](https://github.com/meridane/QimaTrade-MVP/actions/runs/42981741129)), code HEAD `48d463321c5833f6c0d434377e71975b31b3618d`: **FAILURE** in the browser job. The first fixture version over-escaped the retry-number regex, so the synthetic PostgREST failure was not activated; the fetch-follow-redirect approach also did not complete the expected browser URL transition. PostgreSQL 16 and 17.6 jobs passed. **CodeQL #1166** ([run 42981741151](https://github.com/meridane/QimaTrade-MVP/actions/runs/42981741151)): **SUCCESS**.
- **CI #1216** ([run 42981838533](https://github.com/meridane/QimaTrade-MVP/actions/runs/42981838533)), code HEAD `a45844c6e63438120fad7a871fac1e5ee7f353d6`: **FAILURE** in browser assertions. The fixture regex was corrected, but the fetch-follow-redirect path still left the browser on the original form URL; the error test also matched both the inline alert and Next.js route announcer with a non-specific role locator. **CodeQL #1167** ([run 42981838466](https://github.com/meridane/QimaTrade-MVP/actions/runs/42981838466)): **SUCCESS**.
- **CI #1217** ([run 42982109460](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982109460)), code HEAD `8ae72ed525811de8b839322598280c0ede134518`: **FAILURE** in browser tests. The new JSON response path worked, but the test attempted to read a Playwright response body after the browser had navigated away; the error locator also needed to target the inline paragraph specifically. **CodeQL #1168** ([run 42982109637](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982109637)): **SUCCESS**.
- **CI #1218** ([run 42982210130](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982210130)), code HEAD `b6e0d91c092b72287f8bac4928e72c607a4168ef`: **FAILURE** in browser tests. The response-body assertion was still present in that run, and the global form loader intercepted the error test's retry click. **CodeQL #1169** ([run 42982210178](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982210178)): **SUCCESS**.
- **CI #1219** ([run 42982395099](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982395099)), code HEAD `c23b7b32186259785bf41faeded6788f31e94002`: **FAILURE** in the browser error-path test. The success-path test no longer read the response body, but the global loader still blocked the error-path retry. The browser job reported 343 passed and 1 failed. **CodeQL #1170** ([run 42982395174](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982395174)): **SUCCESS**.
- **Correction:** the form now sets `data-no-loading="true"`; its own `isSubmitting` state provides the progress state. The error-path regression explicitly asserts the global `aria-busy` overlay is absent after failure.

### Final code validation

- Final code HEAD: `ae5b1c401b54ebcc77117a086888950a0a7c5f46`.
- **QIMA CI #1220** ([run 42982719211](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982719211)): **SUCCESS, 3/3 jobs**.
  - Browser job: **344 Playwright tests passed, 0 failed**.
  - npm install and npm audit: success.
  - TypeScript: success.
  - Next.js production build: success.
  - Chromium installation: success.
  - PostgreSQL 16 integration job: success.
  - PostgreSQL 17.6 compatibility job: success.
- **CodeQL #1171** ([run 42982718901](https://github.com/meridane/QimaTrade-MVP/actions/runs/42982718901)): **SUCCESS**.
- Vercel Preview combined status on final code HEAD remains **FAILURE**, target `build-rate-limit` (free-plan quota). This is separate from successful GitHub Actions and CodeQL validation. No quota bypass or Production deployment was attempted.

### Interpretation and safety boundary

The 400/403/500 responses are deliberately synthetic PostgREST fixtures. The regression proves that the application handles those simulated upstream failures without displaying a false success or leaking the fixture's internal marker. It does not prove a live Supabase failure, RLS weakness, exploitability, or Production database behavior.

No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change was performed.

## QA337 — documentation-head validation closure

- Documentation commit before this closure: `0afe251519d741f013bd3b4baad9d6faa84fd99e`.
- **QIMA CI #1221** ([run 42983250409](https://github.com/meridane/QimaTrade-MVP/actions/runs/42983250409)) — **SUCCESS, 3/3 jobs** on documentation HEAD `0afe251519d741f013bd3b4baad9d6faa84fd99e`. The browser job passed **344/344 Playwright tests**; npm install, npm audit, TypeScript, Next.js production build, Chromium installation, PostgreSQL 16 integration, and PostgreSQL 17.6 compatibility all succeeded.
- **CodeQL #1172** ([run 42983250426](https://github.com/meridane/QimaTrade-MVP/actions/runs/42983250426)) — **SUCCESS** on the same documentation HEAD.
- Vercel combined status on `0afe251519d741f013bd3b4baad9d6faa84fd99e` remains **FAILURE**, target `build-rate-limit` (Preview quota). No Production deployment or quota bypass was attempted.
- The documentation-only closure below does not change application code or the validated QA337 behavior. The PR-level workflows are still checked after publication because the PR diff contains application and test files as well as documentation.

## QA337 — final documentation-head validation closure

- Documentation commit before this closure: `1734c2091ca090b110837378c996d45495dbf47b`.
- **QIMA CI #1222** ([run 42983515109](https://github.com/meridane/QimaTrade-MVP/actions/runs/42983515109)) — **SUCCESS, 3/3 jobs** on documentation HEAD `1734c2091ca090b110837378c996d45495dbf47b`. The browser job passed **344/344 Playwright tests**; npm install/audit, TypeScript, Next.js production build, Chromium installation, PostgreSQL 16 integration, and PostgreSQL 17.6 compatibility all succeeded.
- **CodeQL #1173** ([run 42983515130](https://github.com/meridane/QimaTrade-MVP/actions/runs/42983515130)) — **SUCCESS** on the same documentation HEAD.
- Vercel combined status on `1734c2091ca090b110837378c996d45495dbf47b` remains **FAILURE**, target `build-rate-limit` (Preview quota). This does not change the GitHub Actions/CodeQL results. No quota bypass or Production deployment was attempted.
- The only change in the following closure commit is this append-only QA record. The application and test files remain those validated by QIMA CI #1220 and revalidated by #1222.

## QA337 — final PR-head validation closure

- Documentation commit before this closure: `5600abe172c33a6a4df9d8ba6eb91ea811d55e8a`.
- **QIMA CI #1223** ([run 42983784537](https://github.com/meridane/QimaTrade-MVP/actions/runs/42983784537)) — **SUCCESS, 3/3 jobs** on documentation HEAD `5600abe172c33a6a4df9d8ba6eb91ea811d55e8a`. The browser job passed **344/344 Playwright tests**; npm install/audit, TypeScript, Next.js production build, Chromium installation, PostgreSQL 16 integration, and PostgreSQL 17.6 compatibility all succeeded.
- **CodeQL #1174** ([run 42983784713](https://github.com/meridane/QimaTrade-MVP/actions/runs/42983784713)) — **SUCCESS** on the same documentation HEAD.
- Vercel combined status remains **FAILURE**, target `build-rate-limit` (Preview quota). It is a separate provider quota status; no quota bypass or Production deployment was attempted.
- This closure changes only the append-only QA337 register record. The code and test implementation is unchanged from the version validated by CI #1220 and revalidated by #1223.

## QA337 — register-closure HEAD validation

- Register commit before this closure: `43bb1a37264aae462bde200eec746e07d01732ef`.
- **QIMA CI #1224** ([run 42984056409](https://github.com/meridane/QimaTrade-MVP/actions/runs/42984056409)) — **SUCCESS, 3/3 jobs** on HEAD `43bb1a37264aae462bde200eec746e07d01732ef`. Browser tests: **344/344 passed**. PostgreSQL 16 integration and PostgreSQL 17.6 compatibility both succeeded; npm install/audit, TypeScript, Next.js production build, and Chromium installation succeeded.
- **CodeQL #1175** ([run 42984056483](https://github.com/meridane/QimaTrade-MVP/actions/runs/42984056483)) — **SUCCESS** on the same HEAD.
- Vercel remains **FAILURE** with the documented Preview quota target `build-rate-limit`; this does not alter the GitHub Actions/CodeQL outcomes.
- This append-only closure records the completed checks for the previous register update. No application, test, database, or deployment change is included.
