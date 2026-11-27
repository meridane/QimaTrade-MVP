# QimaTrade — security mission checkpoint

Date: 2026-11-27 (Asia/Seoul)

## Provenance

- Repository: `meridane/QimaTrade-MVP`
- PR under observation: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
- Verified source HEAD: `61002cb21aaa738a7f018794ab84bff41a2c6eb2`
- Mission branch: `work/qima-security-error-boundary-20261127-0441`
- Branch base: exact verified PR HEAD above

## Finding SEC-ROUTE-01 — product-request publish error boundary

Reviewed `app/api/product-requests/publish/route.ts` and `lib/actions/runtime.ts`.

The route's previous catch block returned `error.message` for unexpected failures. The runtime passes Supabase RPC error messages into thrown `Error` objects, so an upstream PostgREST/SQL diagnostic could cross the public HTTP boundary. The previous `message.includes(code)` check could also classify a longer diagnostic string as a public domain error and return that full string.

This is a **confirmed source-level error-disclosure path**. No live exploit, production response, or production vulnerability was tested or confirmed.

## Change on this isolated branch

1. Reject malformed JSON and non-object JSON bodies with stable HTTP 400 `INVALID_REQUEST_BODY` before authentication or database access.
2. Keep the existing required-`requestId` contract.
3. Expose only exact matches from the existing public domain-code allowlist.
4. Replace all other exception messages with the generic HTTP 500 response `Unable to publish product request.`.
5. Add Playwright coverage for malformed JSON, null/array/primitive bodies, non-string request IDs, and the source-level no-raw-error contract.

Files changed:
- `app/api/product-requests/publish/route.ts`
- `tests/e2e/product-request-publish-route-contract.spec.ts`

No SQL, migration, schema, RLS policy, grant, secret, or production setting was changed.

## Validation and evidence limits

- The parent PR HEAD's QIMA CI run #2036 is **SUCCESS**; CodeQL #1962 is **SUCCESS**; the combined Vercel status is **SUCCESS**.
- The new branch has not yet run CI. The new Playwright tests are **pending execution**; this connector session cannot execute the repository's local npm/Playwright commands.
- The canonical register is a 2.9 MB file. Its exact Git blob was readable, but the normal file reader returns an empty body. This append-only companion avoids replacing or truncating the canonical register.
- Existing security documentation records that live Supabase catalog verification is blocked by PostgreSQL authentication error `28P01`. That remains a separate production-evidence blocker; synthetic fixtures do not establish production ACL state.

## Risks and next step

- Confirmed: the old source returned unfiltered exception text from the publish route's catch block.
- Not confirmed: whether any production caller can trigger a particular sensitive database diagnostic, or whether a live production deployment contains this branch's route.
- Next: run the new Playwright file and the full relevant CI on this branch, review the exact diff, then compare this branch with the independent TESTS branch before any integration.

No Supabase Production data or migrations were touched. No Production deployment, PR merge, force-push, or branch-protection change was performed.

## Validation update — 2026-11-27

- QIMA CodeQL run [45891103720](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891103720): **SUCCESS** on the earlier security branch head.
- QIMA CI run [45891103428](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891103428): TypeScript, production build, dependency audit and the isolated QIMA security fixture passed; the Playwright step failed before executing this file because the source-reading test used an ESM-incompatible loader path (require is not defined). This was a test-harness failure, not a confirmed application vulnerability.
- The test now reads the route source using Node's built-in module access and the repository root path. Current branch head at this update: e4570b440b953819e3fca182a0e4d1a8e7f2ba9d.
- Revalidation: QIMA CI [45891442647](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891442647) is queued; CodeQL [45891442644](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891442644) is in progress.
- PostgreSQL 16 and 17.6 integration jobs from the earlier run remain in progress. Vercel Preview for the updated commit is blocked by the provider's 24-hour build-rate limit.
- The original code finding remains a confirmed source-level error-message exposure path in the prior implementation. No real-world exploitation or Production disclosure has been established.

## Authorization review follow-up — 2026-11-27

- The product_requests table stores tenant_id. Its SELECT policy requires a dt_memberships row for that exact tenant; its INSERT policy also requires user_id = auth.uid().
- The SECURITY DEFINER RPC dt_publish_product_request checks auth.uid() = p_user_id and filters the request by id plus user_id, but the function body does not check current membership for the request's tenant_id.
- The API route currently checks only that the user has at least one dt_memberships row; it does not correlate that membership to the selected product request's tenant.
- Potential scenario: a user retains ownership of a request in tenant A but only has a current membership in tenant B. The route's generic membership check may pass, while the SECURITY DEFINER function bypasses the request table's RLS membership predicate. The function's actor/profile and downstream demand tenant semantics still need verification.
- Classification: **authorization hypothesis, not a confirmed vulnerability**. Static source evidence establishes the missing tenant-specific membership check; it does not establish that this scenario is reachable in Production or violates the intended revocation policy.
- Required decision: should loss of membership in a request's tenant prevent publishing an already-owned request? If yes, the check belongs inside the RPC (not only the API route), followed by a disposable two-tenant PostgreSQL fixture against the actual migration. No Production migration or policy was changed.

