# QIMA V1 Function Register — CI #1536 final evidence

**Statut : CLOSED — QIMA CI #1536 completed successfully on the exact PR HEAD `9ed446901fa3063950cbaa9e0a7be911ac434997` (17 November 2026 KST).**  
**Target :** PR #26, branch `fix/create-offer-status-contract`.  
**Evidence type :** supplemental register append; the canonical monolithic register is retained unchanged.

## PR and branch snapshot

- PR #26 is OPEN, DRAFT, MERGEABLE and UNMERGED.
- PR head and `fix/create-offer-status-contract` both resolve to `9ed446901fa3063950cbaa9e0a7be911ac434997`.
- Base `main` resolves to `0d35c13db81019867fe9929420b0a6916285fbf6`; GitHub compare reports 1,908 commits ahead and 0 behind.
- The ten most recent branch commits were inspected. The latest is the documentation commit `9ed4469`, whose parent is `9709d2e9919caef10b6b287d0c804818b78b5572`.
- No submitted review or inline review thread is recorded.

## QIMA CI #1536 — final result

[GitHub Actions run #1536](https://github.com/meridane/QimaTrade-MVP/actions/runs/43968145812) completed with overall **SUCCESS**.

| Job | GitHub job ID | Conclusion |
|---|---:|---|
| Typecheck, audit, build and browser tests | 133652914937 | SUCCESS |
| CREATE_OFFER PostgreSQL integration tests (16) | 133652914637 | SUCCESS |
| CREATE_OFFER PostgreSQL 17.6 compatibility | 133652914958 | SUCCESS |

### Verify job

- Static contract checks completed successfully, including QA315, QA330, QA332, QA370–QA373 and QA429.
- Dependency audit enforcement completed with `AUDIT_OUTCOME=success` at the configured `npm audit --audit-level=high` threshold. This records the configured gate result; it is not a claim of zero findings at every severity.
- TypeScript check and Next.js production build completed successfully.
- Playwright completed with **347 passed**.
- The log includes an Auth `ECONNRESET` diagnostic during browser execution. The browser suite still passed; this diagnostic alone is not a confirmed vulnerability or a test failure.

### PostgreSQL 16 and 17.6 runtime evidence

Both complete runtime job logs were inspected separately. Each job completed **SUCCESS** and emitted successful runtime evidence for:

- QA315 — numeric scale/exponent lexical-form characterization.
- QA330 — legacy offers INSERT RLS actor-binding regression; transaction rolled back.
- QA332 — INSERT RETURNING and synthetic actor-scoped SELECT mechanics; transaction rolled back.
- QA370–QA372 — database-local settings/default ACLs, parameter ACL and extension configuration boundaries, and non-superuser catalog visibility.
- QA391 — zero-price acceptance and exact replay.
- QA403 — changed-geography replay rejection with original persisted state preserved.
- QA427 — committed geography-default replay across two PostgreSQL sessions, preserving hash, result and all four persisted records.
- QA429 — two concurrent identical same-key requests both returned the same committed success; later replay matched it, with one row in each of the four persistence tables.

The jobs also completed the wider runner/privilege QA363–QA381 and CREATE_OFFER QA384–QA424 coverage. The logs contain expected negative SQL errors used by rejection/privilege tests; the corresponding runtime jobs still completed successfully.

### Prepared-transaction cleanup harness

- Setup-failure job `133652914980`: conclusion **failure**, expected by the negative test.
- Cleanup-failure job `133652914946`: conclusion **failure**, expected by the negative test.
- Intentionally skipped job `133652916786`: conclusion **skipped**, expected.
- Assertion jobs `133652914772`, `133652993925` and `133653004382`: all **SUCCESS**.

The negative job conclusions are intentional stimuli and are not unexpected failures of the overall CI workflow.

## CodeQL and Preview

- [QIMA CodeQL #1470](https://github.com/meridane/QimaTrade-MVP/actions/runs/43968145938), job `133652914075`: **SUCCESS**.
- Commit status API for `9ed4469`: combined status **success**; Vercel context reports “Deployment has completed”. [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/BzMdno9MMB5hk7XS4dfApbt72YiS). Preview only; no Production deployment.

## Scope and limitations

- QA330/QA332 use disposable synthetic fixtures and rollback. QA332's actor-scoped SELECT policy is test-only and does not establish live Supabase Production RLS behavior.
- All PostgreSQL runtime evidence is from disposable CI databases. It is not a Production assessment and does not establish a confirmed vulnerability.
- The authorization relationship between `demand_id` and `tenant_id` remains blocked on an approved business ownership model.
- `docs/MKT-1.2_LEGACY_DRAFT_IDEMPOTENCY_CONTRACT.md` remains **PROPOSAL ONLY — NOT APPROVED**; draft-key scope, retention, browser persistence, replay response and storage architecture require product approval.
- MKT-1.3 numeric canonicalization remains subject to a product decision; no normalization rule is inferred.
- No Production data, migration, persistent grant/RLS policy, secret or PostgreSQL configuration was changed. No Production deployment, merge, force-push or branch-protection change was performed.

## Canonical register handling

The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was identified at blob `c6368b855d8df16a572cf535f59a6707ce142af8`. The GitHub file-content connector returned an empty body for this approximately 2 MB file, including for requested line ranges. To avoid replacing the canonical register with incomplete content, this verified append is stored as a separate `QIMA_V1_FUNCTION_REGISTER_*_APPEND.md` artifact, following the repository's existing QA append-file convention. The canonical monolithic file is not claimed to have been modified in this commit.
