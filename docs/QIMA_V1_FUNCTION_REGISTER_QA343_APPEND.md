# QIMA V1 Function Register — QA343 append

Date: 2026-11-11 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa343-jsonb-numeric-lexical-characterization-20261111-2117`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and GitHub reported it **mergeable**.
- Starting PR HEAD: `230152b782c73b73ed6dd02fb3833dfaca13fa96`.
- PR metadata: 1,420 commits, 97 changed files; base `main`.
- No submitted reviews or inline review threads were returned.
- Starting QIMA CI **#1237** ([run 43010598173](https://github.com/meridane/QimaTrade-MVP/actions/runs/43010598173)) was **SUCCESS, 3/3 jobs**.
- Starting CodeQL **#1188** ([run 43010598178](https://github.com/meridane/QimaTrade-MVP/actions/runs/43010598178)) was **SUCCESS**.
- The CI jobs confirmed PostgreSQL 16 integration, PostgreSQL 17.6 compatibility, TypeScript, npm audit, Next.js build, and Playwright completed successfully. PostgreSQL 17.6 reported `server_version_num=170006`.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but an empty content body. The canonical file was not modified or replaced.
- `docs/MKT-1.3_IDEMPOTENCY_NUMERIC_CANONICALIZATION.md`, `docs/MKT-1.2_LEGACY_DRAFT_IDEMPOTENCY_CONTRACT.md`, and the QA342 append were fetched and reviewed.

## QA343 — broader numeric lexical-form characterization

### Scope

Added `tests/sql/idempotency-numeric-lexical-characterization.sql` and wired it into `tests/sql/run-create-offer-integration.sh` immediately after the existing `create-offer-runtime.sql` suite.

The new QA315 block is read-only: it creates no tables, rows, functions, policies, or persistent state. It evaluates six equivalent numeric lexical forms:

- `1`
- `1.0`
- `1.00`
- `1e0`
- `10e-1`
- `100e-2`

It checks typed PostgreSQL `numeric`, JSONB scalar values, nested JSONB objects, and those objects inside JSONB arrays. For each family it asserts that the values compare equal while more than one textual serialization remains. It also confirms that the current MD5-over-text expression yields more than one digest for the equivalent lexical forms.

The test intentionally does not assert exact exponent rendering across PostgreSQL versions and does not choose a desired business normalization policy. It changes no existing request-hash behavior.

### Documentation

Updated `docs/MKT-1.3_IDEMPOTENCY_NUMERIC_CANONICALIZATION.md` with a QA315 section explaining the expanded matrix and its limitations.

### Work-branch commits

- `3130cc9c3ec1e581533400355f516c802669b7f0` — add the read-only SQL characterization.
- `69f0fe9e1faed19b65dc26d7a3cc190e46550aa9` — execute the new script in the disposable integration runner.
- `d1aabc9ede2ddccc7fe219ad3d7c77a43ba1b13f` — correct the psql `ON_ERROR_STOP` meta-command to one leading backslash.
- `da64d909b5d7de14d1e20fa0bb43774194b26272` — document QA315 in MKT-1.3.

The final work branch was compared with the starting PR HEAD and was **ahead by 4 commits, behind by 0** after the documentation update. (The first comparison before the MKT-1.3 documentation commit was ahead by 3.)

## Validation status at appendix creation

- The code/test HEAD `d1aabc9ede2ddccc7fe219ad3d7c77a43ba1b13f` triggered QIMA CI **#1238** ([run 43019421837](https://github.com/meridane/QimaTrade-MVP/actions/runs/43019421837)) and CodeQL **#1189** ([run 43019421839](https://github.com/meridane/QimaTrade-MVP/actions/runs/43019421839)).
- At the time of this note, CI #1238 was queued and CodeQL #1189 was in progress. No QA315 test result is claimed until both PostgreSQL compatibility jobs and the complete CI run finish.
- Vercel on the new code HEAD was **PENDING** at the last status read; no Preview success is claimed.
- The test is run only by the repository's fail-closed disposable PostgreSQL integration runner, which requires loopback `qima_test` at port 5432. It is not configured to accept a Supabase Production URL.

## Safety boundary

- QA315 characterizes serialization behavior only; it does not prove a Production defect, vulnerability, or incident.
- No application runtime code, migration, SQL function, schema, RLS policy, grant, secret, or Supabase Production data/configuration was modified or accessed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.


## QA343 — final validation on the code/test commit

The corrected QA315 script was present on code/test HEAD `d1aabc9ede2ddccc7fe219ad3d7c77a43ba1b13f`. The psql meta-command was verified to contain exactly one leading backslash. A static review confirmed the script contains no INSERT, UPDATE, DELETE, DDL, GRANT, REVOKE, or TRUNCATE statements, and the runner's fail-closed loopback `qima_test` guard precedes every database command. The new script is invoked after the main runtime suite.

- **QIMA CI #1238** ([run 43019421837](https://github.com/meridane/QimaTrade-MVP/actions/runs/43019421837)) — **SUCCESS, 3/3 jobs**.
  - PostgreSQL 16 integration job — **SUCCESS**; the CREATE_OFFER integration runner, including the QA315 script, completed successfully.
  - PostgreSQL 17.6 compatibility job — **SUCCESS**; the version assertion and CREATE_OFFER integration runner, including QA315, completed successfully.
  - Typecheck/audit/build/browser job — **SUCCESS**; npm installation, dependency audit, TypeScript, Next.js build, Chromium installation, and Playwright browser tests completed successfully.
- **CodeQL #1189** ([run 43019421839](https://github.com/meridane/QimaTrade-MVP/actions/runs/43019421839)) — **SUCCESS**.
- No test failure was reported in the completed CI jobs. The PostgreSQL 16 and PostgreSQL 17.6 runner steps both completed with success, which is the direct CI evidence for QA315.
- The code/test commit `d1aabc9` had a **successful Vercel Preview** status at the time of its status check.
- The final PR HEAD after documentation-only commits is `085dacd84fe82e9d75421b3dbe624c988a54a817`. Its Vercel combined status is **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`. This is a Preview quota status, not a GitHub CI or CodeQL failure; no retry or quota bypass was attempted.
- The two documentation commits after `d1aabc9` do not change the validated SQL or runner. The canonical register remains unmodified.

