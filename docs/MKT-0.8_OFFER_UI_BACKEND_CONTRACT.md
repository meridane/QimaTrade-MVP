# QIMA MKT-0.8 — Offer UI-to-backend contract map

Date: 2026-10-28
Branch: `fix/create-offer-status-contract`
Scope: source review only; no database or production changes.

## UI entry points confirmed

### A. Independent supplier offer draft
- UI: `app/offers/new/page.tsx`
- Form action: `POST /api/offers`
- Backend: `app/api/offers/route.ts`
- Behavior visible in source: no demand ID is required; price is optional; created row is assigned `lifecycle: "draft"`; success redirects to `/offers?created=<id>`.
- This is a draft-first supplier flow and is not equivalent to a demand response.

### B. Offer against a buyer demand
- UI: `app/offers/page.tsx`
- Server action: `createOffer` in `app/offers/actions.ts`
- Runtime: `lib/actions/runtime.ts`
- RPC: `execute_create_offer_v1`
- Behavior visible in source: a demand ID and a Product Master linked in demand scope are required; a single tenant membership is required; creation is submitted through universal action runtime.

## Contract mismatch requiring a decision

The demand-specific UI makes price optional. In `app/offers/actions.ts`, an empty price is converted to `null`, but the universal action input then sends `price: price ?? 0` and `currency: price === null ? "USD" : currency`. In `app/api/actions/create-offer/route.ts`, the input is converted with `Number(body.price)`; an omitted price becomes `NaN`. These are three different representations of an optional price.

This should be resolved explicitly before consolidating routes:
1. Is price optional for a demand response, or only for a draft?
2. If optional, should the database store NULL or a separate “price pending” state? Zero must not silently mean unknown price.
3. Should the universal route reject missing/invalid price or normalize it to the agreed representation?
4. Should the independent draft route remain supported, or be retired after its UI and lifecycle are migrated?

## Authorization still unresolved

Both routes derive the provider actor from the authenticated profile, which is good. The source read did not establish a complete server-side invariant tying the demand to the selected tenant and confirming the provider may respond to that demand. Reads of a demand alone do not prove eligibility. RLS metadata also does not answer the full business ownership question.

## Safe next actions

- Agree the price/draft contract and provider-to-demand eligibility rule.
- Add tests for missing price, zero price, malformed price, wrong tenant, unrelated provider, and cross-user demand IDs.
- Exercise tests in isolated development/test data before any schema or policy change.
- Only then consolidate the API paths and update the function register.

## Safety boundary

This document records source findings, not confirmed exploitability. No production writes, SQL migrations, RLS changes, merge, or production deployment occurred.