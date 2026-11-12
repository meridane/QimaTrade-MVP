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

CodeQL run [#43279189048](https://github.com/meridane/QimaTrade-MVP/actions/runs/43279189048) succeeded. The cleanup correction subsequently passed in CI #1346 (run #43281883350).

No production data, migration, persistent PostgreSQL setting, or credential policy was changed.

### QA369 host-port failure triage — 2026-11-13

CI #43279189235 failed in the PostgreSQL 17.6 QA369 slot runtime with `psql: server closed the connection unexpectedly` against the disposable container's published port. The available job log does not establish whether this was a startup race or a container termination. The runtime now waits for a host-side `SELECT 1` after internal `pg_isready`, checks container state during readiness, and prints the bounded container log tail if the host probe fails or the container stops. Cleanup only queries the second database after its successful creation.

Final validation succeeded in CI #1346 (run #43281883350) on PostgreSQL 16 and 17.6. The host-side readiness probe passed on both versions; the original connection error remains an unconfirmed transient symptom, not a confirmed PostgreSQL defect.


### QA372/QA369 corrective validation — 13 November 2026

- Corrected code HEAD: `a4d194ffcf34580910db0bdf900f047059eb8f56`.
- QIMA CI [#43280824308](https://github.com/meridane/QimaTrade-MVP/actions/runs/43280824308): **SUCCESS**. Both PostgreSQL integration jobs (16 and 17.6) passed; the QA369 logical-slot runtime and QA372 non-superuser catalog-visibility runtime passed on both versions.
- The QA372 Verify contract passed, including the assertion that database CONNECT grants are revoked before disposable roles are dropped. npm audit at the high threshold, TypeScript, Next.js production build, Chromium installation, and Playwright all passed. Playwright: **347 passed in 10.6 seconds**.
- CodeQL [#43280824337](https://github.com/meridane/QimaTrade-MVP/actions/runs/43280824337): **SUCCESS**.
- Earlier CI #43280742571 failed only in Verify because its static guard expected unescaped identifier quotes; both PostgreSQL jobs, including QA369 and QA372 runtime probes, succeeded. The matcher was corrected in commit `a4d194f` and the corrected HEAD passed CI #43280824308.
- The prepared-transaction failure harness jobs retain their intentional failure outcomes; their separate blocking assertions succeeded. The skipped harness remains skipped with its assertion successful.
- Vercel remains rate-limited for the final HEAD. No Preview success is claimed for this HEAD.
- PR #26 remains open, mergeable, in draft, unmerged, with no human reviews or review threads.



### QA372 final-register assertion correction — 2026-11-13

CI run [#43281662101](https://github.com/meridane/QimaTrade-MVP/actions/runs/43281662101) (run #1345) reached Verify and stopped in the newly added documentation-evidence guard. The guard used bare grep commands under `set -e` and searched a run label without accounting for the Markdown link bracket. This was a static-test defect, not a PostgreSQL runtime failure. The correction searches stable run-ID substrings and adds explicit failure messages. The corrected guard passed in CI #1346 (run #43281883350).


### QA372 / QA369 final corrective validation — 13 November 2026

- Final code-and-documentation HEAD before this evidence-only update: `d2f3473dc14b11ba37b84ead73a37d02e4cce3a7`.
- QIMA CI [#1346](https://github.com/meridane/QimaTrade-MVP/actions/runs/43281883350): **SUCCESS**. PostgreSQL 16 and PostgreSQL 17.6 integration jobs both succeeded. QA369 logical-slot runtime and QA372 non-superuser visibility runtime passed on both versions.
- Verify job: QA369 and QA372 static contracts passed; npm audit at the high threshold, TypeScript, Next.js production build, Chromium, and Playwright succeeded. Playwright: **347 passed in 9.4 seconds**.
- CodeQL [#1295](https://github.com/meridane/QimaTrade-MVP/actions/runs/43281883127): **SUCCESS**.
- CI #1345 (run #43281662101) failed only in the newly added QA372 documentation-evidence guard; both PostgreSQL integration jobs succeeded. The bare-grep / Markdown-link matching defect was corrected in commit `d2f3473`, and CI #1346 validated the corrected guard.
- The prepared-transaction failure harness jobs retain intentional failure conclusions; their separate blocking assertions passed. The skipped harness remains skipped and its assertion passed.
- Vercel remains **RATE LIMITED** (`build-rate-limit`) on the final code HEAD. No Preview success is claimed for this HEAD.
- PR #26 remains **OPEN**, **DRAFT**, **MERGEABLE**, unmerged, with zero human reviews and zero review threads.



### QA372 final HEAD documentation verification — 13 November 2026

- Documentation HEAD `e0207bdc97dbcf029417950502c734929c562852` was validated by QIMA CI [#1347](https://github.com/meridane/QimaTrade-MVP/actions/runs/43282469525): **SUCCESS**. Both PostgreSQL 16 and 17.6 integration jobs passed, including QA369 slot and QA372 non-superuser visibility runtime probes. The Verify job passed the QA369/QA372 static contracts, npm audit at the high threshold, TypeScript, Next.js production build, Chromium, and **347 Playwright tests in 13.1 seconds**.
- CodeQL [#1296](https://github.com/meridane/QimaTrade-MVP/actions/runs/43282469560): **SUCCESS**.
- GitHub's combined status still reports Vercel **RATE LIMITED** (`build-rate-limit`); no Preview success is claimed for this HEAD.
- The run #1347 is the CI/CodeQL verification of the prior documentation-only evidence commit. No Production deployment, PR merge, or branch-protection change occurred.

