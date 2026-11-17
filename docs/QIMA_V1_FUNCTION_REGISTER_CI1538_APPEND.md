# QIMA V1 Function Register — CI #1538 final evidence

**Status: CLOSED — QIMA CI #1538 completed successfully on PR HEAD `3cbeb8cd16b309b2be9e771931afe82f39ba54ec` (17 November 2026 KST).**  
**Target:** PR #26, branch `fix/create-offer-status-contract`.  
**Evidence type:** supplemental register append; the canonical monolithic register is retained unchanged by this commit.

## PR and branch snapshot

- PR #26 is OPEN, DRAFT, MERGEABLE and UNMERGED.
- At evidence collection, PR #26 and `fix/create-offer-status-contract` both resolved to `3cbeb8cd16b309b2be9e771931afe82f39ba54ec`.
- The previous evidence commit is `3cbeb8cd16b309b2be9e771931afe82f39ba54ec`, parent `935a5acb71c5e08642882e891155a7fa76486612`.
- GitHub compare reports `main` as the merge base, 1,910 commits ahead and 0 behind; the PR reports 264 changed files.
- No submitted review or inline review thread is recorded.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched at the branch and by line range; the content endpoint returned an empty body (blob SHA `c6368b855d8df16a572cf535f59a6707ce142af8`). Existing CI #1536 and #1537 supplemental append files are readable. This append follows that established convention and does not claim to modify the monolithic register.

## QIMA CI #1538 — final result

[GitHub Actions run #1538](https://github.com/meridane/QimaTrade-MVP/actions/runs/43986775077) completed with overall **SUCCESS**.

| Job | GitHub job ID | Conclusion |
|---|---:|---|
| Typecheck, audit, build and browser tests | 133716844638 | SUCCESS |
| CREATE_OFFER PostgreSQL integration tests (16) | 133716844634 | SUCCESS |
| CREATE_OFFER PostgreSQL 17.6 compatibility | 133716844348 | SUCCESS |

### Verify job

- Static contract checks passed, including QA315, QA330, QA332, QA366–QA381 and QA384–QA429 contract guards.
- Dependency audit enforcement completed with `AUDIT_OUTCOME=success` at the configured `npm audit --audit-level=high` threshold. This records the configured gate result and is not a claim of zero findings at every severity.
- TypeScript check and Next.js production build completed successfully.
- Playwright completed with **347 passed**.
- The log includes an Auth `ECONNRESET` diagnostic during browser execution. The browser suite still passed; this diagnostic alone is not a confirmed vulnerability or a test failure.

### PostgreSQL 16 and 17.6 runtime evidence

Both complete runtime job logs were inspected separately. Each job completed **SUCCESS** and emitted successful runtime evidence for:

- QA315 — numeric scale/exponent lexical-form characterization.
- QA330 — legacy offers INSERT RLS actor-binding regression; transaction rolled back.
- QA332 — INSERT RETURNING and synthetic actor-scoped SELECT mechanics; transaction rolled back.
- QA363/QA373 — safe second-runner rejection and database-owner/CREATEROLE runner boundaries.
- QA366–QA372 — extension-aware catalog objects, replication slots, database-local settings/default ACLs, parameter ACL boundaries, and non-superuser catalog visibility.
- QA374–QA381 — role membership, SET/ADMIN OPTION, indirect SET chains, and CREATEROLE self-grant semantics.
- QA384 — negative-Infinity quantity/price and NaN price rejection without persisted side effects.
- QA391 — zero-price acceptance and exact replay without duplicate rows.
- QA403 — changed-geography replay rejection with original hash, result, execution, offer and success event preserved.
- QA427 — committed geography-default replay across two PostgreSQL sessions, preserving hash, result and all four persisted records.
- QA428 — a changed-payload request queued behind a committed same-key success is rejected with `IDEMPOTENCY_KEY_REUSE`, preserving the original four-table state.
- QA429 — two concurrent identical same-key requests return the same committed success; later replay matches it, with one row in each of the four persistence tables.

The jobs also completed auxiliary runner guards, legacy-offer RLS mechanics, wrapper-owner/EXECUTE ACL checks, legacy-messages RLS regressions, participant self-enrollment regressions, and disposable-database cleanup checks. Expected negative SQL errors are test stimuli; both PostgreSQL runtime jobs completed successfully.

### Prepared-transaction cleanup harness

- Job `133716844420`: expected failure stimulus; setup failed and cleanup failure was observed (cleanup exit code 52). The harness assertion job `133716892249` completed **SUCCESS**, confirming the failure marker was preserved and no success marker was emitted.
- Job `133716844680`: expected setup-failure stimulus; setup failed, but the always-cleanup restore ran successfully (exit code 0). Assertion job `133716894083` completed **SUCCESS**.
- Job `133716846452`: intentionally **SKIPPED**. Assertion job `133716845248` completed **SUCCESS**, confirming skipped cleanup is not treated as success.
- These expected negative/skipped conclusions do not represent an unexpected failure of CI #1538.

## CodeQL and Preview

- [QIMA CodeQL #1472](https://github.com/meridane/QimaTrade-MVP/actions/runs/43986775062), job `133716843422`: **SUCCESS**. Initialize, Autobuild, analysis and post-analysis steps all completed successfully.
- Commit status API for `3cbeb8cd`: Vercel context reports **success**. [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/D5p6MbAJbf81nbiYXoVo2P6AYQzG). Preview only; no Production deployment.

## Scope and limitations

- QA330/QA332 use disposable synthetic fixtures and rollback. QA332's actor-scoped SELECT policy is test-only and does not establish live Supabase Production RLS behavior.
- All PostgreSQL runtime evidence is from disposable CI databases. It is not a Production assessment and does not establish a confirmed vulnerability.
- The authorization relationship between `demand_id` and `tenant_id` remains blocked on an approved business ownership model.
- `docs/MKT-1.2_LEGACY_DRAFT_IDEMPOTENCY_CONTRACT.md` remains **PROPOSAL ONLY — NOT APPROVED**; draft-key scope, retention, browser persistence, replay response and storage architecture require product approval.
- MKT-1.3 numeric canonicalization remains subject to a product decision; no normalization rule is inferred.
- No Production data, migration, persistent grant/RLS policy, secret or PostgreSQL configuration was changed. No Production deployment, merge, force-push or branch-protection change was performed.

## Canonical register handling

The canonical monolithic register was not overwritten because the GitHub file-content connector returned an empty body, including for a requested line range. The existing CI #1536 and CI #1537 append files were readable and establish the repository's supplemental append convention. This verified CI #1538 evidence is therefore stored separately as `QIMA_V1_FUNCTION_REGISTER_CI1538_APPEND.md`; the canonical file is not claimed to have been modified.
