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
| qa373_no_createrole | yes | no | Refused before preflight/fixtures |

### Code-validation evidence

Pending the first CI run for the QA373 code HEAD.

### CodeQL evidence

Pending the first CodeQL run for the QA373 code HEAD.

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
