# QIMA V1 Function Register — QA373 Appendix

Date: 2026-11-13

## QA373 — full CREATE_OFFER runner write-privilege contract

### Scope

Characterize the complete tests/sql/run-create-offer-integration.sh flow on disposable PostgreSQL 16 and 17.6 instances. This is separate from QA372, which characterized only read-only preflight visibility.

### Intended contract

- A superuser remains supported for the ephemeral CI service.
- A non-superuser is supported when it owns the already-created qima_test database, has CREATEROLE, and can either SET ROLE into existing authenticated/anon roles or administer their memberships.
- The runner does not require CREATEDB; the CI service provisions qima_test before invoking it.
- The non-superuser fixture path creates or reuses the two client roles and grants membership to the disposable runner role so the runtime can exercise SET ROLE.
- The reverse membership direction remains forbidden by the CREATE_OFFER wrapper-owner migration: anon and authenticated must not be members of the trusted wrapper owner.
- The candidate role is deliberately not granted pg_monitor, REPLICATION, BYPASSRLS, or SUPERUSER; the full concurrency and migration path must still succeed.
- Roles that do not own qima_test, lack CREATEROLE, or cannot enter/administer existing client roles must be rejected before fixture DDL/DML.

### Runtime matrix

| Role | Database owner | CREATEROLE | Expected |
|---|---:|---:|---|
| qa373_runner | yes | yes | Full runner succeeds |
| qa373_not_owner | no | yes | Refused before preflight/fixtures |
| qa373_no_role_admin | yes | yes, but no SET/ADMIN OPTION on existing client roles | Refused before preflight/fixtures |
| qa373_no_createrole | yes | no | Refused before preflight/fixtures |

### QA373 code-validation evidence

- Final code HEAD: 40f0801cd45856197e8f60a692f0233dcebf6be6.
- QIMA CI [#1356](https://github.com/meridane/QimaTrade-MVP/actions/runs/43290307373): SUCCESS.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs both passed the full runner privilege characterization.
- The synthetic non-superuser candidate owned qima_test and had CREATEROLE, without SUPERUSER, CREATEDB, REPLICATION, BYPASSRLS, or pg_monitor membership. The complete fixture, pgcrypto installation, migration, SECURITY DEFINER wrapper, SET ROLE, and concurrency runner succeeded.
- The runtime verified role attributes false|true|false|false|false, client-role SET membership true|true, reverse membership false|false, and pg_monitor membership false.
- The three negative cases (non-owner with CREATEROLE; database owner with CREATEROLE but no SET/ADMIN OPTION on pre-existing client roles; database owner without CREATEROLE) were rejected with exit 4 before fixture changes. Catalog/data snapshots remained unchanged.
- Verify: QA373 static PASS, npm audit high-threshold PASS, TypeScript PASS, Next.js build PASS (11.0 seconds), Chromium PASS, Playwright 347/347 (13.2 seconds).
- Vercel Preview for the final code HEAD: SUCCESS at https://vercel.com/bmk1/qimatrade-mvp/9Z5ZmEt4y3pPRiTN5nvQDNTHz61K. Preview only; no Production deployment.

### QA373 CodeQL evidence

- QIMA CodeQL [#1305](https://github.com/meridane/QimaTrade-MVP/actions/runs/43290307298): SUCCESS.
- CodeQL runs #1300, #1301, #1302, #1303, #1304, and #1305 on the successive QA373 heads all completed SUCCESS.

### Safety and interpretation

All runtime roles, databases, extensions, tables, functions, and data are synthetic and confined to a disposable Docker PostgreSQL container. The test removes the entire container. No Supabase Production data, migration, secret, or persistent PostgreSQL configuration is accessed or changed.

A successful synthetic runtime characterization establishes the tested CI contract only; it does not prove that any production database role is currently overprivileged or vulnerable.

### QA372 final host-port readiness validation — 13 November 2026

- The latest QA372 code HEAD 0dce09fda2dd65d15bf30e97dbd3ca0282b00105 was validated by QIMA CI run #43283708687, run number #1350: SUCCESS.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs both passed. The QA372 non-superuser visibility runtime, including the host-side SELECT 1 readiness probe, passed on both versions.
- The Verify job passed QA369/QA372 static contracts, npm audit at the high threshold, TypeScript, Next.js production build, Chromium, and 347 Playwright tests.
- CodeQL #43283708686, run number #1299: SUCCESS.
- The earlier PostgreSQL 17.6 host-port closure in CI #1349 remains an unconfirmed transient symptom. The bounded readiness retry/diagnostic hardening passed; no root cause is asserted.
- Combined GitHub status continues to report Vercel build-rate-limit; no Preview success is claimed for this HEAD.
- PR #26 remains open, draft, mergeable, unmerged, with zero human reviews and zero review threads.


### QA373 CI correction history

- QIMA CI #1351: initial fixture delimiter and static-contract quoting defects; corrected with a tagged dollar delimiter and a rewritten static test. The audit-enforcement step did not receive a completed report after Verify stopped; this was not an npm vulnerability finding.
- QIMA CI #1352: stale preflight mocks and static contract defects; corrected to mock the read-only runner privilege query before the catalog preflight.
- QIMA CI #1353: repeat-run guard expected one psql call; corrected to expect the role-capability query followed by the read-only catalog preflight.
- QIMA CI #1354: Docker setup SQL was not passed through stdin; corrected by using docker exec -i for the setup heredoc.
- QIMA CI #1355: boolean::text assertions expected t/f rather than true/false; corrected.
- QIMA CI #1356: final full workflow SUCCESS. The expected individual failures in prepared-transaction cleanup harnesses remain intentional and their separate blocking assertions passed; the skipped harness remains skipped.

