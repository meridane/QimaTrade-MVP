# QIMA MKT-1.1 — CREATE_OFFER authorization contract audit

Date: 2026-10-28 (KST)
Branch: `fix/create-offer-status-contract`
Scope: source review and read-only Supabase metadata/data inspection. No production writes or migrations.

## Confirmed from the repository

- `public.execute_create_offer_v1` checks authentication, membership in the supplied tenant, profile actor identity, positive quantity, non-negative price, supported-by-presence currency, active Product Master, existence of the demand, and publication of the CREATE_OFFER action.
- `public.create_offer_v1` checks actor identity and the existence of the product master and demand, then inserts an offer.
- Neither inspected function verifies that the demand is in a response-eligible lifecycle state.
- Neither inspected function proves that the supplied tenant/provider is authorized to answer the specific demand.
- The integration fixture seeds the demand with `requester_actor_id` set to provider B, then successfully creates an offer from provider A under tenant A. This fixture currently demonstrates cross-actor response behavior; it does not establish the intended production authorization rule.
- The legacy `app/api/offers/route.ts` independently inserts a draft offer through Supabase JS and bypasses the Universal Action Runtime. It allows a missing price for a draft. This path remains a separate contract.

## Read-only observations from the actual QIMA Supabase project

- `public.demands` has `requester_actor_id`, `demand_status`, and business fields, but no `tenant_id` column was found in the inspected columns.
- `public.dt_memberships` relates `tenant_id` to `auth.users.id`; `public.profiles` relates `auth_user_id` to `actor_id`.
- No direct tenant-to-demand foreign-key relationship was found in the inspected schema metadata.
- The read-only status count returned 23 demand rows, all with `demand_status = 'draft'`. This is only a snapshot and does not prove the full intended status vocabulary.
- The deployed `execute_create_offer_v1` definition is still the older version (lowercase internal statuses, hash of `p_input` only, and no advisory transaction lock). The corrective SQL remains branch-only.

## Decision: do not guess the authorization policy

A tenant membership check alone does not answer whether:
1. every authenticated supplier may respond to any publicly published demand;
2. only a specific audience/market/category may respond;
3. the demand owner must publish the demand first;
4. an organization/tenant relationship is required; or
5. another existing QIMA permission/policy engine decides eligibility.

The current data snapshot also cannot validate a publication-state rule because all observed demands are drafts. Implementing a hard-coded `published` check before confirming the allowed status values could block every real demand.

## Required next gate

1. Define the business contract for response eligibility: allowed demand states and whether any authenticated tenant can respond or eligibility is restricted.
2. Map that rule to an existing server-side policy/action mechanism where possible; do not trust a client-supplied tenant or provider identity.
3. Add isolated negative tests for (a) draft/closed/unavailable demand, once statuses are confirmed, and (b) a provider/tenant that is not eligible under the approved rule.
4. Review the legacy draft route separately: confirm whether it is an intentional draft-first workflow and what authorization it must enforce before consolidation.
5. Re-run CI and CodeQL on the resulting commit before changing PR status.

## Current validation

- QIMA CI: SUCCESS for head `195dab9bcb2026c6a80f7a0b876a590bbcaf2da5` (run 238).
- QIMA CodeQL: SUCCESS for the same head (run 201).
- These are automated checks on the branch; they do not prove the unimplemented tenant/demand business rule is safe.
- No production migration, write, policy change, merge, or production deployment was performed.