## Final PR synchronization

- Work branch `work/qa343-jsonb-numeric-lexical-characterization-20261111-2117` was fast-forwarded to `fix/create-offer-status-contract` only after comparing it with the expected prior PR HEAD and confirming it was ahead with zero commits behind.
- Final PR HEAD at the time of this note: `085dacd84fe82e9d75421b3dbe624c988a54a817`.
- PR #26 remains **OPEN**, **DRAFT**, unmerged, and GitHub reports it **mergeable**.
- Final PR metadata: 1,425 commits, 99 changed files; base `main`.
- No submitted reviews or inline review threads were returned.

## Final safety boundary

QA315 is a disposable, read-only characterization of PostgreSQL serialization. It does not choose the future numeric normalization policy and does not establish a Production defect, vulnerability, or incident. No Supabase Production data, migration, function, schema, RLS policy, grant, secret, or persistent configuration was read or modified. No Production deployment, PR merge, force update, or branch-protection change was performed.


## QA343 follow-up refinement — recursive JSONB hash assertions

After the first CI cycle, QA315 was strengthened so the nested-object and nested-array cases also calculate MD5 over their serialized JSONB text and assert at least two distinct hashes. This aligns the test assertions with the MKT-1.3 description; it still makes no claim about the desired normalization policy.

- Follow-up code/test commit: `94b05aa01c7665de28ac822317fd6b186ecbdfba`.
- The final SQL script remains read-only and has no DML or DDL statements.
- **QIMA CI #1241** ([run 43019812058](https://github.com/meridane/QimaTrade-MVP/actions/runs/43019812058)) was **IN PROGRESS** at the last check. Its three jobs had started; the PostgreSQL 16 and 17.6 CREATE_OFFER integration steps were still running. No final QA315 result is claimed for this refinement until that run completes.
- **CodeQL #1192** ([run 43019811821](https://github.com/meridane/QimaTrade-MVP/actions/runs/43019811821)) completed **SUCCESS**.
- The final PR code/test HEAD at this point is `94b05aa01c7665de28ac822317fd6b186ecbdfba`; PR #26 remains open, draft, unmerged, and mergeable.
- The latest Vercel status for this HEAD is **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`. The earlier code/test HEAD `d1aabc9` had a successful Preview; no Preview success is claimed for `94b05aa`.
