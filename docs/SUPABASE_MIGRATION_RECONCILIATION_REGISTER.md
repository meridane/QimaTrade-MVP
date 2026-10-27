# Supabase migration reconciliation register

**Snapshot date:** 2026-10-27  
**Branch:** `fix/create-offer-status-contract`  
**Status:** INVENTORY ONLY — reconciliation is not complete.

## Evidence captured

- The connected Supabase project's migration history returned 161 applied versions. Latest remote version: `20261026034925 enable_rls_on_unexposed_reference_tables`.
- The current repository branch contains 17 SQL migration files in `supabase/migrations/`.
- The two newest local files are proposals for CREATE_OFFER and are not in the remote applied history:
  - `20261027090000_fix_create_offer_action_status_contract.sql`
  - `20261027100000_restrict_direct_create_offer_rpc.sql`
- A count difference does not prove every missing remote migration must be recreated as an individual file. Some historical changes may be represented by a baseline, external/manual changes, or files lost from version control. That must be established from schema and SQL definitions.

## Local migration inventory (17 files)

| Version | File |
|---|---|
| 20260824065000 | `20260824065000_create_project_documents.sql` |
| 20260824080000 | `20260824080000_create_project_inspections.sql` |
| 20260829090000 | `20260829090000_create_decision_tree_v1.sql` |
| 20260829091000 | `20260829091000_create_decision_answer_transaction.sql` |
| 20260829091500 | `20260829091500_seed_decision_tree_v1.sql` |
| 20260829092000 | `20260829092000_link_decision_tree_to_canonical_taxonomy.sql` |
| 20260829093000 | `20260829093000_persist_selected_product_master.sql` |
| 20260829100000 | `20260829100000_product_requests_v1.sql` |
| 20260829102000 | `20260829102000_grant_authenticated_v1_decision_tree_access.sql` |
| 20260829110000 | `20260829110000_product_request_to_demand_bridge_v1.sql` |
| 20260829112000 | `20260829112000_add_product_request_updated_at.sql` |
| 20260829113000 | `20260829113000_improve_mvp_matching_and_country_fields.sql` |
| 20260829130000 | `20260829130000_fix_offers_insert_rls_actor_lookup.sql` |
| 20260901090000 | `20260901090000_security_gate_dt_v1.sql` |
| 20260901120000 | `20260901120000_action_definition_read_rpc_v1.sql` |
| 20261027090000 | `20261027090000_fix_create_offer_action_status_contract.sql` (proposal; not applied) |
| 20261027100000 | `20261027100000_restrict_direct_create_offer_rpc.sql` (proposal; not applied) |

## Reconciliation work required

For each of the 161 remote version records, add one row to a future full register with:
1. remote version and migration name;
2. matching tracked file path and file hash, if found;
3. classification: `MATCHED`, `BASELINE`, `MANUAL/EXTERNAL`, `MISSING_SOURCE`, or `UNRESOLVED`;
4. evidence comparing the SQL change to the current live schema;
5. whether the migration is safe/relevant for a clean disposable database;
6. reviewer and resolution note.

The full remote history must be exported without truncation and joined to a complete recursive Git tree of the branch. Do not infer matches from timestamps or similar names alone.

## Safe procedure

1. Read/export the remote schema and migration history only; do not write to production.
2. Download all repository migration files and compare definitions/version IDs.
3. Create a baseline/replay plan only after classifying every remote version.
4. Test the plan in a newly created disposable PostgreSQL/Supabase database.
5. Review grants, RLS, extensions, triggers, functions, and seed data before deciding whether a clean reconstruction is equivalent.
6. Keep any CREATE_OFFER proposals separate until their own authorization and draft-compatibility gates pass.

## Explicit prohibitions for this audit

- Do not run `supabase db reset`, `supabase db push`, or bulk replay against production.
- Do not mark migration parity as passed based only on counts.
- Do not claim this register contains all 161 remote rows; it currently records the verified count, latest version, and all local filenames only.
- No production migration or data mutation was performed for this inventory.
