# QIMA V1 Function Register — QA432

## QA431 validation closure

**Target:** PR #26, `fix/create-offer-status-contract`.  
**Reviewed HEAD:** `d7e448adcedf6759ab6136293c27d9e5faf3afb3`.

- PR #26 was verified OPEN / DRAFT / not merged, base `main`, mergeable, with no unresolved inline review threads.
- QIMA CI #1889: **SUCCESS**.
  - Verify job `138269818654`: npm audit, TypeScript, production build, Chromium and **423/423 Playwright passed (35.7 s)**.
  - PostgreSQL integration job `138269818497`: **SUCCESS**. The step `Verify legacy migration runner rejects unsafe database URLs` completed successfully; the script containing QA431's exact-argv assertions ran successfully. Its output ended with the QA262 assertion summary, and no argument-vector assertion failed.
  - The same PostgreSQL job passed the legacy messages RLS regression, post-run database-absence check, real SQL failure cleanup, participant self-enrollment URL guard and RLS regression.
  - PostgreSQL 17.6 compatibility job: **SUCCESS**.
  - CodeQL #1817: **SUCCESS**.
  - Vercel status: **SUCCESS**.
  - Prepared-transaction simulation jobs with intentional failure conclusions are controlled by successful assertion jobs; the expected skipped job remains skipped.
- QA431's exact six-argument `psql` vector was therefore exercised in CI #1889 on PostgreSQL 16, including localhost, IPv4 and IPv6 loopback cases. This closes the pending validation note in the QA431 entry; the earlier entry is retained as a historical snapshot.

## QA432 — reject control characters in the legacy migration runner URL credentials

### Finding

The legacy destructive runner's allowlist used `[^@]+` for the URI credential component. That character class also accepts line-feed, carriage-return, tab and other control characters. Existing guard tests covered control characters after the database path, but not inside the credential component.

This is a guard-contract gap in the CI runner input validation. It is not evidence of an exploitable production vulnerability.

### Change

- The runner uses GNU grep `-z` with a C-locale `[[:cntrl:]]` expression so the complete URI is treated as one record; LF, CR, TAB and other control characters are rejected before the loopback/database allowlist.
- The refusal remains generic and does not print `DATABASE_URL`; the runner exits with the existing URL-guard status `2` before invoking `psql`.
- The regression adds LF, CR, TAB and SOH cases inside the credential component.
- The output assertion now rejects any control character, not only CR and TAB, and still requires a single diagnostic line.
- Existing unsafe-path cases, unset/empty cases, loopback acceptance and cleanup behavior are unchanged.

### Files changed

- `tests/sql/run-legacy-messages-rls-regression.sh` — reject control characters before the allowlist.
- `tests/sql/test-legacy-messages-runner-guard.sh` — add four credential-component cases and broaden diagnostic validation.
- `docs/QIMA_V1_FUNCTION_REGISTER_QA432_APPEND.md` — this append-only QA record.

### Validation status

- Work branch: `work/qima-legacy-url-controlchars-20261124-1641`, created from reviewed HEAD `d7e448adcedf6759ab6136293c27d9e5faf3afb3`.
- QA431 is validated by QIMA CI #1889 as described above.
- QA432 is a new change and is **not yet validated by CI**. The next QIMA CI run must execute `test-legacy-messages-runner-guard.sh` in the PostgreSQL integration job and confirm all 15 unsafe destinations are rejected before the inert `psql` stub.
- No local shell run is claimed in this environment.

### Limits and safety

The test uses an inert local `psql` stub and characterizes the runner's allowlist behavior only. It does not establish a production vulnerability.

No Supabase Production data or migrations, secrets, grants, persistent RLS policies, production deployment, merge, force-push, or branch-protection settings were changed.
