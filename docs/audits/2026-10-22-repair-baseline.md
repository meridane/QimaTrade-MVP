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


## Repair progress — tenant resolution

Changes staged on `chore/qima-free-autopilot-review` after the initial baseline:

- `lib/decision-tree/server.ts`: `getTenantForUser` now loads memberships and returns a tenant only when exactly one exists. It fails closed with `TENANT_SELECTION_REQUIRED` when multiple memberships exist instead of choosing an arbitrary row.
- `app/api/actions/create-offer/route.ts`: rejects missing or ambiguous memberships before executing `CREATE_OFFER`.
- `app/api/product-requests/route.ts`: rejects missing or ambiguous memberships before associating a request with a tenant.
- Decision Tree session endpoints now translate ambiguous membership into HTTP 409 and a stable public code.
- `app/api/decision-tree/answer/route.ts`: returns stable public error codes rather than raw exception messages.

### Known limitation

This is a fail-closed safety measure, not the final multi-tenant UX. A user with memberships in multiple organizations will need an explicit tenant-selection flow that validates the selected organization server-side. Until that exists, these endpoints intentionally reject ambiguous membership rather than guessing.

### Validation still pending

No typecheck, build, automated test, Supabase integration test, or two-organization isolation test has been executed against these changes yet. Do not merge this branch or call the Security Gate passed until those checks run against the exact branch commit.


## CI results for repair branch commit `f420b1250f8838ee84ca4c85a8a79b9534f48c87`

- QIMA CodeQL Security: **success**.
- QIMA CI: **success**. Dependency installation, dependency security audit, TypeScript check, production build, Playwright Chromium installation, and browser smoke tests all completed successfully.
- These checks validate this branch commit only. They do not prove tenant isolation, production Supabase policy correctness, or historical immutability. Dedicated integration tests against two distinct test tenants remain necessary.

## Additional SQL finding — direct DML grants

The migration `20260829102000_grant_authenticated_v1_decision_tree_access.sql` grants authenticated users `INSERT, UPDATE, DELETE` on `dt_sessions`, `dt_observations`, `dt_transitions`, and `product_requests`. The Decision Tree design also has server-side RPCs for some mutations. We must map every direct write in application code and test the RLS behavior before deciding which grants to revoke. Do not apply a blanket revoke without that usage inventory, because it could break legitimate flows.


## SQL permissions and write-path inventory (static review)

### Observed application write paths

| Table | Observed write path in reviewed files | Initial conclusion |
|---|---|---|
| `dt_sessions` | `lib/decision-tree/server.ts` uses direct authenticated `.insert(...)` in `createDecisionSession`. | Do not revoke INSERT until session creation is moved to a validated RPC or the policy is otherwise proven sufficient. |
| `product_requests` | `app/api/product-requests/route.ts` uses direct authenticated `.insert(...)`; publishing is handled by `dt_publish_product_request`. | INSERT is currently used by the application. Check UPDATE/DELETE usage and RLS before changing grants. |
| `dt_observations` | Reviewed Decision Tree answer persistence uses `dt_submit_answer` RPC. | Direct DML grant appears unnecessary in the reviewed path, but full-repository usage and integration tests are still required before revocation. |
| `dt_transitions` | Reviewed Decision Tree transition persistence occurs inside `dt_submit_answer` RPC. | Direct DML grant appears unnecessary in the reviewed path, but full-repository usage and integration tests are still required before revocation. |
| `product_masters` | Read in the reviewed flows; selection/persistence is performed by RPC. | Do not change permissions without mapping all product management/admin workflows. |

### Security implications

- Migration `20260829102000_grant_authenticated_v1_decision_tree_access.sql` grants `INSERT, UPDATE, DELETE` to `authenticated` on `dt_sessions`, `dt_observations`, `dt_transitions`, and `product_requests`.
- Migration `20260901090000_security_gate_dt_v1.sql` makes `dt_submit_answer` a `SECURITY DEFINER` function, derives the target node from stored rules, validates `auth.uid()`, user/session ownership, tenant membership, active status, revision, node/tree version, and tenant/tree consistency.
- The migration does not itself remove the table-level DML grants on `dt_observations` and `dt_transitions`. Their policies and grants must be considered together: an RPC being secure does not prevent users from using any still-authorized direct DML path.
- The base migration defines broad `FOR ALL` policies on session, observation and transition rows; later migrations may change policies. The full migration sequence and actual Supabase catalog must be reconciled before deciding the final permissions.
- `dt_submit_answer` is a security-sensitive definer function. Its effective owner, execute grants, RLS bypass behavior, and exact deployed definition must be checked in the target database before the Security Gate can pass.

