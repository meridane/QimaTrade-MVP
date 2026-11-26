# QIMA MKT-0.7 — Legacy offer route findings

Date: 2026-10-28. Source review only. No production changes.

## What the current route does

`app/api/offers/route.ts` accepts multipart form data, validates name and quantity, validates optional price/currency, authenticates the user, reads the profile actor, optionally reads the demand and Product Master, then inserts directly into `public.offers` with `lifecycle: draft`.

The route does not call `executeUniversalAction` or the `execute_create_offer_v1` RPC. The RLS INSERT policy observed for `public.offers` checks that the submitted provider actor matches the current profile actor. That policy alone does not establish the user's eligibility for the referenced demand.

## Why we should not change it blindly

The legacy route allows draft offers and optional price, while the universal action path expects a CREATE_OFFER action and currently maps numeric price/currency values. These paths may have different business semantics and UI callers. Replacing one with the other without confirming the draft/optional-price contract could break existing behavior.

## Next safe steps

1. Identify every form/component calling `/api/offers` and document whether it creates a draft or a submitted offer.
2. Confirm the intended lifecycle and whether an offer without a price is valid.
3. Define the provider-demand-tenant authorization rule using existing domain records.
4. Add isolated negative tests for cross-user demand IDs and provider actor tampering.
5. Only then propose a branch-only consolidation, with tests and review.

## Validation

This is source inspection, not proof of exploitability. No production data, policies, grants, schema, or migrations were changed. No merge or production deployment occurred.