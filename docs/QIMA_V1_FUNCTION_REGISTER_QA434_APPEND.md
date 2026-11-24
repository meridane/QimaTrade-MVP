# QIMA V1 Function Register — QA434

## QA433 validation closure

**Target:** PR #26, `fix/create-offer-status-contract`.  
**Reviewed HEAD:** `36b56e60a91eb461892600821831faa544aabd15`.

- QIMA CI #1891 completed **SUCCESS**.
- Browser/typecheck job `138313748943`: npm audit, TypeScript, Next.js production build, Chromium and **423/423 Playwright passed (37.1 s)**.
- PostgreSQL 16 integration job `138313749382`: **SUCCESS**. The participant self-enrollment runner URL guard reported: `15 unsafe URLs plus unset/empty DATABASE_URL rejected before psql; 3 supported loopback URLs accepted.` The participant RLS regression also completed successfully.
- PostgreSQL 17.6 compatibility job `138313749304`: **SUCCESS**, with `server_version_num=170006`.
- CodeQL #1819: **SUCCESS**. Vercel status: **SUCCESS**.
- Prepared-transaction simulation jobs retain their intentional failure conclusions; the corresponding assertion jobs succeeded, and the expected skipped job remained skipped.

## QA434 — reject control characters in auxiliary PostgreSQL runner credentials

### Finding

The wrapper-owner and function EXECUTE ACL regression runners used the loopback allowlist expression `[^@]+` for URI credentials without first rejecting control characters. Their shared guard test covered control characters in the path but not in the username/password components.

This is a test-runner guard-contract gap only; it is not evidence of an exploitable production vulnerability.

### Change

- `tests/sql/run-create-offer-wrapper-owner-regression.sh` now rejects C-locale control characters across the complete `DATABASE_URL` before the loopback allowlist and before any `psql` call.
- `tests/sql/run-function-execute-acl-regression.sh` applies the same preflight and returns the existing URL-guard exit status `2` with a generic one-line diagnostic.
- `tests/sql/test-auxiliary-postgres-runner-guards.sh` adds four credential-component cases: LF in the username, CR and TAB in the password, and SOH in the username. The matrix now contains 15 unsafe URLs for each of the two runners.
- Diagnostic validation now rejects every C-locale control character, requires one output line, and checks that both the existing path payload and new credential payload markers are not reflected.
- Existing unset/empty checks, 11 prior unsafe URL cases, and the three supported loopback URL forms remain covered.

### Files changed

- `tests/sql/run-create-offer-wrapper-owner-regression.sh` — reject control characters before the allowlist.
- `tests/sql/run-function-execute-acl-regression.sh` — reject control characters before the allowlist.
- `tests/sql/test-auxiliary-postgres-runner-guards.sh` — extend both runner matrices and diagnostic assertions.
- `docs/QIMA_V1_FUNCTION_REGISTER_QA434_APPEND.md` — this append-only QA record.

### Validation status

- Work branch: `work/qima-aux-controlchars-qa434-20261124-1836`, created from reviewed HEAD `36b56e60a91eb461892600821831faa544aabd15`.
- QA433 parent validation: CI #1891, CodeQL #1819 and Vercel all **SUCCESS**.
- QA434 is **pending CI**. After publication, verify the auxiliary runner guard step in PostgreSQL 16 and 17.6. Each runner must reject all 15 unsafe URLs, unset and empty configuration before the stub is called, and accept the three loopback forms only through the inert stub.
- No full local shell suite is claimed.

### Limits and safety

The regression uses an inert `psql` stub for rejected destinations and checks the existing CI runner contract. It does not establish a production vulnerability.

No Supabase Production data or migrations, secrets, grants, persistent RLS policies, production deployment, merge, force-push, or branch-protection settings were changed.
