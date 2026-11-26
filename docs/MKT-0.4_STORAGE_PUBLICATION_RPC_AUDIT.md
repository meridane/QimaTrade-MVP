# QIMA MKT-0.4 — Storage, publication lifecycle and privileged RPC audit

**Date:** 2026-10-28  
**Scope:** read-only Supabase metadata and function-definition review for automotive-parts marketplace feasibility.  
**Environment:** Supabase project `yyulzlnrfcbaxovzjbnh`.  
**Safety:** no production writes, schema changes, policy changes, migration, merge or deployment.

## Findings

### Storage
- `storage.buckets` returned one bucket: `project-documents`, private.
- Policies returned for `storage.objects` cover SELECT/INSERT/UPDATE/DELETE on `project-documents` and use `can_access_project((storage.foldername(name))[1]::uuid)`.
- No dedicated marketplace-photo bucket/access contract was found in this inventory. This is a finding about the queried environment, not a recommendation to expose a public bucket.

### Publication lifecycle
- Only trigger found on `core.publications`: `trg_publications_updated_at`, BEFORE UPDATE, calls `core.set_updated_at()`.
- No publication moderation/status enforcement trigger was found on that table.
- `core.can_access_publication(uuid)` is SECURITY DEFINER with fixed search_path `pg_catalog, auth, core`; it allows the author or status ACTIVE/REOPENED and has no moderation-approval predicate.
- Current enums already documented: kind OFFER/REQUEST; status DRAFT/ACTIVE/PAUSED/CLOSED/REOPENED/ARCHIVED. No PENDING_REVIEW or REJECTED state.

### Privileged offer RPCs
- `public.create_offer_v1(...)` is SECURITY DEFINER, search_path `public`. Its inspected definition checks auth, provider actor identity, positive quantity, nonnegative price, currency, Product Master existence, and demand existence. It does not check demand-to-tenant membership/ownership or provider eligibility for that demand.
- `public.execute_create_offer_v1(...)` is SECURITY DEFINER, search_path `public`. It checks tenant membership for the caller, provider actor identity, quantity/price/currency, active Product Master, demand existence, and published CREATE_OFFER action. The inspected body does not validate the business relationship between the demand, tenant, and provider.
- Idempotency hash is computed from `md5(p_input::text)`; server-side contract must ensure `p_input` represents the same effective business parameters as the explicit RPC arguments. This is a review concern, not proof of exploit.
- Verify EXECUTE ACLs/grants for SECURITY DEFINER RPCs and callers before changing anything. Do not assume a function is unreachable just because it is not used in the UI.

### Constraints / vehicle-fitment gap
Foreign keys link publications to generic category/product/context/media/item references. The inspected constraints do not provide an explicit vehicle fitment model for make/model/year/engine/OEM reference.

## Risk disposition
1. **BLOCKER:** define and enforce the demand ↔ tenant ↔ provider authorization contract for CREATE_OFFER; add negative tests for cross-tenant and ineligible-provider attempts.
2. **BLOCKER for public marketplace:** implement server-controlled moderation status transitions and test direct attempts to set ACTIVE.
3. **BLOCKER for listing photos:** define private Storage upload/read/delete policies and signed URL behavior for drafts, pending review, published listings, and moderation staff.
4. **Architecture undecided:** compare extension of `core.publications` with a separate marketplace context/tables; no new table is approved yet.

## Next read-only/branch-only work
- Inspect grants and EXECUTE ACLs for privileged functions and grants on related tables.
- Trace app routes/actions invoking offer/publication functions.
- Document the demand/tenant/provider ownership model and test matrix.
- Produce an Option A/B field mapping and migration proposal on a feature branch only.

No production data, policy, function, table, or migration was changed.