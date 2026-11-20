# QimaTrade — append-only register note (2026-11-20 12:29 KST)

This supplement records the current run without rewriting the oversized canonical register. The canonical file remains at `docs/QIMA_V1_FUNCTION_REGISTER.md`; its Git blob SHA was readable (`ff35772854f2319d32aff3da7ed954c560ac93bc`), but the GitHub file reader returned an empty body for full, base64, and small line-range reads. A full replacement would therefore be unsafe.

## Verified starting state

- PR [#26](https://github.com/meridane/QimaTrade-MVP/pull/26): **OPEN / DRAFT / not merged**, `mergeable=true`; branch `fix/create-offer-status-contract`, base `main`.
- Starting HEAD: `6c023cc65d7afc6444954d9e927e0aa3a437ac55`; 2,068 commits ahead of `main`, 0 behind; 269 changed files, 87,149 additions, 261 deletions.
- Recent commits included `6c023cc` (CI #1678 register update), `a40e8eee` (omitted/null numeric-input fixtures), `9f147fda` (product-master test/audit triage), and `dda68d11` (product-master ID trimming).

## Closed checks on the starting HEAD

- QIMA CI [#1679](https://github.com/meridane/QimaTrade-MVP/actions/runs/44664763976): **SUCCESS**. Verify job: **397 Playwright passed (14.7 s)**; npm audit, TypeScript, Next.js build, Chromium, PostgreSQL 16 and PostgreSQL 17.6 all succeeded.
- npm audit reported **1 moderate, 0 high, 0 critical**. The workflow threshold is `--audit-level=high`; SUCCESS does not mean zero advisories. The locked Next.js version remains 15.5.28; no lockfile was changed in this run.
- CodeQL [#1610](https://github.com/meridane/QimaTrade-MVP/actions/runs/44664763935): **SUCCESS**.
- Vercel Preview status on the starting HEAD: **SUCCESS**.
- The setup-failure and cleanup-failure harness jobs intentionally conclude failure; their cleanup/propagation assertions pass. The explicit skipped-job assertion passes. These expected outcomes are not unexpected CI failures.

## New regression test

- Commit [`b75a45f2`](https://github.com/meridane/QimaTrade-MVP/commit/b75a45f2b9f9fb7f42f6fc3d276247b14168784a) extends the existing test `CREATE_OFFER route trims required name and demand IDs before action execution`.
- The test now surrounds `name` and `demandId` with ASCII whitespace plus ECMAScript-trimmable U+00A0 (NO-BREAK SPACE) and U+FEFF (BOM), then retains the existing assertions that the RPC receives the canonical values exactly once.
- This is test-only: no route/runtime/SQL behavior changed. The file remains at 71 test declarations; this extends one existing test rather than adding a new Playwright test.
- The route already calls `.trim()` for both fields. The test characterizes that existing normalization contract; it does not claim a security vulnerability.

## Validation after the new test commit

- The test commit was pushed to the PR branch by fast-forward only (`force=false`) with expected previous HEAD `6c023cc65d7afc6444954d9e927e0aa3a437ac55`.
- New test commit: `b75a45f2b9f9fb7f42f6fc3d276247b14168784a`.
- At the first post-push check, no PR workflow run was yet visible for this commit; Vercel was **PENDING**. Do not attribute the 397 passing tests from CI #1679 to this new commit until its own Playwright run completes.
- Work branch: `work/create-offer-unicode-whitespace-normalization-20261120-1229`. No local test command was run.

## Safety and next step

- No application code, SQL, migrations, Supabase Production data, secrets, grants, persistent RLS policies, production deployment, merge, force-push, workflow, or branch-protection rule was changed.
- Next: verify the new commit's Playwright/TypeScript/build and PostgreSQL 16/17.6 checks, then update this note with final results. Continue the Next.js 15.5.28 advisory triage separately; only update the lockfile after a real reproducible dependency install and full CI validation.
