# QIMA V1 Function Register — QA347 append

Date: 2026-11-12 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa347-apt-retry-policy-20261112-0117`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and GitHub reported it **mergeable**.
- Starting PR HEAD: `8e540737f22e1a0058a92ddc4ab63da279bb52f1`.
- PR metadata: 1,438 commits and 102 changed files; base `main`; zero commits behind.
- Starting CodeQL **#1200** ([run 43047590629](https://github.com/meridane/QimaTrade-MVP/actions/runs/43047590629)) — **SUCCESS**.
- Starting QIMA CI **#1249** ([run 43047590553](https://github.com/meridane/QimaTrade-MVP/actions/runs/43047590553)) — **FAILURE**. All three jobs failed before the relevant tests: PostgreSQL client installation failed in both database jobs and Playwright Chromium dependency installation failed in the browser job. Job logs explicitly show DNS failures resolving `archive.ubuntu.com`, `azure.archive.ubuntu.com`, and `security.ubuntu.com`. The runner URL guard, PostgreSQL integration suites, and browser tests were skipped, not failed.
- The failed-jobs-only retry of CI #1248 was also checked and had completed with the same three dependency-setup failures. Its job logs show the same Ubuntu mirror DNS failures.
- The combined status on the starting PR HEAD reported Vercel **FAILURE** with `build-rate-limit`; this is separate from GitHub Actions.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but empty content. The canonical register was not replaced.
- QA346 appendix was read in full. It records the preceding whitespace-only URL guard change and the unresolved CI dependency-setup failures.

## QA347 — retry transient Ubuntu package mirror failures

### Scope

Updated `.github/workflows/ci.yml` with a runner-local APT retry configuration step in all three jobs that install operating-system dependencies:

1. `verify`, before Playwright's `install --with-deps` step;
2. `postgres-integration`, before installing `postgresql-client`;
3. `postgres17-create-offer-compatibility`, before installing `postgresql-client`.

The step writes `/etc/apt/apt.conf.d/80-qima-network-retries` with:

- `Acquire::Retries "3";`
- `Acquire::http::Timeout "30";`
- `Acquire::https::Timeout "30";`

This is a bounded retry policy for transient package-mirror connection and DNS failures. It does not disable TLS verification, change package sources, suppress apt errors, or turn failed installation steps into successes. If mirrors remain unavailable after retries, the job still fails closed.

### Implementation and correction

- `44b8c3ca9017028e0b835372c411de919b324095` — initial CI retry step in all three jobs.
- Inspection of that commit's diff found over-escaped shell backslashes in the generated YAML block. This intermediate version was not promoted to the PR branch.
- `63cc1af0aa797d3ccfbc2dce831f14aa75cb494f` — corrected the shell block to use one newline escape and valid line continuations. The corrected diff was re-read.
- A local shell execution reproduced the exact `printf` block. It emitted the three expected APT directives, and `apt-config -c /tmp/80-qima-network-retries dump` parsed and reported all three values. This is a local syntax/configuration check, not a GitHub-hosted runner result.

### Validation status

- No full repository CI result is claimed yet for QA347.
- The PR-head workflow must verify that all three retry configuration steps execute and that the PostgreSQL client / Playwright dependency installations can recover from transient mirror failures.
- The existing CI #1249 failure is classified as hosted-runner DNS/dependency setup failure, not a source-code test failure.
- CodeQL #1200 was **SUCCESS** on the starting HEAD. A CodeQL run for the updated workflow commit must be checked after publishing the branch.
- Vercel was **FAILURE** on the starting HEAD due to the team's daily deployment quota. No new Preview success is claimed.

## Safety boundary

- The change is limited to GitHub Actions runner configuration for APT retries.
- Retry count and HTTP/HTTPS timeouts are bounded; package installation failures remain blocking.
- No package repository, signing key, TLS verification, application dependency, SQL runner allowlist, or runtime behavior was changed.
- No Supabase Production URL, credential, data, migration, function, schema, RLS policy, grant, secret, or persistent Production configuration was accessed or changed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
