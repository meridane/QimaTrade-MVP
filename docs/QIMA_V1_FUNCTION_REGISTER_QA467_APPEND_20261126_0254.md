# QIMA Function Register — QA467 append-only update

Date: 2026-11-26 (KST)

## Scope

This entry adds a CI regression for the restore script's required-executable preflight. The test uses a minimal temporary PATH and inert command symlinks. It does not connect to Supabase Production and does not establish a production vulnerability.

## Baseline before QA467

- PR #26: https://github.com/meridane/QimaTrade-MVP/pull/26 — OPEN, not merged; head branch `fix/create-offer-status-contract`.
- Baseline PR HEAD: `1ba7de92842f4f1b495a7435b2526eaf499b39e6`.
- Compare `main...fix/create-offer-status-contract`: 2,500 commits ahead, 0 behind.
- QIMA CI #1981 completed SUCCESS on baseline HEAD: https://github.com/meridane/QimaTrade-MVP/actions/runs/45656929569
  - Typecheck/audit/build/browser job: SUCCESS.
  - npm audit, TypeScript, Next.js production build, Chromium and Playwright: SUCCESS.
  - CREATE_OFFER PostgreSQL integration tests: SUCCESS.
  - PostgreSQL 17.6 compatibility: SUCCESS.
  - Independent cleanup assertions: SUCCESS.
  - Expected-failure setup/cleanup harness jobs returned their deliberately injected failure codes; their assertion jobs passed. The skipped-result job was SKIPPED as designed.
- QIMA CodeQL #1908 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45656929512

## QA467 — dependency preflight regression

- Code/test branch: `work/qima-restore-missing-tool-preflight-qa467-20261126-0254`.
- Initial test commit: `108b2429fda78a7db09adf9302d5764571579b62`.
- Harness quoting correction: `b6c0b4157a28783834b1bd2738eb907ddf01f445`.
- Changed code/test file: `tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`.
- Three cases run the actual `tests/sql/restore-prepared-transactions-config.sh` with a minimal PATH:
  1. `psql` absent while Docker and pg_isready are discoverable.
  2. `docker` absent while psql and pg_isready are discoverable.
  3. `pg_isready` absent while psql and Docker are discoverable.
- Each case expects exit 127 and the exact dependency diagnostic. Each also verifies an empty mock event log, unchanged simulated configuration state `10`, no QA267 success marker and no credential leakage.
- The test creates temporary symlinks only; it does not alter installed tools or repository/runtime settings.

## QA467 GitHub Actions evidence

- QIMA CI #1982: https://github.com/meridane/QimaTrade-MVP/actions/runs/45669912319 — IN PROGRESS at this snapshot.
- The actual runtime job log explicitly reports: `QA467 dependency-preflight guard passed: missing psql, docker, or pg_isready returned 127 before any mock event, state change, or success marker.`
- The independent prepared-transaction cleanup assertion job completed SUCCESS.
- npm audit and TypeScript steps completed SUCCESS.
- Next.js production build was still IN PROGRESS; Chromium/Playwright and the QIMA security fixture were pending.
- PostgreSQL 16 CREATE_OFFER integration and PostgreSQL 17.6 compatibility jobs were still IN PROGRESS. No overall CI success is claimed.
- QIMA CodeQL #1909: https://github.com/meridane/QimaTrade-MVP/actions/runs/45669912261 — IN PROGRESS at this snapshot; Initialize CodeQL and Autobuild succeeded, analysis was running.
- Vercel status on the code/test commit was PENDING at the last status query.

## Publication and branch state

- The corrected code/test commits were fast-forwarded to `fix/create-offer-status-contract`; no force update was used.
- Official branch HEAD at the code publication: `b6c0b4157a28783834b1bd2738eb907ddf01f445`.
- This document is an append-only companion. The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was re-read, but GitHub's file-content endpoint returned an empty body despite a valid blob SHA; its history was not replaced.
- Final closure must be appended after CI #1982 and CodeQL #1909 reach terminal states.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- QA467 is a synthetic CI preflight contract test and does not prove a production vulnerability.
