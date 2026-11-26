# QIMA V1 Function Register — QA431

## QA431 — exact psql argument contract for the read-only legacy migration-cleanup assertion

**Target:** PR #26, branch `fix/create-offer-status-contract`.  
**Work branch:** `work/qima-legacy-assertion-argv-contract-20261124-1542`.  
**Base HEAD reviewed:** `a13a996421d2cd011b0e06a075e046b082d866ce`.

## Initial state reviewed

- PR #26 is OPEN / DRAFT / not merged; GitHub reports `mergeable=true`.
- Current PR HEAD before QA431: `a13a996421d2cd011b0e06a075e046b082d866ce`.
- PR metadata reports 2,363 commits and 290 changed files; review submissions and inline review threads returned no outstanding items.
- QIMA CI #1888: SUCCESS.
  - Verify job 138254583254: SUCCESS; Playwright reported 423 passed (37.8 s), with npm audit, TypeScript, build and Chromium checks successful.
  - PostgreSQL integration job 138254583381: SUCCESS; the log confirms the legacy migration runner guard, the read-only cleanup assertion, unset/empty DATABASE_URL rejection, and the real disposable-database cleanup regressions.
  - PostgreSQL 17.6 job 138254582977: SUCCESS.
  - CodeQL #1816: SUCCESS.
  - Vercel status on the HEAD: SUCCESS.
  - Prepared-transaction setup/cleanup simulation jobs intentionally conclude failure; their assertion jobs succeed. The explicitly skipped cleanup job is expected. Overall QIMA CI #1888 is SUCCESS.

## Finding and change

- The read-only assertion script invokes `psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc "<query>"`.
- The existing stub recorded `"$*"`, which flattened the argument vector into one string. The test checked that the query text appeared, but did not independently verify argument boundaries, order, or that exactly one invocation occurred.
- QA431 changes the stub to record one argument per line.
- A new assertion compares the exact six-argument vector for the localhost, IPv4 loopback, and IPv6 loopback cases:
  1. the expected disposable `DATABASE_URL`;
  2. `-X`;
  3. `-v`;
  4. `ON_ERROR_STOP=1`;
  5. `-Atqc`;
  6. the exact `pg_database` count query.
- The exact argument count also rejects additional or repeated invocations.
- Failure diagnostics report only the scenario and argument index; they do not print the URL or captured arguments.
- Existing assertions for unset/empty URLs, unsafe destinations, result handling, query failure propagation, and credential redaction remain intact.

## Files changed

- `tests/sql/test-legacy-messages-runner-guard.sh` — exact psql argv regression only.
- `docs/QIMA_V1_FUNCTION_REGISTER_QA431_APPEND.md` — append-only register entry.

No runner implementation, SQL fixture, migration, application code, Supabase data, grants, or persistent RLS policies were changed.

## Validation status

- GitHub commit `683956d1aec7f3ecc58c288abe3fe3e5b745cd9a` contains the test-only change.
- The work branch was created from the reviewed PR HEAD and is one commit ahead before this documentation entry.
- The prior CI #1888 results validate the base HEAD and QA430; they do **not** validate the new QA431 assertion.
- No local shell execution was available in this run. After the work branch is fast-forwarded to the PR branch, inspect the new GitHub Actions run and confirm the exact-argv assertions in the PostgreSQL 16 job before marking QA431 validated.

## Limits and safety

- The stub is inert and the regression characterizes command construction in CI; it does not prove an exploitable production vulnerability.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` is 2,840,776 bytes and GitHub's file reader returns an empty body despite a valid blob SHA. It is not safe to replace a file of that size without a readable full copy. This QA entry therefore uses an append-only companion file and leaves the canonical blob untouched.
- No Supabase Production data or migrations, secrets, grants, persistent RLS policies, production deployment, merge, force-push, or branch-protection settings were changed.
