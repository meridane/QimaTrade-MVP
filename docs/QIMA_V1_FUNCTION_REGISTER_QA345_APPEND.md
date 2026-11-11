# QIMA V1 Function Register — QA345 append

Date: 2026-11-11 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa345-exact-missing-db-url-guard-assertions-20261111-2342`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and GitHub reported it **mergeable**.
- Starting PR HEAD: `a2b0201e1e136bf6c178c28555676400b92fe1f3`.
- Starting PR metadata: 1,431 commits, 100 changed files; base `main`.
- Starting CodeQL **#1196** ([run 43033036414](https://github.com/meridane/QimaTrade-MVP/actions/runs/43033036414)) — **SUCCESS**.
- Starting combined commit status showed Vercel **SUCCESS** on the prior HEAD.
- The first attempt of QIMA CI **#1245** ([run 43033036530](https://github.com/meridane/QimaTrade-MVP/actions/runs/43033036530)) — **FAILURE**. Inspection of all three failed jobs showed transient DNS resolution failures for `archive.ubuntu.com`, `azure.archive.ubuntu.com`, and `security.ubuntu.com` while installing PostgreSQL client / Playwright browser dependencies. The PostgreSQL integration assertions, npm audit, TypeScript, and Next.js build had not reported code failures before the network-dependent setup failures.
- The failed CI jobs were re-run using GitHub's failed-jobs-only retry. That retry was **IN PROGRESS** at the time this append was prepared.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested at the tail range. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but empty content. The canonical register was not replaced.

## QA345 — exact missing/empty DATABASE_URL guard assertions

### Scope

Refined `tests/sql/test-create-offer-integration-runner-guard.sh`.

The prior QA344 test verified that an unset or empty `DATABASE_URL` failed non-zero, printed a diagnostic containing the variable name, and never invoked the inert `psql` stub. That assertion could accept an unrelated non-zero exit or a generic URL-guard diagnostic.

The QA345 refinement now requires, for both unset and explicitly empty configuration:

- exact exit status **1**, matching the Bash required-variable expansion failure in the runner script;
- the exact diagnostic text `DATABASE_URL must point to a disposable PostgreSQL database`;
- an untouched `psql` call log, proving the database client was not invoked.

The seven unsafe URL cases and three supported loopback URL cases remain unchanged.

A local shell reproduction using a temporary Bash script with the same `: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"` required-variable expression returned exit status 1 for both unset and empty values. The full repository regression still requires CI execution.

### Code commit and branch synchronization

- Work-branch code commit: `b12370c06a65b3a8136906a50ca717d42e479deb` — `test(sql): assert exact missing DATABASE_URL failure`.
- The diff changes only the two missing/empty configuration assertions; it does not modify the runner or any production-facing code.
- The target branch was advanced by a non-forced fast-forward from expected prior SHA `a2b0201e1e136bf6c178c28555676400b92fe1f3` to `b12370c06a65b3a8136906a50ca717d42e479deb`.
- PR #26 remains open, draft, unmerged, and mergeable at the latest metadata read.

## Validation status at append creation

- The first attempt of CI #1245 failed because hosted-runner DNS could not resolve Ubuntu package mirrors. This is classified as an infrastructure/network failure, not a source-code regression.
- The failed-jobs-only retry of CI #1245 was still running. Its latest job view showed PostgreSQL client installation and Playwright setup in progress; no final result is claimed.
- The push of QA345 code commit `b12370c` was expected to receive its own pull-request CI run after the existing PR concurrency group became available; no run result for this new HEAD was yet returned.
- CodeQL #1196 remains **SUCCESS** for the preceding code state. A new CodeQL result for QA345 must be verified separately.
- Vercel on the preceding HEAD was **SUCCESS**; no Vercel result is claimed for QA345 yet.

## Safety boundary

- The change only tightens a shell regression test around the existing fail-closed environment-variable check.
- Missing/empty cases use the inert local `psql` stub and assert it is never invoked.
- No Supabase Production URL, credential, data, migration, function, schema, RLS policy, grant, secret, or persistent configuration was accessed or changed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
