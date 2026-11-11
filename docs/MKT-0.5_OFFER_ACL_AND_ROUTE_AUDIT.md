# QIMA MKT-0.5 — Function ACL and offer creation path audit

**Date:** 2026-10-28  
**Scope:** read-only ACL metadata and source-code review on branch `fix/create-offer-status-contract`. No production writes.

## Function EXECUTE ACL
- `public.create_offer_v1(...)`: EXECUTE granted to `authenticated` and owner `postgres`; no direct PUBLIC grant appeared in the inspected ACL rows.
- `public.execute_create_offer_v1(...)`: EXECUTE granted to `authenticated` and owner `postgres`; no direct PUBLIC grant appeared in the inspected ACL rows.
- `core.can_access_publication(uuid)`: EXECUTE granted to PUBLIC and owner `postgres`. This alone does not prove data exposure; function logic and RLS context still matter.

## Application paths
- `app/api/actions/create-offer/route.ts` uses the universal action runtime and checks bearer authentication, profile actor, and exactly one tenant membership. It does not itself establish the demand ↔ tenant ↔ provider business eligibility contract; the database RPC also needs that explicit invariant.
- `app/offers/actions.ts` uses `executeUniversalAction`, refuses to choose arbitrarily among multiple tenants, and reads the demand before creating the action. These reads do not themselves prove that the user/provider is authorized to answer that demand.
- **Legacy route:** `app/api/offers/route.ts` directly inserts into `public.offers` and redirects, instead of using the universal `CREATE_OFFER` action runtime. This is a second creation contract and should be treated as a compatibility/security risk until it is either retired, routed through the universal runtime, or explicitly secured and tested. No code change was made.

## Public offers table privilege dependencies — source inventory (11 November 2026)

The following is a bounded source review of the offer-related call sites in this branch, not an exhaustive proof that no other application, background, or administrative caller exists.

| Reviewed path | Observed operation on `public.offers` | Permission dependency |
|---|---|---|
| `lib/offers/create-legacy-offer.ts` (called by `app/api/offers/route.ts`) | `insert({...}).select("id").single()` for an independent draft | INSERT plus SELECT access for the returned representation; the effective SELECT RLS policy must be checked separately |
| `app/demands/conversation/actions.ts` | SELECT `id,demand_id` for a requested offer and SELECT latest `id` by demand | SELECT, with row visibility determined by the actual SELECT policy |
| `app/offers/actions.ts` | Reads demand/Product Master context and calls `executeUniversalAction`; no direct `offers` table DML in this file | Runtime/RPC path, not direct table INSERT/UPDATE/DELETE |
| `app/api/actions/create-offer/route.ts` | Calls the Universal Action Runtime | RPC/function EXECUTE path; no direct table DML in this route |

No direct UPDATE or DELETE operation was found in these reviewed offer-specific paths. This is not a repository-wide absence claim and is not sufficient evidence to revoke UPDATE or DELETE. TRUNCATE is not governed by row-level security and must be assessed separately from RLS policies.

### Evidence boundaries

- The existing migration `20260829130000_fix_offers_insert_rls_actor_lookup.sql` defines only the actor-bound INSERT policy `offers_insert_own_provider`; it does not define SELECT, UPDATE, or DELETE policies.
- QA330 applies that INSERT policy to the disposable CI fixture and checks actor identity. It does not validate the PostgREST `.insert(...).select("id")` return path or the live SELECT policy.
- The fixture grants SELECT to `authenticated` and QA330 adds INSERT. QA331 now asserts that this fixture does not accidentally acquire authenticated UPDATE/DELETE/TRUNCATE or any anon table privileges, and that the fixture contains only the one INSERT policy. These are test-fixture invariants, not claims about live Supabase ACLs.
- The historical read-only snapshot in `docs/SECURITY_AUDIT_2026-10-28.md` recorded broad table privileges, including TRUNCATE, on several historical tables including `public.offers`. That snapshot is dated 28 October 2026 and is not treated as the current effective ACL.
- No current live catalog result was available in this run. The previously documented PostgreSQL `28P01` authentication blocker prevents re-verifying effective grants, column grants, table owner, RLS flags, or policy definitions. No connection retry or credential change was attempted.

### Read-only catalog query for an authorized operator

The following query is read-only. Run it only with an approved catalog-read account against the intended project; it does not change grants, policies, schema, or data.

