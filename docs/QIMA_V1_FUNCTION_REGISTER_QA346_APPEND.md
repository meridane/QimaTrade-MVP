# QIMA V1 Function Register — QA346 append

Date: 2026-11-12 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa346-whitespace-database-url-guard-20261112-0019`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and GitHub reported it **mergeable**.
- Starting PR HEAD: `2c6bec0f89a498e82f52ad6a814d92a3d5f03689`.
- PR metadata: 1,434 commits, 101 changed files; base `main`; zero behind.
- Starting CodeQL **#1199** ([run 43041400979](https://github.com/meridane/QimaTrade-MVP/actions/runs/43041400979)) — **SUCCESS**.
- Starting QIMA CI **#1248** ([run 43041401460](https://github.com/meridane/QimaTrade-MVP/actions/runs/43041401460)) — **FAILURE**. All three jobs stopped during dependency setup: PostgreSQL client installation on both database runners and Playwright browser/system-dependency installation on the browser runner. Job logs explicitly show repeated DNS resolution failures for `archive.ubuntu.com`, `azure.archive.ubuntu.com`, and `security.ubuntu.com`; the SQL guard test and Playwright tests were skipped, not failed.
- GitHub's failed-jobs-only retry was requested for CI #1248. At the time of this append, all three retried jobs were **IN_PROGRESS**, with no new failure visible.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but empty content for both the opening and tail ranges. The canonical register was not replaced.
- Existing QA345 appendix was read in full and confirms that the previous code commit's full CI / CodeQL validation had not yet been established.

## QA346 — whitespace-only DATABASE_URL rejection

### Scope

Extended `tests/sql/test-create-offer-integration-runner-guard.sh` with one non-empty but whitespace-only configuration case:

```bash
DATABASE_URL="   " bash "$RUNNER"
```

The existing runner first requires the variable to be set and non-empty, then applies a strict allowlist for loopback `qima_test` URLs. Whitespace therefore passes the required-variable expansion but must be rejected by the URL allowlist with exit status **2**.

The new assertion requires:

- exact exit status **2**;
- the full loopback safety diagnostic: `Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted.`;
- an untouched inert `psql` call log, proving no database client invocation.

The existing seven unsafe URL cases, two unset/empty cases, and three supported loopback cases remain unchanged. The test's final summary now explicitly reports the whitespace-only case.

A follow-up edit preserves the mock client's line-delimited call log format (`printf '%s\n'`); this avoids changing the test fixture's output format while adding the new assertion.

### Code commits

- `42a1296e74fb134d622afff5ea86a8347bbb86eb` — `test(sql): reject whitespace-only disposable database URL`.
- `2215069dc149625961fae6533b02666a96de13a8` — `test(sql): preserve line-delimited psql call log`.

The change is test-only. It does not alter the runner's allowlist, migrations, SQL functions, schema, policies, grants, or application behavior.

### Validation status

- The exact test was added to the existing PostgreSQL integration-runner guard step, so the PR CI will execute it before any real `psql` call.
- No local full-repository execution is claimed in this run.
- The failed-jobs-only retry of prior CI #1248 was still **IN_PROGRESS** when checked; no final retry result is claimed.
- The new QA346 PR-head CI and CodeQL runs must be inspected after the target branch is advanced. No QA346 CI success is claimed in this append.
- The previous CI #1248 failure is classified as hosted-runner DNS/dependency setup failure, not as a source-code test failure.

## Safety boundary

- The whitespace case uses the existing inert `psql` stub; no socket is opened.
- The runner remains fail-closed: unset/empty values exit at the required-variable check; non-empty malformed values are rejected by the strict loopback allowlist.
- No Supabase Production URL, credential, data, migration, function, schema, RLS policy, grant, secret, or persistent configuration was accessed or changed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
