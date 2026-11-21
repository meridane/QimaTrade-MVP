# QIMA V1 Function Register — security fixture supplement

Date: 2026-11-21 16:10 KST  
Repository: `meridane/QimaTrade-MVP`  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Base HEAD: `bbb8f367ee73124baa1672b08bbdd665a7842391`

## Previous validation closed

- QIMA CI [#1751](https://github.com/meridane/QimaTrade-MVP/actions/runs/44870534997): **SUCCESS**.
- Verify job: npm audit (0 high / 0 critical; 1 moderate), TypeScript, Next.js build, Chromium, **404/404 Playwright tests**, and isolated QIMA security-contract fixture all **SUCCESS**.
- The isolated fixture step reported `PASS: local QIMA security-contract fixture assertions completed.`
- PostgreSQL integration jobs: PostgreSQL 16 **SUCCESS** and PostgreSQL 17.6 **SUCCESS**.
- CodeQL [#1681](https://github.com/meridane/QimaTrade-MVP/actions/runs/44870534966): **SUCCESS**.
- Vercel commit status for the validated HEAD: **SUCCESS**.
- The prepared-transaction setup/cleanup simulation jobs have expected negative conclusions; their blocking assertion jobs succeeded. The intentionally skipped harness is expected and separately asserted.

## Regression gap and change prepared

The previous RLS fixture checked that each synthetic user saw exactly one row per table. Cardinality alone does not establish that the visible row belongs to that user: an incorrectly scoped policy could expose the other tenant's single row and still satisfy a count of one.

The next test commit strengthens `supabase/fixtures/qima_security_contract_tests.sql` for both User A and User B. For each of the five fixture tables (memberships, sessions, observations, transitions, product_requests), it now asserts:
- the exact expected row identifier is visible;
- the row's tenant and actor/owner relationship match the active synthetic identity;
- the other tenant's corresponding row is not visible;
- the existing exact-one-row count remains in place.

This is a test-only strengthening of the disposable PostgreSQL fixture. The fixture's policies, schema, production migrations, and application runtime are unchanged.

## Validation status

The new SQL assertions and documentation are being committed on an isolated work branch based on the verified PR HEAD. Their CI result is **not yet available** at the time this supplement is created; no pass is claimed for the new assertions. The next PR-head push is expected to trigger QIMA CI and CodeQL.

## Evidence boundary and safety

These checks use only synthetic UUIDs and a disposable PostgreSQL container. They characterize the fixture's declared policy model; they do not prove deployed Supabase Production grants or RLS behavior and do not establish a vulnerability.

No local test was run in this execution. No Supabase Production data, migration, secret, grant, or persistent RLS policy was changed. No production deployment, PR merge, force-push, or protection-rule change was performed.