```sql
BEGIN READ ONLY;

SELECT role_name, privilege_name,
       has_table_privilege(role_name, 'public.offers', privilege_name) AS effective
FROM (VALUES ('anon'), ('authenticated')) AS roles(role_name)
CROSS JOIN (VALUES
  ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
  ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
) AS privileges(privilege_name)
ORDER BY role_name, privilege_name;

SELECT grantee, grantor, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'offers'
  AND grantee IN ('anon', 'authenticated', 'PUBLIC')
ORDER BY grantee, privilege_type, grantor;

SELECT grantee, column_name, privilege_type, is_grantable
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name = 'offers'
  AND grantee IN ('anon', 'authenticated', 'PUBLIC')
ORDER BY grantee, column_name, privilege_type;

SELECT pg_get_userbyid(c.relowner) AS table_owner,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class c
WHERE c.oid = 'public.offers'::regclass;

SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'offers'
ORDER BY policyname;

COMMIT;
```

### Safe next gate

1. Obtain authorized read-only catalog output for the current effective table/column privileges and policies.
2. Compare SELECT requirements for the legacy draft return representation and conversation reads against the actual SELECT policy.
3. Search the full repository and operational integrations for UPDATE, DELETE, TRUNCATE, trigger, and background-job dependencies.
4. Only after the complete dependency map is reviewed, prepare any least-privilege change in a disposable database and test all normal flows. Do not issue REVOKE based on the fixture or the historical snapshot alone.

No production migration, data write, grant change, RLS change, merge, or deployment was performed by this source inventory.


## Next checks
1. Inspect RLS policies and grants on `public.offers` and related legacy tables.
2. Map every offer-creation route/action and decide the one supported contract.
3. Add negative tests for cross-tenant demand IDs, non-eligible providers, and legacy route behavior.
4. Do not implement a fix until the demand/tenant/provider business ownership model is confirmed.

No Supabase production writes, schema changes, migration, merge or deployment.

## QA332 — legacy draft INSERT RETURNING and SELECT-policy mechanics (11 November 2026)

The legacy handler in `lib/offers/create-legacy-offer.ts` performs `insert(...).select("id").single()`. The conversation actions also issue SELECT queries against `public.offers`. The existing QA330/QA331 fixture deliberately contains only the INSERT policy, so it does not cover the return/read path.

A new disposable regression, `tests/sql/legacy-offer-returning-select-rls-regression.sql`, checks the PostgreSQL mechanics separately:

- With the existing actor-bound INSERT policy but no SELECT policy, the test requires that the inserted row is not successfully returned. The probe runs in a PL/pgSQL subtransaction so any attempted insert is rolled back.
- The test then creates a **synthetic, actor-scoped SELECT policy** named `qa332_offers_select_own_provider` inside the same transaction.
- Under each of the two authenticated fixture users, `INSERT ... RETURNING id` must return the new own-actor row, a demand-scoped SELECT must see the two own-actor rows, and the other provider's rows must remain invisible under this synthetic policy.
- The test rolls back the temporary policy, grants, helper function, seed rows, and inserted rows.

**Evidence boundary:** the synthetic SELECT policy is used only to exercise PostgreSQL RLS and the application's INSERT-returning/SELECT query shapes. It is not a proposed production policy and does not decide whether buyers, suppliers, or conversation participants should see one another's offers. QA332 does not establish the current live Supabase SELECT policy or prove a production vulnerability.

### Safe next gate

1. Obtain authorized read-only catalog output for the live `public.offers` SELECT grants and policies.
2. Confirm the intended visibility contract for supplier drafts and buyer/supplier conversations.
3. Exercise the actual policy and `.insert(...).select("id").single()` behavior against an approved disposable schema copy before proposing any migration.
4. Keep demand/tenant/provider eligibility separate until the product owner confirms the rule.

No production data, policy, grant, schema, migration, or credential was changed.


### QA332 validation and correction (11 November 2026)

