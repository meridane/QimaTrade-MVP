# QIMA Repair Baseline — 2026-10-22

## Scope and safety

This is a repository-level static review of `main`. No application build, database query, migration, or end-to-end test was executed as part of this review. Findings below are observations to verify, not a claim that production is exploitable.

No Supabase schema or production data was changed. This report is committed to the isolated branch `chore/qima-free-autopilot-review`, not to `main`.

## Confirmed repository observations

### P0 — Main branch is not protected
The GitHub branch API reports `protected: false` for `main`. This means this review did not find branch protection configured. Configure required pull requests and required CI checks before relying on review gates. Repository administration permissions may be required.

### P0 — Dependency installation is not reproducible yet
The root `package.json` exists, but checks for `package-lock.json`, `pnpm-lock.yaml`, and `yarn.lock` on `main` returned 404. The CI workflow currently runs `npm install`, so dependency resolution can drift between runs. Confirm npm is the chosen package manager, then generate and commit a reviewed lockfile and switch CI to `npm ci`.

### P0 — RLS inventory needs table-by-table reconciliation
The existing function register reports 31 tables in `public` with RLS enabled and no declared policies. This is not proof that each table is exposed: grants, views, functions, service-role access and actual call paths must be checked. Do not add permissive policies or delete legacy tables in bulk.

### P0 — Decision Tree route returns raw exception messages
`app/api/decision-tree/answer/route.ts` sends `error.message` back to clients. This can reveal internal database or implementation details. Replace this with a stable public error code/message and keep diagnostic details in server-side logs, without logging secrets or user tokens.

### P0 — Tenant membership selection is ambiguous
`lib/decision-tree/server.ts` resolves membership with `dt_memberships ... .limit(1).maybeSingle()`. `app/api/actions/create-offer/route.ts` does the same when choosing a tenant. If a user belongs to more than one tenant, selecting an arbitrary first membership can resolve the wrong context. Tenant selection must be explicit and authorized against the session/action.

### P0 — Decision Tree server-authority checks still require end-to-end proof
The route validates session ownership and revision before calling `dt_submit_answer`; the migration `20260901090000_security_gate_dt_v1.sql` derives the target node from stored rules. However, the full flow still needs tests for tenant boundaries, wrong tree/version, non-member access, replay/idempotency, immutable history, and all database grants/policies.

## Existing checks and limits

- `package.json` defines `typecheck` and `build` only indirectly through scripts; the current CI workflow runs installation, npm audit, TypeScript, production build, Playwright browser smoke tests, and CodeQL is configured separately.
- This review has not executed those checks. A prior green workflow run must not be treated as validation of the current commit unless its SHA matches the audited commit.
- The current `main` commit observed during this review is `0d35c13db81019867fe9929420b0a6916285fbf6`.
- The GitHub API reported branch protection disabled for `main`; whether repository rulesets apply separately still needs checking.

## Repair order

1. Enable branch protections/rulesets and require CI before merge.
2. Add a reviewed lockfile and make CI reproducible.
3. Stop returning raw exception messages from API routes.
4. Remove arbitrary tenant selection and define explicit tenant resolution.
5. Inventory grants, policies, SECURITY DEFINER functions, views, and actual code usage for all flagged tables.
6. Add multi-tenant positive/negative integration tests and immutable-history/idempotency tests.
7. Run CI and record results against the exact commit SHA.
8. Only then proceed to the first vertical business slice.

## Approval boundary

Do not apply migrations to production, delete legacy data/tables, weaken RLS, merge to `main`, or deploy production without explicit approval.
