# QIMA V1 Function Register — QA477 closeout and coverage review

**Snapshot:** 26 November 2026, 15:25 KST  
**Repository:** `meridane/QimaTrade-MVP`  
**Pull request:** [#26 — fix: align CREATE_OFFER execution statuses](https://github.com/meridane/QimaTrade-MVP/pull/26)  
**Target branch:** `fix/create-offer-status-contract`  
**Verified parent HEAD:** `15ab4d5f5fe659a82ab41a39c4818cbd8611f080`

## QA477 — final validation

The regression `legacy offers route fails closed when the profile lookup returns an error alongside a profile row` is present in `tests/e2e/legacy-offers-route-contract.spec.ts`.

The test supplies a synthetic non-null profile row and a simultaneous profile lookup error. It verifies HTTP 403 with the existing generic profile-linking message, no redirect, no demand or Product Master reads, and no offer insertion. The internal synthetic detail is not returned to the caller.

This is a defensive precedence test for the existing `profileError || !profile?.actor_id` guard. The combined row-plus-error fixture is synthetic; it does not assert that PostgREST normally returns both values.

### Evidence from GitHub Actions

- QIMA CI [#2002](https://github.com/meridane/QimaTrade-MVP/actions/runs/45762199996): **SUCCESS**.
- Verify job: **432 Playwright tests passed (37.6 s)**. The log explicitly records QA477 as passed.
- npm audit, TypeScript, Next.js production build, Chromium installation, isolated QIMA security fixture, PostgreSQL 16, PostgreSQL 17.6, and prepared-transaction cleanup assertions: **SUCCESS**.
- CodeQL [#1928](https://github.com/meridane/QimaTrade-MVP/actions/runs/45762200108): **SUCCESS**.
- Vercel Preview status for parent HEAD `15ab4d5f`: **SUCCESS** ([deployment](https://vercel.com/bmk1/qimatrade-mvp/Fz5N8ybSj4ucGKLJaY7YEardDW6y)).

The workflow also contains intentional setup/cleanup failure fixtures. Their job conclusions are expected to be negative; their dedicated assertions passed, and the overall CI run is successful. They are not regressions in the application tests.

## Coverage review — avoid duplicate QA478

The legacy route contract spec currently contains 138 Playwright tests. Review of its existing cases found that adjacent error-plus-row precedence is already covered:

- Demand lookup: `legacy offers route stops when the first duplicated demandId lookup errors and ignores a valid reference that follows` supplies both a non-null demand row and `demandError`, then asserts no Product Master read or offer insert.
- Product Master lookup: `legacy offers route rejects a demand-scope product lookup error even when the mock also returns a product row` supplies both a product row and `productMasterError`, then asserts no offer insert.
- Profile lookup: QA477 adds the corresponding profile case.

A second synthetic test for the same demand precedence would duplicate existing coverage rather than close a distinct gap. No new test or application-code change is made in this closeout.

The primary CREATE_OFFER route contract spec currently contains 93 tests. Its profile and membership failure cases exercise non-success HTTP responses through the Supabase client. A simultaneous transport-level PostgREST data-plus-error result is not directly representable by the current HTTP fixture, so no artificial claim is made that this case was tested there.

## Next priority

Continue with a focused review of the primary CREATE_OFFER route's public error mapping and action-runtime status normalization against the SQL contract. Reuse the existing allowlist-alignment test and add coverage only if a genuinely distinct, reproducible gap is found. Do not change numeric canonicalization, idempotency semantics, or other business rules without explicit approval.

## Safety

- No Supabase Production data, migrations, schema, grants, RLS policies, secrets, or persistent configuration were changed.
- No Production deployment, merge, force-push, or branch-protection change was performed.
- This closeout records synthetic route-contract tests and CI evidence; it does not establish a production vulnerability.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` blob is `154cbadc87aad8a6d5753ef30cd9fce5a0416bac`. GitHub's file reader returned an empty body for both full-file and ranged reads of this large file. It was therefore left untouched rather than replaced without its complete contents. This append-only closeout is kept as a companion record until a safe full-content read is available.
