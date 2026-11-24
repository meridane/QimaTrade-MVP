# QIMA V1 Function Register — QA433

## QA432 validation closure

**Target:** PR #26, `fix/create-offer-status-contract`.  
**Reviewed HEAD:** `df0639227067d0ebb014a7cfec0bd7a250fed55a`.

- QIMA CI #1890 completed **SUCCESS**.
- Browser/typecheck job `138296349768`: npm audit, TypeScript, Next.js production build, Chromium and **423/423 Playwright passed (38.3 s)**.
- PostgreSQL integration job `138296349423`: **SUCCESS**. Step 32, `Verify legacy migration runner rejects unsafe database URLs`, completed successfully; the QA432 guard script ran with its 15-entry unsafe URL matrix, including LF, CR, TAB and SOH in the credential component.
- The same PostgreSQL 16 job passed legacy messages RLS, post-run database-absence verification, real SQL failure cleanup, participant self-enrollment URL guard and participant RLS regression.
- PostgreSQL 17.6 compatibility job `138296349753`: **SUCCESS**.
- CodeQL #1818: **SUCCESS**. Vercel status: **SUCCESS**.
- The prepared-transaction simulation jobs retain their intentional failure conclusions; the corresponding assertion jobs succeeded, and the expected skipped job remained skipped.

## QA433 — reject control characters in participant self-enrollment DATABASE_URL credentials

### Finding

The participant self-enrollment runner used the same URI credential allowlist class `[^@]+` without a prior control-character check. Its guard tests covered control characters in the path, but not inside the credential component.

This is a test-runner guard-contract gap only; it is not evidence of an exploitable production vulnerability.

### Change

- `tests/sql/run-participant-self-enrollment-regression.sh` now checks the complete `DATABASE_URL` for C-locale control characters with GNU grep `-z` before evaluating the loopback/database allowlist.
- Rejection uses the existing URL-guard exit status `2`, emits a generic one-line diagnostic, and occurs before invoking `psql`.
- `tests/sql/test-participant-self-enrollment-runner-guard.sh` adds four credential-component cases: LF, CR, TAB and SOH. Together with the existing cases, the unsafe matrix contains 15 destinations.
- The diagnostic assertion now rejects any C-locale control character and still requires exactly one output line. Existing no-`psql`, no-credential-reflection, unset/empty and three supported loopback URL checks remain in place.

### Files changed

- `tests/sql/run-participant-self-enrollment-regression.sh` — reject control characters before the allowlist.
- `tests/sql/test-participant-self-enrollment-runner-guard.sh` — add four credential cases and broaden diagnostic validation.
- `docs/QIMA_V1_FUNCTION_REGISTER_QA433_APPEND.md` — this append-only QA record.

### Validation status

- Work branch: `work/qima-participant-controlchars-qa433-20261124-1722`, created from reviewed HEAD `df0639227067d0ebb014a7cfec0bd7a250fed55a`.
- Code commits: `9a9461d6bcbde52f0d9d9905a00a2f18766fdd24` (runner) and `f30b4f7a9bfdbae028df45f94b23e4f9b20252a4` (regression test).
- A local primitive check confirmed that LF, CR, TAB and SOH are detected and the three supported loopback URL strings contain no control characters. This is not a substitute for the full runner test.
- QA433 is **pending CI**. After fast-forward publication, verify the PostgreSQL step `Verify participant self-enrollment runner rejects unsafe database URLs` and the subsequent participant RLS regression on PostgreSQL 16; also confirm PostgreSQL 17.6, Playwright, CodeQL and Vercel.
- No full local shell suite is claimed.

### Limits and safety

The regression uses an inert `psql` stub for rejected destinations and checks the existing CI runner contract. It does not establish a production vulnerability.

No Supabase Production data or migrations, secrets, grants, persistent RLS policies, production deployment, merge, force-push, or branch-protection settings were changed.
