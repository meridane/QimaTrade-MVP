# QIMA V1 Function Register — QA338 append

Date: 2026-11-11
Repository: `meridane/QimaTrade-MVP`
PR: #26 — `fix/create-offer-status-contract`
Scope: independent supplier draft retry behavior after one transient PostgREST INSERT failure. Synthetic local test service only.

## Starting-state inspection

- PR #26 was **OPEN**, **DRAFT**, **UNMERGED**, and **MERGEABLE** before this change.
- Starting PR HEAD: `bcaefd7e1a0b1fb52edc830f457d751232e7396b`.
- Comparison with `main`: 1,404 commits ahead, zero behind; PR file count 90.
- Starting-head **QIMA CI #1225** (run `42984396126`) completed **SUCCESS, 3/3 jobs**.
- Starting-head **CodeQL #1176** (run `42984396018`) completed **SUCCESS**.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` fetch returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but no file text through the connector, including a bounded line-range request. Its content was not overwritten. Existing append-only QA337 history was read before work.
- Vercel combined status was **FAILURE** with target `build-rate-limit`; this is separate from GitHub Actions/CodeQL.

## QA338 — retry after a transient draft INSERT failure

### Changes

1. `tests/fixtures/mock-supabase-auth-server.mjs`
   - Adds one narrowly scoped synthetic scenario for an offer name matching `QA338 transient retry retry-<attempt>`.
   - The first matching PostgREST INSERT returns synthetic HTTP 503 and records one `PGRST_QA338` failure.
   - A subsequent request with the same exact offer name proceeds through the normal successful insert path.
   - Existing name-scoped inspection and cleanup endpoints are reused; no unrestricted fixture behavior was added.

2. `tests/e2e/offer-creation-confirmation.spec.ts`
   - Adds an authenticated browser regression that submits the independent draft form.
   - The first request receives the route's generic HTTP 500 response for the synthetic upstream 503.
   - Verifies the generic retry alert, retained offer name and quantity, enabled submit button, unchanged form URL, no success status/reference, no inserted row, and exactly one recorded synthetic failure.
   - Retries without reloading or re-entering the form. The second request succeeds with HTTP 201 and a canonical UUID-v4 confirmation.
   - Verifies exactly one inserted fixture row, the authenticated provider actor, draft lifecycle, cleared alert, and no visible synthetic database marker or PostgREST code.

### Commits

- Fixture behavior: `891dd41806bc06e8a1e08574da8f51768e8336da`.
- Browser regression: `1d167bd8392c63efc02b74caaccfe4535af535b9`.
- Work branch: `work/qa338-draft-retry-after-transient-insert-failure-20261111-1712`.
- The two-file change was fast-forwarded to the PR branch using expected HEAD `bcaefd7e1a0b1fb52edc830f457d751232e7396b`; no force update was used.

### Validation

- **QIMA CI #1226** (run `42985537156`) on code HEAD `1d167bd8392c63efc02b74caaccfe4535af535b9`: **SUCCESS, 3/3 jobs**.
  - Browser job: **345 Playwright tests passed, 0 failed**.
  - npm ci, npm audit enforcement, TypeScript, Next.js production build, and Chromium installation all succeeded.
  - PostgreSQL 16 CREATE_OFFER integration/cleanup job succeeded.
  - PostgreSQL 17.6 compatibility job succeeded, including the exact server-version guard, CREATE_OFFER integration, wrapper-owner, membership, and seven-function EXECUTE ACL regressions.
- **CodeQL #1177** (run `42985537329`) on the same code HEAD: **SUCCESS**.
- Vercel combined status remains **FAILURE**, target `build-rate-limit`. No quota bypass or Production deployment was attempted.

### Interpretation and safety boundary

The upstream 503 and the later success are deliberately synthetic responses from the local Auth/PostgREST test fixture. This verifies client retry UX, form-state retention, response handling, and fixture-level insertion count. It does not establish live Supabase availability, transaction semantics, RLS behavior, Production persistence, or offer idempotency under concurrent/replayed requests. A separate server-side idempotency contract would require a product/technical decision and is not inferred here.

No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change was performed.

## QA338 — register-head validation closure

- Register commit before this closure: `ace9d0274afd224809d438447b611677ed40822a`.
- **QIMA CI #1227** ([run 42985849314](https://github.com/meridane/QimaTrade-MVP/actions/runs/42985849314)) — **SUCCESS, 3/3 jobs** on documentation HEAD `ace9d0274afd224809d438447b611677ed40822a`. Browser tests: **345/345 passed**, including the one-time synthetic 503 followed by a successful retry. npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, PostgreSQL 16 integration, and PostgreSQL 17.6 compatibility all succeeded.
- **CodeQL #1178** ([run 42985849434](https://github.com/meridane/QimaTrade-MVP/actions/runs/42985849434)) — **SUCCESS** on the same HEAD.
- Vercel Preview combined status on `ace9d0274afd224809d438447b611677ed40822a`: **SUCCESS**. This is a Preview only, not a Production deployment.
- This closure records validation of the previous append-only QA338 register commit. It does not change application code, test behavior, database objects, or deployment configuration.
