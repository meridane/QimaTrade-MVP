# QIMA V1 Function Register — QA435

## QA434 validation closure

**Target:** PR #26, `fix/create-offer-status-contract`.  
**Reviewed HEAD:** `61011f8e88ddd053be00fd57f65e4dfd9741801d`.

- QIMA CI #1892 completed **SUCCESS** on the QA434 code commit.
- Browser/typecheck job `138352065487`: npm audit, TypeScript, Next.js production build, Chromium and **423/423 Playwright passed (37.9 s)**.
- PostgreSQL 16 integration job `138352065472`: **SUCCESS**. The dedicated auxiliary runner guard step reported: `2 runners; 15 unsafe URLs (including credential control characters) and unset/empty DATABASE_URL rejected before psql; 3 supported loopback URLs accepted per runner.` Wrapper-owner, function EXECUTE ACL, legacy messages and participant RLS regressions also passed.
- PostgreSQL 17.6 compatibility job `138352065040`: **SUCCESS**, with `server_version_num=170006`; wrapper-owner and seven-function EXECUTE ACL regressions passed.
- CodeQL #1821: **SUCCESS**. Vercel combined status on the reviewed HEAD: **SUCCESS**.
- QIMA CI #1893 on the documentation-only HEAD completed **SUCCESS**. Its expected prepared-transaction simulation failures were paired with successful assertion jobs; the cleanup skipped-result job remained intentionally skipped.

## QA435 — reject control characters in CREATE_OFFER integration URL credentials

### Finding

The full CREATE_OFFER integration runner already used a strict loopback/database allowlist, but its URI credential expression (`[^@]+`) could accept control characters in username/password components. The existing URL guard test covered control characters in the path component, not the credential components.

This is a test-runner guard-contract gap only; it is not evidence of an exploitable production vulnerability.

### Change

- `tests/sql/run-create-offer-integration.sh` now rejects C-locale control characters across the complete `DATABASE_URL` before the loopback allowlist and before any `psql` invocation. It returns the existing URL-guard status `2` with a generic single-line diagnostic.
- `tests/sql/test-create-offer-integration-runner-guard.sh` adds four credential cases: LF in the username, CR and TAB in the password, and SOH in the username.
- The diagnostic checks now also reject SOH and ensure the credential payload marker is not reflected.
- The matrix now contains 15 unsafe URL cases, plus unset, empty and whitespace-only configuration. The three supported loopback forms remain accepted only through the inert `psql` stub.

### Files changed

- `tests/sql/run-create-offer-integration.sh` — whole-URL control-character preflight before allowlist and database access.
- `tests/sql/test-create-offer-integration-runner-guard.sh` — credential-component regressions and diagnostic assertions.
- `docs/QIMA_V1_FUNCTION_REGISTER_QA435_APPEND.md` — this append-only QA record.

### Validation status

- Work branch: `work/qima-create-offer-integration-controlchars-qa435-20261124-2010`, created from reviewed HEAD `61011f8e88ddd053be00fd57f65e4dfd9741801d`.
- QA434 parent validation: CI #1892, CodeQL #1821 and Vercel all **SUCCESS**; CI #1893 (documentation-only follow-up) also **SUCCESS**.
- QA435 is **pending CI**. The CREATE_OFFER PostgreSQL 16 job must run `test-create-offer-integration-runner-guard.sh` and report all 15 unsafe URLs plus unset/empty/whitespace rejected before the inert stub, while the three supported loopback forms reach only that stub. The runtime integration tests on PostgreSQL 16 and 17.6 must remain successful.
- No full local shell suite is claimed.

### Limits and safety

The regression uses an inert `psql` stub for URL-guard cases and checks the disposable CI runner contract. It does not establish a production vulnerability.

No Supabase Production data or migrations, secrets, grants, persistent RLS policies, production deployment, merge, force-push, or branch-protection settings were changed.
