# QIMA V1 Function Register — QA372 Appendix

Date: 2026-11-13

## QA372 — non-superuser bootstrap catalog visibility

### Scope

Characterize the read-only CREATE_OFFER bootstrap preflight under two ordinary login roles: one without `pg_monitor`, and one granted `pg_monitor`. All objects are created in a disposable PostgreSQL container pinned to PostgreSQL 16 or 17.6. No persistent server configuration, Supabase data, or production migration is touched.

### Findings and implementation

- PostgreSQL documents `pg_user_mapping` as restricted from normal users. A direct SELECT therefore fails closed for a non-superuser; it does not silently prove that no mapping exists.
- PostgreSQL documents `pg_user_mappings` as a publicly readable view. It exposes the mapping row identity and masks `umoptions` when the current role lacks rights to inspect credential-bearing options.
- The preflight now reads `pg_user_mappings`, joins `pg_depend` through `umid`, and never selects `umoptions`. This preserves extension-membership filtering without granting access to stored mapping options.
- The `pg_subscription` probe reads only `subdbid` and the subscription name. It separately asserts that normal roles cannot select `subconninfo`; no connection string is copied into test output.
- The runtime probes assert whether ordinary roles can see current-database logical slots, physical slots, and large-object metadata owned by another role. The preflight must detect current-database logical slots and large objects while treating physical slots as database-neutral.
- The same preflight is exercised with and without `pg_monitor`. No `pg_monitor` membership is granted to the baseline probe role.
- This validates the read-only preflight only. The full integration runner still applies fixture DDL and migrations and creates roles; this work does not claim that a non-superuser can execute the complete runner or change its credential policy.

### QA372 code-validation evidence

Pending the first CI run for the code HEAD.

### QA372 CodeQL evidence

Pending the first CodeQL run for the code HEAD.

### Safety and interpretation

These are runtime permission and catalog-visibility characterizations on disposable PostgreSQL instances. They do not establish a production vulnerability. Permission errors are treated as errors, not as empty catalog results. No secret, connection string, mapping option, or production credential is read or emitted.

### Documentation references

- PostgreSQL 16 `pg_user_mapping`: https://www.postgresql.org/docs/16/catalog-pg-user-mapping.html
- PostgreSQL 17 `pg_user_mapping`: https://www.postgresql.org/docs/17/catalog-pg-user-mapping.html
- PostgreSQL 16 `pg_user_mappings`: https://www.postgresql.org/docs/16/view-pg-user-mappings.html
- PostgreSQL 17 `pg_user_mappings`: https://www.postgresql.org/docs/17/view-pg-user-mappings.html
- PostgreSQL 17 `pg_subscription`: https://www.postgresql.org/docs/17/catalog-pg-subscription.html
- PostgreSQL 17 predefined roles: https://www.postgresql.org/docs/17/predefined-roles.html
- PostgreSQL 17 `pg_replication_slots`: https://www.postgresql.org/docs/17/view-pg-replication-slots.html
- PostgreSQL 17 `pg_largeobject_metadata`: https://www.postgresql.org/docs/17/catalog-pg-largeobject-metadata.html

### QA372 next step

QA373 should separately characterize the write privileges required by the full fixture runner (database ownership, role creation, extension installation, and migration DDL). Do not infer full-runner support from preflight-only visibility tests, and do not change credential policy without an explicit, evidence-based contract.


### QA372 first CI failure triage — 2026-11-13

CI run [#43279189235](https://github.com/meridane/QimaTrade-MVP/actions/runs/43279189235) exposed a test-harness cleanup defect on PostgreSQL 16: the two disposable login roles retained explicit `CONNECT` grants on the disposable database, so PostgreSQL correctly refused `DROP ROLE`. The runtime now revokes those grants before dropping the roles, and the static contract requires this cleanup ordering.

CodeQL run [#43279189048](https://github.com/meridane/QimaTrade-MVP/actions/runs/43279189048) succeeded. Final validation of the cleanup correction is pending.

No production data, migration, persistent PostgreSQL setting, or credential policy was changed.