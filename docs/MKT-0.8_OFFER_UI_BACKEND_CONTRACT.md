# QIMA MKT-0.8 — Offer UI-to-backend contract map

Date: 2026-10-28
Branch: `fix/create-offer-status-contract`
Scope: source review only; no database or production changes.

## UI entry points confirmed

### A. Independent supplier offer draft
- UI: `app/offers/new/page.tsx`
- Form action: `POST /api/offers`
- Backend: `app/api/offers/route.ts`
- Behavior visible in source: no demand ID is required; price is optional; created row is assigned `lifecycle: "draft"`; success redirects to `/offers/new?created=<id>`; the authenticated confirmation route accepts only a valid UUID v4 reference.
- This is a draft-first supplier flow and is not equivalent to a demand response.

### B. Offer against a buyer demand
- UI: `app/offers/page.tsx`
- Server action: `createOffer` in `app/offers/actions.ts`
- Runtime: `lib/actions/runtime.ts`
- RPC: `execute_create_offer_v1`
- Behavior visible in source: a demand ID and a Product Master linked in demand scope are required; a single tenant membership is required; creation is submitted through universal action runtime.

## Contract mismatch requiring a decision

The demand-specific UI makes price optional. In `app/offers/actions.ts`, an empty price is converted to `null`, but the universal action input then sends `price: price ?? 0` and `currency: price === null ? "USD" : currency`. In `app/api/actions/create-offer/route.ts`, the input is converted with `Number(body.price)`; an omitted price becomes `NaN`. These are three different representations of an optional price.

This should be resolved explicitly before consolidating routes:
1. Is price optional for a demand response, or only for a draft?
2. If optional, should the database store NULL or a separate “price pending” state? Zero must not silently mean unknown price.
3. Should the universal route reject missing/invalid price or normalize it to the agreed representation?
4. Should the independent draft route remain supported, or be retired after its UI and lifecycle are migrated?

## Authorization still unresolved

Both routes derive the provider actor from the authenticated profile, which is good. The source read did not establish a complete server-side invariant tying the demand to the selected tenant and confirming the provider may respond to that demand. Reads of a demand alone do not prove eligibility. RLS metadata also does not answer the full business ownership question.

## Safe next actions

- Agree the price/draft contract and provider-to-demand eligibility rule.
- Add tests for missing price, zero price, malformed price, wrong tenant, unrelated provider, and cross-user demand IDs.
- Exercise tests in isolated development/test data before any schema or policy change.
- Only then consolidate the API paths and update the function register.

## Safety boundary

This document records source findings, not confirmed exploitability. No production writes, SQL migrations, RLS changes, merge, or production deployment occurred.

## QA334 — independent draft confirmation landing

- The legacy draft endpoint now redirects to `/offers/new?created=<uuid>` after a successful plain INSERT. It no longer sends the independent draft flow to `/offers`, which is the separate demand-response form.
- `app/offers/new/page.tsx` reads the first `created` query value through `getCreatedOfferId` and displays an accessible confirmation/reference panel only for a canonical UUID v4.
- The confirmation page offers a clean `/offers/new` link to start another draft; its click handler clears the current confirmation state before navigation so the form is available again.
- The query value is presentation-only. It is not an ownership check, database read, or proof that a caller visiting a manually constructed URL owns an offer. The POST handler's successful INSERT is the source of the redirect in the normal flow.
- Regression coverage updates the route's exact Location assertion and tests valid, missing, malformed, and duplicated `created` query values. The duplicate test preserves URLSearchParams first-value semantics.
- **QIMA CI #1201** ([run 42961382981](https://github.com/meridane/QimaTrade-MVP/actions/runs/42961382981)) — **SUCCESS, 3/3 jobs** on code commit `f1acd444f5c43b87fe7ee6656b905eff9c9ca313`; Playwright **338/338**, TypeScript, npm audit, Next.js build, PostgreSQL 16 and PostgreSQL 17.6 checks passed.
- **CodeQL #1152** ([run 42961382979](https://github.com/meridane/QimaTrade-MVP/actions/runs/42961382979)) — **SUCCESS**.
- Final code HEAD `e7b5dda97606bfd33517b6999e62de4dd1ac5d55`: **QIMA CI #1202** ([run 42961575562](https://github.com/meridane/QimaTrade-MVP/actions/runs/42961575562)) — **SUCCESS, 3/3 jobs**; Playwright **338/338**, PostgreSQL 16 and 17.6 checks, TypeScript, npm audit, and Next.js build passed. **CodeQL #1153** ([run 42961575549](https://github.com/meridane/QimaTrade-MVP/actions/runs/42961575549)) — **SUCCESS**.
- Vercel combined status remains a Preview quota failure (`build-rate-limit`); it is separate from successful GitHub Actions/CodeQL validation. No Production deployment was attempted.
- The same final evidence and safety boundary are recorded in the QA334 function-register addendum.
- No production database, migration, RLS policy, grant, or deployment was changed.


