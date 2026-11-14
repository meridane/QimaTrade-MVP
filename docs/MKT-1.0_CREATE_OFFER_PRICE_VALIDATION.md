# QIMA MKT-1.0 — CREATE_OFFER price validation implementation

Date: 2026-10-28
Branch: `fix/create-offer-status-contract`
Scope: application-layer validation only. No database schema or production changes.

## Changes committed

- `app/offers/actions.ts`
  - Demand-response offers now reject an empty price before calling the universal action runtime.
  - Price must be finite and non-negative; currency must be one of USD, EUR, KRW, MAD, CNY.
  - Removed the fallback that silently converted a missing price into zero.
  - Sends the validated price and currency to the runtime and sets pricing model to fixed.

- `app/api/actions/create-offer/route.ts`
  - Validates JSON body shape.
  - Requires name and demand ID.
  - Rejects missing, non-finite, or negative price, invalid quantity and unsupported currency with HTTP 400.
  - Continues to derive provider actor from the authenticated profile and requires exactly one tenant membership.

## Deliberate scope boundary

This implements the proposed rule that price is required for a demand response. It does not change the independent draft-first endpoint `app/api/offers/route.ts`, which still supports nullable price and inserts directly into `public.offers`. That flow remains a separate contract and needs a product decision before consolidation.

This also does not solve the demand-owner/tenant/provider authorization invariant. A valid session and tenant membership alone do not prove that the provider is eligible to answer a particular demand.

## Validation status at commit time

- Changes pushed to the existing draft branch; PR #26 remains open and unmerged.
- Vercel Preview status was pending immediately after the last code commit.
- No workflow-run result was returned yet for the last code commit; typecheck/build/integration tests must be confirmed before treating the change as validated.
- No Supabase production migration, data write, RLS change, merge or production deployment was performed.

## Manual regression checklist

1. Empty price in demand-response form returns a readable validation error and does not call the RPC.
2. Price `0` is accepted only if zero is a valid business quote; confirm product policy.
3. Negative, NaN, Infinity and non-numeric prices are rejected.
4. Unsupported currency is rejected.
5. Valid numeric price and supported currency reach the universal action runtime unchanged.
6. Independent draft-first route still accepts a blank price by design.
7. Tenant A cannot answer a demand that tenant A is not authorized to respond to — pending server-side rule and isolated negative test.

## Next gate

Confirm CI and preview checks. Then define and test demand/tenant/provider eligibility in an isolated database before any migration or production action.