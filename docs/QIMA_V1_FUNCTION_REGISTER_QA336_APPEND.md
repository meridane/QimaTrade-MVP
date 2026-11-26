# QIMA V1 Function Register — QA336 append-only record

Date: 2026-11-11
Repository: `meridane/QimaTrade-MVP`
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Target branch: `fix/create-offer-status-contract`
Work branch: `work/qa336-legacy-offer-submit-e2e-20261111-1548`

## Starting-state inspection

- PR #26 was open, draft, unmerged, and mergeable at the start of this run.
- Starting HEAD: `16bc92908ffe84af919afdc94d5ac7da735bd2e1`.
- Initial comparison against `main`: 1,381 commits ahead, zero behind.
- Initial PR file count: 87.
- Previous checks on the starting HEAD: QIMA CI #1208 [run 42966020974](https://github.com/meridane/QimaTrade-MVP/actions/runs/42966020974) **SUCCESS**; CodeQL #1159 [run 42966020975](https://github.com/meridane/QimaTrade-MVP/actions/runs/42966020975) **SUCCESS**.
- Initial Vercel status was pending; subsequent Preview status for the new code HEAD returned the free-plan `build-rate-limit` failure.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested at the target branch. The connector returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but no file content (zero characters). Its history was therefore not overwritten or reconstructed. This QA record is an additive companion.

## QA336 — authenticated independent-draft submission

### Purpose

Complete the browser path left open by QA335: authenticate a synthetic supplier, submit the actual `/offers/new` HTML form, execute `POST /api/offers`, observe the HTTP 303 response, follow the `created` redirect, and inspect the synthetic PostgREST insertion.

### Changes

1. `tests/fixtures/mock-supabase-auth-server.mjs`
   - Retains the existing synthetic PKCE exchange and authenticated `GET /auth/v1/user`.
   - Adds a narrow `GET /rest/v1/profiles` response for the single synthetic user and actor.
   - Adds `POST /rest/v1/offers` to record the submitted JSON and respond with a PostgREST-style 201 empty response.
   - Records content type, Prefer header, and whether the synthetic bearer token was valid.
   - Restricts inspection to an exact offer-name query; missing name is rejected.
   - Adds a test-only DELETE endpoint that clears only rows matching the supplied offer name.
   - Unknown routes and unknown tokens remain rejected.

2. `tests/e2e/offer-creation-confirmation.spec.ts`
   - Adds a browser test that obtains a session through the existing PKCE callback fixture.
   - Opens the authenticated independent draft form, fills offer name and quantity, and selects South Korea for market and geography.
   - Submits the real browser form and captures the `POST /api/offers` response.
   - Asserts HTTP 303 and the `/offers/new?created=<uuid>` destination.
   - Verifies the confirmation status and displayed reference in the browser.
   - Reads the synthetic PostgREST inspection endpoint and checks the exact inserted payload: generated id, authenticated profile actor, quantity, null price/currency for an unpriced draft, market, geography, empty attributes, incomplete documentation status, `lifecycle: draft`, `offer_type: supplier_offer`, and null demand/Product Master associations.
   - Rejects `Prefer: return=representation`. The current Supabase client omits an explicit Prefer header for this insert; the test correctly accepts that absence because PostgREST defaults to a minimal response. It does not require a literal `return=minimal` header.
   - Uses a retry-specific offer name and clears only that name before the test, preventing stale in-memory records from contaminating a Playwright retry.
   - Uses URL predicates rather than hand-escaped regular expressions for navigation assertions.

### Validation history

- **QIMA CI #1209** [run 42975337522](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975337522), code HEAD `3bcb5cc6d871f031bc6e8b4ef0b845bfbb496420`: **FAILURE** in TypeScript parsing. The first authored version over-escaped URL regular expressions. PostgreSQL jobs were still running when this attempt was superseded. **CodeQL #1160** [run 42975337648](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975337648): **SUCCESS**.
- **QIMA CI #1210** [run 42975565769](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975565769), code HEAD `fc4106220254b56714ba4bf7e2fd25c01201bb77`: **FAILURE** in the browser job, with **341 passed and 1 failed**. TypeScript, npm audit, Next.js build, PostgreSQL 16, and PostgreSQL 17.6 jobs succeeded. The full POST, synthetic insert, 303 redirect, and confirmation had succeeded; the remaining assertion incorrectly required an explicit `Prefer: return=minimal` header. The observed header was absent. This was an incorrect test assumption, not an application or database security finding. **CodeQL #1161** [run 42975565740](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975565740): **SUCCESS**.
- **QIMA CI #1211** [run 42975658451](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975658451), intermediate code HEAD `443a7190ec29758c632216918f5cbcf218c3df12`: **CANCELLED** after a newer commit superseded it. No job result is claimed for this run. **CodeQL #1162** [run 42975658679](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975658679): **SUCCESS** on the intermediate HEAD; final validation remains CodeQL #1163 on the final code HEAD.
- **Final code HEAD:** `d684524e2809f18a5eb8ac72703a35e09a718548`.
- **QIMA CI #1212** [run 42975747813](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975747813): **SUCCESS, 3/3 jobs**. The browser job passed **342/342 Playwright tests**, including the full authenticated draft submission. npm audit reported zero advisories at the configured threshold, TypeScript passed, Next.js production build passed, and Chromium installation passed. PostgreSQL 16 integration/cleanup and PostgreSQL 17.6 compatibility jobs both passed; the PostgreSQL 17.6 version assertion succeeded.
- **CodeQL #1163** [run 42975747819](https://github.com/meridane/QimaTrade-MVP/actions/runs/42975747819): **SUCCESS**.
- QIMA CI #1212 and CodeQL #1163 validate code HEAD `d684524e2809f18a5eb8ac72703a35e09a718548`. After the QA336 documentation commits, GitHub also ran QIMA CI #1213 [run 42976124101](https://github.com/meridane/QimaTrade-MVP/actions/runs/42976124101) and CodeQL #1164 [run 42976124087](https://github.com/meridane/QimaTrade-MVP/actions/runs/42976124087) on final documentation HEAD `3ec44c0b554b97b12dae2348e653491e5780fb59`: **CI SUCCESS, 3/3 jobs, 342/342 Playwright; CodeQL SUCCESS**. The PR-level workflows evaluated the full PR diff, which still includes source files; do not assume `paths-ignore: docs/**` suppresses validation when the pull request as a whole also contains non-documentation changes.

### Final PR snapshot before documentation-only commits

- PR #26 remained **OPEN**, **DRAFT**, **UNMERGED**, and **MERGEABLE**.
- Code HEAD: `d684524e2809f18a5eb8ac72703a35e09a718548`.
- Comparison against `main`: 1,389 commits ahead, zero behind.
- PR file count: 88.
- Vercel combined status: **FAILURE**, target `build-rate-limit` (Preview quota). This is separate from successful GitHub Actions and CodeQL. No quota bypass or Production deployment was attempted.

### Interpretation and safety boundary

This is an end-to-end browser test against a synthetic local Auth/PostgREST service. It verifies the application's form submission, actor lookup, insert payload, HTTP redirect, and confirmation rendering. It does **not** establish live Supabase RLS behavior, real Production row persistence, offer ownership, or provider-to-demand eligibility. No vulnerability is inferred from this synthetic fixture.

No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change was performed.
