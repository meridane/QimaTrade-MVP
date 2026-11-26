# QIMA V1 Function Register — QA348 append

Date: 2026-11-12 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa348-control-character-runner-guard-v2-20261112-0301`

## Starting-state verification

- PR #26 was **OPEN**. Its current description still identifies it as a draft for review; it remains unmerged.
- Starting PR branch HEAD: `7b165eae1b7c820fdc7a311526335795d952cfd8`.
- Compare `main...fix/create-offer-status-contract`: **1,444 commits ahead, 0 behind** before QA348.
- Starting CodeQL **#1204** ([run 43057441316](https://github.com/meridane/QimaTrade-MVP/actions/runs/43057441316)) — **SUCCESS**.
- Starting QIMA CI **#1253** ([run 43057441392](https://github.com/meridane/QimaTrade-MVP/actions/runs/43057441392)) — **FAILURE**. PostgreSQL 17.6 client installation and Playwright OS dependency installation failed with repeated DNS resolution failures for `archive.ubuntu.com`, `azure.archive.ubuntu.com`, and `security.ubuntu.com`; the PostgreSQL 16 job was cancelled. Relevant SQL/browser tests were skipped, not failed.
- The preceding CI #1250 ([run 43057146217](https://github.com/meridane/QimaTrade-MVP/actions/runs/43057146217)) had the same dependency setup failures. Its completed npm audit, TypeScript, and Next.js build steps passed.
- The APT retry configuration from QA347 was present, but the failed logs show it did not guarantee recovery on those attempts.
- The combined status on the starting HEAD reported Vercel **FAILURE** with `build-rate-limit`; this is separate from GitHub Actions.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` with empty content. The canonical register was not replaced. The QA347 append was read in full.

## QA348 — reject control characters in DATABASE_URL

### Scope

Updated `tests/sql/test-create-offer-integration-runner-guard.sh` with four additional malformed URL cases:

1. A newline followed by an injection-like marker.
2. A trailing carriage return.
3. A trailing tab.
4. A CRLF pair followed by an injection-like marker.

For every unsafe URL case, the existing inert `psql` stub verifies that the runner exits with status 2 before any database client call. The test also verifies:

- The refusal diagnostic remains one line.
- The diagnostic contains no carriage return or tab.
- The injected marker is not reflected in output.
- Database credentials are not reflected in output.
- The runner's static loopback allowlist behavior remains unchanged.

The final test summary derives the unsafe URL count from the Bash array rather than hard-coding it. The suite now reports **11 unsafe URL cases**, plus whitespace-only and missing/empty configuration cases, with three supported loopback forms accepted by the guard and stopped by the inert client stub.

### CI ordering improvement

Updated `.github/workflows/ci.yml` to run the pure shell DATABASE_URL guard regression immediately after the APT retry configuration and before installing the PostgreSQL client in the PostgreSQL 16 job.

This ordering is intentional: the guard test uses its own mock `psql` and does not require the real PostgreSQL client or a database socket. It can therefore provide a meaningful result even if a later package installation is blocked by runner network infrastructure. The actual SQL integration tests remain after the real client installation and remain blocking.

### Commits

- `c3c9b396911c7d48517b64d7ee6031019686a3f7` — add control-character URL cases, output-sanitization assertions, and dynamic summary.
- `edb408fa4b270dfc0a84fe63f1e4c098bd872dfc` — move the database URL guard step before PostgreSQL client installation.

## Validation

- QIMA CI **#1255** ([run 43074285495](https://github.com/meridane/QimaTrade-MVP/actions/runs/43074285495)) — **SUCCESS, 3/3 jobs**.
- The PostgreSQL 16 job completed **28/28 steps**. Its log explicitly reports: `11 unsafe URL cases (including control characters), whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted.` All CREATE_OFFER integration/concurrency, RLS, ACL, legacy migration cleanup, prepared-transaction cleanup, and participant self-enrollment checks completed successfully.
- The PostgreSQL 17.6 job completed **14/14 steps**. The log reports `server_version_num=170006`; CREATE_OFFER integration/concurrency, RLS, wrapper-owner/membership, and EXECUTE ACL checks passed.
- The browser job completed successfully: npm install, npm audit, TypeScript, Next.js production build, Chromium installation, and browser smoke tests all passed. Playwright reported **347 passed (12.8s)**.
- CodeQL **#1205** ([run 43074285360](https://github.com/meridane/QimaTrade-MVP/actions/runs/43074285360)) — **SUCCESS**.
- No failed or skipped steps were present in the final CI #1255 jobs.
- Vercel status was still **PENDING** at the final combined-status inspection; no Preview success is claimed for QA348.
- A local full-repository execution was not available because this execution environment could not resolve `raw.githubusercontent.com`. The exact committed regression was executed by the GitHub Actions PostgreSQL 16 job and passed.

## Safety boundary

- QA348 changes only a test script and the order of one existing CI step.
- The mock client prevents the guard test from opening a database socket.
- The accepted loopback URLs are only allowed through the validation guard and then stop at the mock `psql` with its sentinel exit code.
- No application runtime code, SQL migration, database function, schema, RLS policy, grant, secret, or Supabase Production data/configuration was changed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
