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