## Defensive hardening added — 2026-11-27

- Added review-branch migration 20261127100000_harden_product_request_publish_tenant_membership.sql. It scopes the SECURITY DEFINER publish RPC lookup to a current membership in the exact request tenant, then holds that membership row with FOR KEY SHARE for the duration of the publish transaction.
- Missing membership fails closed with PRODUCT_REQUEST_NOT_FOUND, matching the existing tenant-scoped read policy without disclosing whether a request exists.
- Added tests/sql/test-product-request-publish-membership-contract.sh and wired it into the existing disposable security fixture runner.
- This is a defensive change in the isolated review branch only. The migration has not been applied to Supabase Production, and no Production schema, data, grants, or policies were changed.
- Static evidence supports the authorization inconsistency; the isolated source-contract test is not proof of Production exploitability. A real two-tenant fixture against the deployed schema remains a follow-up validation item.
- Latest branch head when this note was prepared: 57b6fbd1b94c769dec361deb69b757b9316079ed. QIMA CI run [45891924945](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891924945) is pending; CodeQL [45891925092](https://github.com/meridane/QimaTrade-MVP/actions/runs/45891925092) is in progress.

## Final validation and compatibility checkpoint — 2026-11-27

- QIMA CI [45892064684](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892064684): **SUCCESS**. Verify job 140159676372 passed TypeScript, dependency audit, Next.js production build and **443 Playwright tests (39.2 s)**. The isolated security fixture ran in this job and printed: PASS: product-request publish RPC enforces current membership for the exact request tenant.
- PostgreSQL 16 integration job 140159676306: **SUCCESS**. PostgreSQL 17.6 compatibility job 140159675998: **SUCCESS**.
- CodeQL [45892064718](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892064718): **SUCCESS**.
- The expected-failure prepared-transaction jobs and expected skipped job remain intentional harness cases; their blocking assertion jobs succeeded.
- Vercel Preview status is **failure** because the provider returned its build-rate-limit page. This is an external Preview-capacity blocker, not evidence of an application build failure.
- The new two-tenant fixture is disposable and exercises the migration function; it does not establish the deployed Production ACL/schema state or prove real-world exploitability.

## Product compatibility decision still required

- The isolated route now returns HTTP 409 TENANT_SELECTION_REQUIRED when the authenticated user has more than one distinct non-null dt_memberships.tenant_id. The current request body does not accept an explicit tenant selector.
- This avoids silently choosing an arbitrary tenant, but changes behavior for multi-tenant users. The intended user flow and client handling have not yet been established by this audit.
- **Decision required:** should a multi-tenant user publish only within the tenant owning the request, or must the user explicitly select an active tenant? If explicit selection is intended, define where that selection is made and how the request's tenant is cross-checked.
- Classification: **product/API compatibility risk**, not a confirmed security vulnerability.
- Next: obtain the product decision, then add a focused route/client contract test. Keep the migration and route change isolated until that decision is recorded.

## Live Supabase evidence blocker — 2026-11-27

- A read-only project metadata lookup for QIMA reports status INACTIVE (paused), PostgreSQL 17.11, region ap-southeast-1.
- Because the project is inactive, no table listing, SQL query, log query, project resume, migration, or database write was attempted.
- Live product_requests/dt_memberships columns, deployed RPC body, grants, and RLS policies therefore remain **unverified**. The disposable two-tenant fixture proves only the isolated migration contract, not Production state.
- Next: obtain explicit owner authorization to resume the project or a separate non-production clone/branch for read-only schema verification. Do not resume it automatically or incur compute cost.
## Static RLS-to-RPC parity review — 2026-11-27

- Reviewed the checked-in source migrations `20260829100000_product_requests_v1.sql` and `20260829110000_product_request_to_demand_bridge_v1.sql`.
- The original `product_requests_select_own_tenant` SELECT policy and `product_requests_insert_own_tenant` INSERT policy both require a `dt_memberships` row matching the request's `tenant_id` and `auth.uid()`; INSERT also requires `user_id = auth.uid()`.
- The original `SECURITY DEFINER` publish RPC checked request ownership (`user_id = p_user_id`) but did not itself check membership in the request's tenant. Because a SECURITY DEFINER function can bypass the table's RLS boundary, the RPC must enforce the tenant condition explicitly.
- The isolated hardening migration now checks the exact request tenant and locks the membership row with `FOR KEY SHARE` before continuing. All relation references in the function are schema-qualified; the function's configured search path is `public`.
- This is a **confirmed source-level mismatch in the checked-in historical migrations**, not proof that the same function or policies are deployed in Supabase Production. Live deployed RPC body, policies, columns and grants remain unverified while the project is paused.
- QIMA CI [45901460978](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901460978) completed **SUCCESS**: Verify **443 Playwright passed**, isolated two-tenant fixture **PASS**, PostgreSQL 16 **SUCCESS**, PostgreSQL 17.6 **SUCCESS**. CodeQL [45901460932](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901460932) **SUCCESS**.
- The CI fixture is disposable and synthetic. It validates the migration's intended behavior only; it does not establish Production exploitability or deployed state.
- The multi-tenant HTTP 409 behavior remains a product/API compatibility decision. Keep the branch isolated until the product owner defines whether publishing is scoped automatically to the request tenant or requires an explicit active-tenant selection.


## Latest isolated CI closeout — 2026-11-27

- Current mission branch HEAD at this checkpoint: `5c0e28b6b4a843119a049cf752b13bcbefdd4142`.
- QIMA CI [#45904993720](https://github.com/meridane/QimaTrade-MVP/actions/runs/45904993720) completed **SUCCESS**. Verify job 140199508343 passed TypeScript, dependency audit, Next.js build and **443 Playwright tests (36.7 s)**. The isolated tenant-membership security fixture was included in the Verify job.
- PostgreSQL 16 integration job 140199508654 and PostgreSQL 17.6 compatibility job 140199508688 both completed **SUCCESS**.
- CodeQL [#45904993732](https://github.com/meridane/QimaTrade-MVP/actions/runs/45904993732) completed **SUCCESS**.
- The expected setup-failure and cleanup-failure harness jobs concluded `failure` by design; their assertion jobs succeeded. The expected skipped-result harness was skipped and its assertion succeeded. Overall CI is **SUCCESS** with no unexpected failing job.
- The Vercel combined status for this branch is **SUCCESS**.
- The source-level RLS/RPC mismatch remains confirmed in the checked-in historical migrations; live deployed Production RPC, RLS, grants and schema remain **unverified** because the QIMA project is paused. The disposable fixture is not evidence of Production exploitability.
- The multi-tenant HTTP 409 behavior remains blocked on product/API decision. Keep this branch in Draft and do not integrate the migration until the intended tenant-selection contract is approved.


## Preview status precision — 2026-11-27

- The **SUCCESS** Vercel status above belongs to the validated code/test HEAD `5c0e28b6b4a843119a049cf752b13bcbefdd4142`.
- After the documentation-only closeout commit `20352d99442a490ae9c19a063a00dda665786470`, the latest PR #27 Vercel status is **PENDING**. No Preview success is claimed for the new documentation commit.


## Disposable RPC EXECUTE ACL regression — 2026-11-27

- Extended `supabase/fixtures/qima_product_request_publish_rpc_tests.sql` to verify the migration grants EXECUTE to `authenticated` and does not leave EXECUTE available to `anon`. The `has_function_privilege` check also detects a privilege inherited through PUBLIC.
- The assertion runs only in the disposable PostgreSQL fixture after the branch-local migration is applied. It does not inspect or alter live Supabase grants.
- Commit: `f59c50147a1089a818041a01a8f7ff072042b022` (`test(security): assert publish RPC execute privileges`).
- Validation: awaiting a new QIMA CI run on the updated branch HEAD. No result is inferred from the earlier fixture run.
- Scope: test-only change; no production data, migration deployment, secret, grant, policy, or persistent configuration was changed.


## Explicit anon EXECUTE revocation regression — 2026-11-27

- The disposable publish-RPC fixture now creates a pre-existing function and explicitly grants EXECUTE to `anon` before applying the hardening migration. This models an ACL that can survive `CREATE OR REPLACE FUNCTION`.
- The migration now explicitly revokes EXECUTE from `anon` in addition to revoking PUBLIC, then grants EXECUTE to `authenticated`.
- The SQL fixture assertion checks that `authenticated` retains EXECUTE and `anon` does not inherit it; the shell contract also requires the explicit anon revoke.
- This is a branch-local migration and disposable fixture only. It has not been applied to Supabase Production and does not establish live Production grants.
- Validation: pending the current SECURITY branch QIMA CI after the ACL-fixture follow-up.