## QA335 — authenticated draft confirmation middleware guard

- **Starting state:** PR #26 remained open on branch `fix/create-offer-status-contract`; comparison against `main` showed 1,373 commits ahead and zero behind. The previous code HEAD `e7b5dda` had QIMA CI #1202 and CodeQL #1153 successful; the latest documentation HEAD had QIMA CI #1204 and CodeQL #1155 successful. Vercel remained blocked by the free-plan `build-rate-limit` quota.
- **Finding:** the middleware protects `/offers/new` and redirects requests without `productMasterId` to `/decision-tree?flow=supplier`. That guard also intercepted the QA334 success redirect `/offers/new?created=<uuid>`, so the confirmation component could not be reached through the normal authenticated browser path.
- **Fix:** after the existing authentication check, middleware now permits `/offers/new` without `productMasterId` only when `getCreatedOfferId(request.nextUrl.search)` returns a canonical UUID v4. Missing or malformed references continue through the supplier classification redirect. The UUID remains presentation-only; the exception does not perform a database lookup, establish ownership, or bypass authentication.
- **Test fixture:** the isolated Supabase Auth server now implements `GET /auth/v1/user` for the single synthetic access token returned by its existing PKCE callback fixture; all other tokens receive 401. This allows middleware authentication to be exercised in a real Playwright browser context without a live Supabase project.
- **Browser regressions:** (1) a valid confirmation URL remains protected when unauthenticated; (2) an authenticated synthetic supplier sees the confirmation panel and reference without a Product Master query, then the “Create another offer” link re-enters `/decision-tree?flow=supplier`; (3) an authenticated supplier with a malformed reference is still sent to classification. The auth session is installed for both local host aliases used by the test server.
- **First validation:** QIMA CI #1205 (run `42965548409`) completed with the PostgreSQL 16 and 17.6 jobs successful, but the browser job failed in two new navigation assertions. The first confirmed the confirmation page rendered; the failure occurred after the “Create another offer” navigation switched from `127.0.0.1` to `localhost`, where the synthetic cookie had not been installed. The malformed-reference case hit the same host-alias mismatch. Playwright reported 339 passed and 2 failed; this was a test-fixture cookie-domain issue, not a production authorization finding. CodeQL #1156 (run `42965548366`) succeeded.
- **Correction:** the browser fixture now installs the same synthetic session cookie for both `127.0.0.1` and `localhost`. Final CI and CodeQL validation are recorded in the QA335 validation closure below.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.


## QA335 — validation closure (11 November 2026)

- **Corrected code commit:** `1fcd5a3dfc9995ffc049553fcc716d5b3648ea39`.
- **QIMA CI #1206:** run [42965751692](https://github.com/meridane/QimaTrade-MVP/actions/runs/42965751692) — **SUCCESS, 3/3 jobs**. The browser job completed **341 Playwright tests passed, 0 failed**; the three authenticated/malformed-reference confirmation scenarios passed. PostgreSQL 16 integration/cleanup checks and PostgreSQL 17.6 compatibility checks both succeeded. npm ci, npm audit at the high threshold, TypeScript, Next.js production build, and Chromium installation succeeded.
- **CodeQL #1157:** run [42965751595](https://github.com/meridane/QimaTrade-MVP/actions/runs/42965751595) — **SUCCESS**.
- **First-attempt correction record:** CI #1205 [run 42965548409](https://github.com/meridane/QimaTrade-MVP/actions/runs/42965548409) had PostgreSQL 16 and 17.6 jobs succeed but the browser job fail with 339 passed and 2 failed. The first confirmation page rendered; subsequent navigation switched the test host from `127.0.0.1` to `localhost`, and the synthetic cookie had only been installed for the first host. Installing the same synthetic session cookie for both local aliases corrected the test fixture. This was a deterministic test-environment host-alias mismatch, not a production authorization finding. CodeQL #1156 [run 42965548366](https://github.com/meridane/QimaTrade-MVP/actions/runs/42965548366) succeeded.
- **Vercel:** combined status on code HEAD `1fcd5a3` remains **FAILURE** with target `build-rate-limit` (free-plan Preview quota). This is separate from successful GitHub Actions and CodeQL checks; no quota bypass or Production deployment was attempted.
- **Conclusion:** the authenticated confirmation path is now exercised end-to-end against the isolated mock Supabase Auth server. The tests demonstrate route rendering and middleware navigation only; they do not verify offer ownership or any live Supabase policy.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.