- **Initial CI #1195:** the new SQL test correctly reached the synthetic SELECT-policy scenario, but both PostgreSQL jobs failed because the actor-visible row count included pre-existing offers created by the broader CREATE_OFFER fixture (`own rows 63`) instead of only QA332's own rows. The cross-provider count remained zero. This was an over-broad test assertion, not evidence of a cross-provider visibility failure.
- **Correction:** both actor-owned and cross-provider count queries now constrain the row set with `name LIKE 'QA332 %'`, so unrelated fixture offers cannot affect the expected count.
- **CI #1196:** **SUCCESS**, all three jobs completed successfully. The QA332 marker was confirmed in both PostgreSQL 16 and PostgreSQL 17.6 job logs. The pinned PostgreSQL 17.6 check reported `server_version_num=170006`.
- **Build/browser:** dependency audit, TypeScript, Next.js production build, Chromium installation, and Playwright succeeded; Playwright reported **336 passed, 0 failed**.
- **CodeQL #1147:** **SUCCESS**.
- **Vercel:** the latest combined status returned `build-rate-limit`; this is a Preview quota limitation, not a CI or CodeQL failure. No Production deployment was attempted.

QA332 remains a synthetic PostgreSQL mechanics test. Its actor-scoped SELECT policy is rolled back and is not asserted to be the current or intended live Supabase policy.


## QA333 — Legacy draft INSERT without SELECT-dependent RETURNING (2026-11-11)

### Observation

The legacy draft handler previously used `.insert(payload).select("id").single()`. QA332's disposable PostgreSQL fixture demonstrates that an authenticated role can satisfy the existing INSERT policy while `INSERT ... RETURNING` does not expose a row when no SELECT policy is present. This is a PostgreSQL/RLS mechanics result from a synthetic fixture, not evidence about the live Supabase policy.

### Change

`lib/offers/create-legacy-offer.ts` now generates a UUID with the already imported Node `randomUUID()` before insertion, includes it as `offers.id`, awaits plain `.insert(payload)` without `.select()`, and redirects using the generated UUID. The INSERT error path remains generic. No grant, RLS policy, or migration was changed.

### Regression coverage

- `tests/e2e/legacy-offers-route-contract.spec.ts` now models a successful plain INSERT as `{ data: null, error: null }`; the mock intentionally exposes no `.select()` chain, so the test fails if the handler reintroduces INSERT RETURNING.
- `tests/sql/legacy-offer-returning-select-rls-regression.sql` retains the no-SELECT RETURNING probe and now additionally verifies that a plain INSERT succeeds under `authenticated` with the actor-bound INSERT policy and no SELECT policy. The outer transaction rolls back all fixture rows and the synthetic policy.
- This change removes the SELECT-policy dependency from the *creation response only*. It does not establish who may subsequently read an offer, and it does not resolve buyer/supplier conversation visibility.

### Validation and correction history

- Initial code run **CI #1198** (run `42955879121`) failed both PostgreSQL jobs because the new plain-insert fixture name matched the QA332 `name LIKE 'QA332 %'` visibility-count filter, producing `own rows 3`. The cross-provider count remained zero. This was test-fixture isolation, not evidence of an RLS bypass.
- The fixture row was renamed to `legacy plain INSERT without SELECT policy`, outside the QA332 visibility-count namespace.
- Final **CI #1199** (run `42956060853`) — **SUCCESS, 3/3 jobs**. PostgreSQL 16 and PostgreSQL 17.6 both completed the QA332 SQL step; PostgreSQL 17.6 reported `server_version_num=170006`.
- Build/browser job — dependency audit, TypeScript, Next.js production build and Chromium succeeded; Playwright reported **335 passed, 0 failed** (one obsolete “no returned row” test was replaced by the no-RETURNING regression).
- **CodeQL #1150** (run `42956060821`) — **SUCCESS**.
- **Vercel:** current code HEAD reports the free-plan `build-rate-limit` Preview status. This does not alter the GitHub Actions or CodeQL results. No Production deployment was attempted.

### Separate open contract discrepancy — Product Master versus demand scope

PR #24 (`security: add demand, offer and conversation guards`) remains **open and unmerged** at its inspected head `d47505758afb49dce25eecf9604efafa02f2f6c1`; the review and review-thread lists were empty at inspection time. Its proposed multipart endpoint change rejects a form-supplied Product Master that differs from `demand.scope.product_master_id` and then uses the demand's canonical Product Master. In contrast, PR #26's current legacy helper and its E2E test explicitly allow a form-supplied Product Master to override the demand-scope fallback. This is a cross-PR contract divergence, not a confirmed production vulnerability. It was not changed in QA333 because PR #24 is unmerged and the intended shared contract still needs maintainer confirmation. PR #24's own CI/CodeQL results do not validate PR #26.

### Safety boundary

No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was touched. No Production deployment, PR merge, force update, or branch-protection change was made.
