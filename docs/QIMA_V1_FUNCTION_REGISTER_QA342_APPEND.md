# QIMA V1 Function Register — QA342 append

Date: 2026-11-11 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa342-idempotency-numeric-canonicalization-20261111-2011`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and GitHub reported it **mergeable**.
- Starting PR HEAD: `d751c514c7096f83b4312223eaf7f639c5a11458`.
- PR metadata: 1,417 commits, 95 changed files; base `main`.
- No submitted reviews or inline review threads were returned by GitHub.
- Starting QIMA CI **#1235** ([run 43006704624](https://github.com/meridane/QimaTrade-MVP/actions/runs/43006704624)) was **SUCCESS, 3/3 jobs**. The PostgreSQL 16 integration, PostgreSQL 17.6 compatibility, and typecheck/audit/build/browser jobs all completed successfully.
- Starting CodeQL **#1186** ([run 43006704614](https://github.com/meridane/QimaTrade-MVP/actions/runs/43006704614)) was **SUCCESS**.
- CI #1235 job details confirmed the CREATE_OFFER runtime/concurrency suite, legacy-offer RLS mechanics, wrapper-owner checks, function EXECUTE ACL checks, legacy-message RLS cleanup checks, participant self-enrollment regressions, TypeScript, npm audit, Next.js build, and Playwright all passed. PostgreSQL 17.6 reported `server_version_num=170006`.
- Vercel combined status on the starting HEAD was **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but an empty content body (zero characters). The canonical file was not modified or replaced.
- The QA341 appendix and MKT-1.2 proposal were fetched and read successfully.

## QA342 — numeric canonicalization in idempotency request hashes

### Evidence reviewed

- Branch migration: `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`.
- Disposable integration suite: `tests/sql/create-offer-runtime.sql`.
- Existing numeric-scale characterization cases:
  - **OFFER-QA-73**: `p_input` JSONB numeric `1` versus `1.0`.
  - **OFFER-QA-74**: typed `p_quantity` `2` versus `2.0`, and typed `p_price` `12` versus `12.0`.
  - **OFFER-QA-75**: nested `p_attributes` JSONB numeric `1` versus `1.0`.
- In each characterization, PostgreSQL JSONB/numeric equality considers the numeric values equal, but the text serialization retains scale. The MD5 values therefore differ, and replaying a completed key with the alternate scale is expected by the current fixture to raise `IDEMPOTENCY_KEY_REUSE`.
- Existing tests also cover object-key order, significant array order, SQL NULL/default behavior, empty values, and independent optional-parameter hash participation.

### Finding and interpretation

The current branch hash is computed from `jsonb_build_object(... )::text`. It is deterministic for the tested values but is not scale-insensitive for numerics. The new MKT-1.2 proposal requires a canonical payload hash but did not yet define whether formatting-only numeric scale changes represent the same effective business request.

This is a contract ambiguity, not a confirmed defect or vulnerability. The cited QA73–QA75 tests are synthetic disposable-PostgreSQL characterizations and do not establish Production behavior or impact.

### Documentation change

Created `docs/MKT-1.3_IDEMPOTENCY_NUMERIC_CANONICALIZATION.md` as a proposal/decision note. It records:

- the exact current behavior characterized by QA73–QA75;
- the distinction between PostgreSQL numeric/JSONB equality and textual hash serialization;
- decisions required for typed quantity, typed price, nested JSONB numbers, SQL NULL/JSON null/empty values, and array ordering;
- compatibility concerns if hash serialization is changed while completed idempotency records exist;
- a disposable regression acceptance matrix and an implementation gate.

No canonicalization policy is selected. No digest algorithm change is proposed as an approved action. No application code, SQL function, migration, schema, RLS policy, grant, or Production configuration was changed.

## Validation after each documentation change

- Work branch was created from exact starting PR HEAD `d751c514c7096f83b4312223eaf7f639c5a11458`.
- Contract note commit: `a78c173ab7315c1761a3f4385a28f195eb57b808`.
- The contract note was fetched back from the work branch and verified: 6,757 characters; blob SHA `6d1e9c49246b9bb45ddb12d982f7f881a489ae01`.
- Workflow-run lookup for the documentation-only contract commit returned no PR-triggered CI or CodeQL runs. This matches the workflow `paths-ignore: docs/**` behavior for push events.
- Combined Vercel status for that work-branch commit was **PENDING** at the check time. It is not reported as a successful Preview.
- The last completed code validation before this documentation change remains CI #1235 (3/3 jobs, 347/347 Playwright) and CodeQL #1186 on unchanged code HEAD `d751c514c7096f83b4312223eaf7f639c5a11458`.
- No test is claimed as newly passing in QA342; this is a documentation-only contract clarification.

## Safety boundary

- Numeric-scale behavior is reported only as characterized by disposable tests.
- No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was read or modified.
- No Production deployment, PR merge, force update, or branch-protection change was performed.


## QA342 — final PR synchronization validation

After the two QA342 documentation files were fast-forwarded to PR #26, GitHub ran the full PR workflows on HEAD `5744caff77cbade6702d463d21e699829777b746`.

- **QIMA CI #1236** ([run 43010248900](https://github.com/meridane/QimaTrade-MVP/actions/runs/43010248900)) — **SUCCESS, 3/3 jobs**.
  - Browser/build job: **347/347 Playwright tests passed, 0 failed**. npm ci, npm audit enforcement, TypeScript, Next.js build, Chromium installation, and browser tests all completed successfully.
  - PostgreSQL 16 integration job: **SUCCESS**.
  - PostgreSQL 17.6 compatibility job: **SUCCESS**; version guard reported `server_version_num=170006`.
  - The PostgreSQL 17.6 logs explicitly report the OFFER-QA-73, OFFER-QA-74, and OFFER-QA-75 numeric-scale characterization assertions passed. Existing request-hash, replay, concurrency, RLS, wrapper-owner, and ACL regression steps also passed.
- **CodeQL #1187** ([run 43010249018](https://github.com/meridane/QimaTrade-MVP/actions/runs/43010249018)) — **SUCCESS**.
- The PostgreSQL logs contain expected error output from negative assertions and rollback/cleanup scenarios. All corresponding jobs concluded successfully; these lines are not reported as test failures.
- Vercel on the final PR HEAD returned **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`. No retry or quota bypass was attempted.
- QA342 changed documentation only. CI #1236 and CodeQL #1187 validate the unchanged application/test code together with the PR synchronization event; no new QA342 application or database test is claimed.
- PR #26 remained **OPEN**, **DRAFT**, unmerged, and mergeable after GitHub recalculated the branch metadata. No reviews or inline review threads were returned.

