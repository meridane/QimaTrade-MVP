# QIMA V1 Function Register — QA340 append-only record

Date: 2026-11-11
Repository: `meridane/QimaTrade-MVP`
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Target branch: `fix/create-offer-status-contract`
Work branch: `work/qa340-ambiguous-offer-response-characterization-20261111-1909`

## Starting-state inspection

- PR #26 was **OPEN**, **DRAFT**, **UNMERGED**, and **MERGEABLE** at the start of this run.
- Starting HEAD: `295e8ff404dd3304fb480172a4eb26265cd9afc2`.
- PR snapshot: **1,410 commits ahead**, **0 behind**, **92 changed files**.
- Starting-head **QIMA CI #1230** ([run 42990657824](https://github.com/meridane/QimaTrade-MVP/actions/runs/42990657824)): **SUCCESS, 3/3 jobs**.
- Starting-head **CodeQL #1181** ([run 42990657944](https://github.com/meridane/QimaTrade-MVP/actions/runs/42990657944)): **SUCCESS**.
- Starting-head Vercel combined status: **FAILURE**, target `build-rate-limit`; this is separate from GitHub Actions and CodeQL.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested by bounded line range and by raw-file URL. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` with empty content for the bounded request; the raw fetch rejected the oversized file (HTTP 400). The canonical file was not modified. Existing QA338 and QA339 append-only records were read before work.

## QA340 — characterize a committed INSERT whose browser response is lost

### Change

Only one code/test file changed:

- `tests/e2e/offer-creation-confirmation.spec.ts`

Added the authenticated Playwright scenario:

`characterizes an ambiguous response after the legacy draft INSERT commits before the browser connection is lost`

The test:

1. Clears only the exact QA340 offer name from the local synthetic Auth/PostgREST fixture.
2. Authenticates a supplier through the existing local OAuth PKCE test flow.
3. Opens the independent draft form and fills the offer name, quantity, target market, and supplier geography.
4. Intercepts the first `POST /api/offers` and uses `route.fetch()` to forward it to the real Next.js route and synthetic PostgREST fixture.
5. Records the upstream HTTP 201, then aborts only the browser-facing response with `connectionreset`.
6. Verifies that the browser reports a failed request and displays the generic retry alert, retains all entered fields, leaves the submit button enabled, and does not show a success reference.
7. Inspects the fixture after the lost response and confirms that the first INSERT has already been recorded with a valid UUID and the authenticated provider actor.
8. Removes the browser fault and retries the unchanged form.
9. Verifies a second HTTP 201 and a confirmation reference with a different UUID.
10. Inspects the fixture and confirms that two rows now exist for the same logical form data, with distinct generated offer IDs.
11. Removes only the exact QA340 fixture records.

No mock-server change was necessary: the existing name-scoped inspection and cleanup endpoints were sufficient. No application code, database migration, RLS policy, grant, or production configuration changed.

### Existing idempotency contract review

The current legacy handler in `lib/offers/create-legacy-offer.ts` generates a new `randomUUID()` for each POST and performs a direct `offers` INSERT. It does not accept or persist a stable idempotency key.

The existing `public.execute_create_offer_v1` contract in migration `20261027090000_fix_create_offer_action_status_contract.sql` does implement tenant-scoped idempotency, request hashing, and replay of a completed result. However, it is not directly reusable for the independent legacy draft form as currently defined: it requires a non-null tenant and membership, non-null demand and active Product Master references, a non-null price, a valid currency, and a published CREATE_OFFER action. The independent legacy form intentionally permits `demand_id = NULL`, `product_master_id = NULL`, `price = NULL`, and `currency = NULL`.

Reusing that RPC would therefore change the current independent-draft contract or require a separate database/API contract. No such product or architecture decision was inferred in QA340.

### Commit and branch

- Code/test commit: `b622d0983f8da3c4ebadccf71957455a7f006f13`.
- Work branch: `work/qa340-ambiguous-offer-response-characterization-20261111-1909`.
- Created from the exact starting PR HEAD above.
- Fast-forwarded to the PR branch using expected HEAD `295e8ff404dd3304fb480172a4eb26265cd9afc2`; no force update was used.

### Validation

- **QIMA CI #1231** ([run 43001701472](https://github.com/meridane/QimaTrade-MVP/actions/runs/43001701472)) on code HEAD `b622d0983f8da3c4ebadccf71957455a7f006f13`: **SUCCESS, 3/3 jobs**.
  - Browser/build job: **347 Playwright tests passed, 0 failed**. QA340 passed (logged as test 337 in interleaved worker output).
  - npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and artifact uploads succeeded.
  - PostgreSQL 16 CREATE_OFFER integration, RLS, ACL, migration cleanup, prepared-transaction restoration, and participant self-enrollment steps succeeded.
  - PostgreSQL 17.6 compatibility succeeded; the pinned version guard and CREATE_OFFER integration, legacy-offer RLS, wrapper/membership, and seven-function EXECUTE ACL checks passed.
- **CodeQL #1182** ([run 43001701322](https://github.com/meridane/QimaTrade-MVP/actions/runs/43001701322)): **SUCCESS**.
- Vercel combined status on the code HEAD: **SUCCESS**, Preview [3jLgXPwyYU5n2TkdPXKduM9oZdL6](https://vercel.com/bmk1/qimatrade-mvp/3jLgXPwyYU5n2TkdPXKduM9oZdL6). Preview only; no Production deployment.

### Interpretation and safety boundary

This is a deterministic characterization of the current legacy route using a synthetic local PostgREST service. It proves that this test setup can commit the first INSERT, drop the response before the browser receives it, and then observe the current handler generate a second UUID on explicit retry. It does **not** prove that a duplicate was created in Supabase Production, that a live database accepts both writes, or that a production vulnerability is confirmed.

The test intentionally records the present behavior rather than claiming duplicate prevention. A future idempotency change needs an explicit contract for key scope, payload equivalence/hash, replay response, concurrent requests, retention, and how independent drafts without demand/Product Master/price fit the data model. Until that decision exists, the safe next step is contract design and review, not an unapproved migration or RPC change.

No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change was performed.

## QA340 — documentation-head validation closure

- Append commit before this closure: `48646f70c848474be6dd5a95145a1ec251743397`.
- **QIMA CI #1232** ([run 43002046866](https://github.com/meridane/QimaTrade-MVP/actions/runs/43002046866)) — **SUCCESS, 3/3 jobs** on the preceding documentation HEAD. Browser/build job: **347/347 Playwright tests passed**, including QA340; npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and artifact uploads succeeded. PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs both succeeded.
- **CodeQL #1183** ([run 43002046764](https://github.com/meridane/QimaTrade-MVP/actions/runs/43002046764)) — **SUCCESS**.
- Vercel combined status on that documentation HEAD: **SUCCESS**, Preview [Eqm26fmxAWUkw2F22DGtJsUbF2i9](https://vercel.com/bmk1/qimatrade-mvp/Eqm26fmxAWUkw2F22DGtJsUbF2i9). Preview only; no Production deployment.
- The CI logs include expected SQL errors from deliberate negative wrapper-owner, missing-relation, and prepared-transaction cleanup assertions; all corresponding regression steps and jobs completed successfully. They are not QA340 failures.
- This closure records the preceding append validation. It does not change application code, test behavior, database objects, or deployment configuration.