### Next safe remediation proposal (not applied)

1. In a test/staging environment, prove no supported UI or API relies on direct INSERT/UPDATE/DELETE to `dt_observations` or `dt_transitions`.
2. Add integration tests asserting authenticated clients cannot directly insert/update/delete observations or transitions, while `dt_submit_answer` still succeeds and remains idempotent.
3. If the tests pass, prepare a new migration that revokes unnecessary direct DML grants on those two tables. Review policies, table grants, function ownership and RPC execution grants together.
4. Separately assess direct session creation and product-request creation. Preserve required inserts until equivalent server-validated RPCs exist or policy coverage is proven.
5. Test cross-tenant reads and writes using two separate test users and tenants, including forged tenant IDs and session IDs.
6. Do not apply this proposed migration to production as part of the audit.

## Audit status

Static code and migration review only. No live Supabase catalog was queried; no migration was applied; no authenticated multi-tenant integration tests were run. Therefore the exact deployed grants/policies and actual cross-tenant behavior remain **unverified**.


## Correction after reading the complete Security Gate migration

The earlier statement that the Security Gate migration did not remove direct DML grants on observations/transitions was incomplete. Reading the full `20260901090000_security_gate_dt_v1.sql` confirms it explicitly revokes `INSERT, UPDATE, DELETE` on both `dt_observations` and `dt_transitions` from `authenticated`, and removes the observations' broad `FOR ALL` policy. This is a positive existing control and should not be reimplemented blindly.

The migration revokes those grants, but it does **not** revoke the direct `INSERT, UPDATE, DELETE` grants on `dt_sessions` that were added by the earlier grant migration. The original `dt_sessions_all` policy is also not replaced by the Security Gate migration. Thus an authenticated owner of a session may retain direct row-level write capability, subject to the actual deployed grants and RLS. This is a priority to test and tighten.

## Revised permission findings

| Table | Migration evidence | Status |
|---|---|---|
| `dt_observations` | Security Gate removes broad policy and revokes authenticated INSERT/UPDATE/DELETE. | Positive control in migration history; confirm deployed schema. |
| `dt_transitions` | Security Gate revokes authenticated INSERT/UPDATE/DELETE. | Positive grant control in migration history; inspect all policies and deployed schema. |
| `dt_sessions` | Earlier migration grants authenticated INSERT/UPDATE/DELETE; Security Gate does not revoke those rights or replace `dt_sessions_all`. | **Priority finding:** verify whether direct session mutation can bypass revision/status invariants. |
| `product_requests` | Earlier migration grants authenticated INSERT/UPDATE/DELETE, but the reviewed table migration only defines SELECT and INSERT policies. | Direct UPDATE/DELETE may be blocked by RLS despite the grants; confirm policy set and deployed schema. |
| `dt_select_product_master` | Defined as `SECURITY INVOKER`; updates the caller's session when RLS/grants permit it. | Direct session UPDATE rights are needed for this invoker function as currently written; prefer a narrow validated RPC plus revoke rather than blanket revocation. |

## Proposed next change (not applied)

Build a test-only SQL/RPC verification pack before modifying permissions. In a disposable staging database with two tenants and users, assert:
1. A user cannot directly alter `current_node_id`, `revision`, `status`, `tenant_id`, or `user_id` on a session in a way that bypasses the state machine.
2. The supported answer RPC advances a session exactly once and preserves idempotency.
3. Product selection still works after session write privileges are narrowed.
4. Users cannot access or mutate another user's session, including across tenant boundaries.
5. Observation and transition direct INSERT/UPDATE/DELETE fail for authenticated users while the supported RPCs still record history.
6. Product request UPDATE/DELETE attempts fail unless a specifically authorized lifecycle operation permits them.

No SQL was executed against Supabase. No migration was applied. The deployed catalog and runtime outcomes remain unverified.
