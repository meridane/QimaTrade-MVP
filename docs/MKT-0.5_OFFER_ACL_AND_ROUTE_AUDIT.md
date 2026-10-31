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

## Next checks
1. Inspect RLS policies and grants on `public.offers` and related legacy tables.
2. Map every offer-creation route/action and decide the one supported contract.
3. Add negative tests for cross-tenant demand IDs, non-eligible providers, and legacy route behavior.
4. Do not implement a fix until the demand/tenant/provider business ownership model is confirmed.

No Supabase production writes, schema changes, migration, merge or deployment.