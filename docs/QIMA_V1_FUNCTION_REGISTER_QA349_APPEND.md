# QIMA V1 Function Register — QA349 append

Date: 2026-11-12 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa349-control-char-guards-v3-20261112-0352`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, **MERGEABLE**, and unmerged.
- Starting HEAD: `af1c617d1c041acdd56e99aa734e6aa3bcb6fe25`.
- Compare `main...fix/create-offer-status-contract`: **1,447 commits ahead, 0 behind, 104 changed files**.
- Latest starting commits:
  - `af1c617` — record QA348 results.
  - `edb408f` — run the CREATE_OFFER URL guard before PostgreSQL client installation.
  - `c3c9b39` — add control-character cases to the CREATE_OFFER runner guard.
- Starting QIMA CI **#1256** ([run 43074700863](https://github.com/meridane/QimaTrade-MVP/actions/runs/43074700863)) — **SUCCESS, 3/3 jobs**.
- Starting CodeQL **#1206** ([run 43074700926](https://github.com/meridane/QimaTrade-MVP/actions/runs/43074700926)) — **SUCCESS**.
- The Vercel status on the starting HEAD was **FAILURE** with `build-rate-limit`; this is independent of GitHub Actions.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched from the PR branch. GitHub returned SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` and empty content. The canonical file was not replaced; this append preserves the QA record separately.

## QA349 — extend control-character URL guard coverage

### Scope

Added four malformed `DATABASE_URL` cases to three existing shell regression suites:

1. LF followed by an injection-like marker.
2. Trailing CR.
3. Trailing TAB.
4. CRLF followed by an injection-like marker.

Coverage targets:

- `test-auxiliary-postgres-runner-guards.sh`: both the wrapper-owner regression runner and the function EXECUTE ACL runner.
- `test-legacy-messages-runner-guard.sh`: the destructive legacy migration runner and its read-only post-run database-absence assertion.
- `test-participant-self-enrollment-runner-guard.sh`: the participant self-enrollment runner.

This adds **20 mocked rejection cases** (four inputs across five guard targets). Existing seven unsafe URL cases remain in each applicable matrix.

For each malformed URL, the test verifies that the URL guard rejects before invoking `psql`, returns the expected guard status, does not expose the fixture credentials, and does not reflect the `qa349-injected` marker. The main runner checks also require a single-line diagnostic without CR or TAB characters. The legacy post-run assertion checks the same output-sanitization properties.

The mock `psql` executable is inert: it records invocation and never opens a socket. No database is contacted by these negative URL cases.

### Files changed

- `tests/sql/test-auxiliary-postgres-runner-guards.sh`
- `tests/sql/test-legacy-messages-runner-guard.sh`
- `tests/sql/test-participant-self-enrollment-runner-guard.sh`

No runner implementation, application runtime, SQL migration, database function, schema, RLS policy, grant, or workflow configuration was changed.

### Commits

- `a6627afa270aefde4b07afe139f6f6939bc57810` — extend control-character cases to auxiliary runner guards.
- `9adb5fe63601835c211a3f737d8812c03407a6c2` — cover control characters in legacy migration and post-run assertion guards.
- `61d0a42483b89c89c6b290af7021191cb5b6bb67` — cover control characters in participant self-enrollment guard.

The work branch was fast-forwarded to the PR branch after verifying that the PR head still matched the expected starting SHA. No force update was used.

## Validation

- QIMA CI **#1257** ([run 43082440979](https://github.com/meridane/QimaTrade-MVP/actions/runs/43082440979)) — **SUCCESS, 3/3 jobs**.
  - PostgreSQL 16 integration job: **28/28 steps completed**, no failed or skipped steps.
  - Typecheck, audit, build, and browser job: **19/19 steps completed**, no failed or skipped steps. npm audit, TypeScript, Next.js build, Chromium installation, and browser smoke tests passed.
  - PostgreSQL 17.6 compatibility job: **14/14 steps completed**, no failed or skipped steps.
  - The new auxiliary runner guard step passed.
  - The new legacy migration runner guard step passed, including its post-run assertion guard cases.
  - The new participant self-enrollment runner guard step passed.
- CodeQL **#1207** ([run 43082440987](https://github.com/meridane/QimaTrade-MVP/actions/runs/43082440987)) — **SUCCESS**.
- No test failures were reported in the final CI run.
- Final PR compare after the code commits: **1,450 commits ahead, 0 behind, 104 changed files**.
- Final Vercel commit status remained **FAILURE** with `Deployment rate limited — retry in 24 hours` / `api-deployments-free-per-day`. No Preview success is claimed for QA349.

### Interpretation boundary

These are synthetic negative tests using inert client stubs. They establish the tested runner behavior for the supplied malformed strings; they do not establish that a production vulnerability existed or was exploited. No claim of a confirmed vulnerability is made.

## Safety boundary

- All database URL rejection tests use a mocked `psql`; they do not open database sockets.
- Existing allowlisted loopback behavior and actual PostgreSQL integration suites were not changed.
- No Supabase Production data, migrations, functions, schema, RLS policies, grants, secrets, or persistent configuration were modified.
- No Production deployment, PR merge, force update, or branch-protection change was performed.


## Final-head validation after QA349 append publication

- The code-change commit `61d0a42483b89c89c6b290af7021191cb5b6bb67` was validated by QIMA CI **#1257** and CodeQL **#1207**, both **SUCCESS**.
- The first QA349 append commit `ff4303111aa0098265a5ec669481dd50ca5f158d` was then validated again by QIMA CI **#1258** ([run 43082789314](https://github.com/meridane/QimaTrade-MVP/actions/runs/43082789314)) — **SUCCESS, 3/3 jobs** — and CodeQL **#1208** ([run 43082789339](https://github.com/meridane/QimaTrade-MVP/actions/runs/43082789339)) — **SUCCESS**.
- CI #1258 job results: PostgreSQL 16 **28/28 steps**, browser/typecheck/audit/build **19/19 steps**, and PostgreSQL 17.6 **14/14 steps**. No failed or skipped steps were reported.
- The auxiliary, legacy migration/post-run assertion, and participant self-enrollment guard steps all passed in CI #1258.
- Vercel remained **FAILURE** on the rate limit status; no Preview success is claimed.
