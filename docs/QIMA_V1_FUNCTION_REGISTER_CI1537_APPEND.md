# QIMA V1 Function Register — CI #1537 final evidence

**Status: CLOSED — QIMA CI #1537 completed successfully on PR HEAD `935a5acb71c5e08642882e891155a7fa76486612` (17 November 2026 KST).**  
**Target:** PR #26, branch `fix/create-offer-status-contract`.  
**Evidence type:** supplemental register append; the canonical monolithic register is retained unchanged by this commit.

## PR and branch snapshot

- PR #26 is OPEN, DRAFT, MERGEABLE and UNMERGED.
- PR body identifies `935a5acb71c5e08642882e891155a7fa76486612` as the documentation HEAD; the target branch exists and GitHub compare reports `main` as the merge base, 1,909 commits ahead and 0 behind.
- Base `main` resolves to `0d35c13db81019867fe9929420b0a6916285fbf6`.
- The latest commit is `docs(qima): record final CI 1536 evidence`; its preceding evidence commit is `9ed446901fa3063950cbaa9e0a7be911ac434997`.
- No submitted review or inline review thread is recorded.

## QIMA CI #1537 — final result

[GitHub Actions run #1537](https://github.com/meridane/QimaTrade-MVP/actions/runs/43977934630) completed with overall **SUCCESS**.

| Job | GitHub job ID | Conclusion |
|---|---:|---|
| Typecheck, audit, build and browser tests | 133686629882 | SUCCESS |
| CREATE_OFFER PostgreSQL integration tests (16) | 133686630006 | SUCCESS |
| CREATE_OFFER PostgreSQL 17.6 compatibility | 133686630115 | SUCCESS |

### Verify job

- Static contract checks passed, including QA315, QA330, QA332, QA360–QA361, QA366–QA381, QA382–QA429 and the associated runner guards.
- Dependency audit enforcement completed with `AUDIT_OUTCOME=success` at the configured `npm audit --audit-level=high` threshold. This records the configured gate result; it is not a claim of zero findings at every severity.
- TypeScript check and Next.js production build completed successfully.
- Playwright completed with **347 passed**.
- The log includes an Auth `ECONNRESET` diagnostic during browser execution. The browser suite still passed; this diagnostic alone is not a confirmed vulnerability or a test failure.

### PostgreSQL 16 and 17.6 runtime evidence

Both complete runtime job logs were inspected separately. Each job completed **SUCCESS** and emitted successful runtime evidence for:

- QA315 — numeric scale/exponent lexical-form characterization.
- QA330 — legacy offers INSERT RLS actor-binding regression; transaction rolled back.
- QA332 — INSERT RETURNING and synthetic actor-scoped SELECT mechanics; transaction rolled back.
- QA366–QA372 — extension-aware catalog objects, replication slots, database-local settings/default ACLs, parameter ACL boundaries, and non-superuser catalog visibility.
- QA373–QA381 — database-owner/CREATEROLE and role-membership/SET/ADMIN privilege boundaries.
- QA384–QA424 — CREATE_OFFER numeric-domain validation, no-write rejection, currency acceptance, request-hash scope, JSONB equivalence, default-argument replay and changed-input rejection.
- QA427 — committed geography-default replay across two PostgreSQL sessions, preserving hash, result and all four persisted records.
- QA428 — changed-payload request queued behind a committed same-key success is rejected with `IDEMPOTENCY_KEY_REUSE`, preserving the original four-table state.
- QA429 — two concurrent identical same-key requests both returned the same committed success; later replay matched it, with one row in each of the four persistence tables.

The jobs also completed the auxiliary runner guards, legacy-offer RLS mechanics, wrapper-owner/EXECUTE ACL checks, legacy-messages RLS regressions, participant self-enrollment regressions, and disposable-database/prepared-transaction cleanup checks. Expected negative SQL errors are test stimuli; the PostgreSQL runtime jobs themselves completed successfully.

### Prepared-transaction cleanup harness

- Cleanup-failure job `133686629662`: conclusion **failure**, expected by the negative test.
- Setup-failure job `133686630009`: conclusion **failure**, expected by the negative test.
- Intentionally skipped job `133686631229`: conclusion **skipped**, expected.
- Assertion jobs `133686630299`, `133686697175` and `133686713795`: all **SUCCESS**.

The negative job conclusions are intentional stimuli and are not unexpected failures of the overall CI workflow.

## CodeQL and Preview

- [QIMA CodeQL #1471](https://github.com/meridane/QimaTrade-MVP/actions/runs/43977934530), job `133686628175`: **SUCCESS**.
- Commit status API for `935a5acb`: combined status **success**; Vercel context reports success. [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/ArY3ifACFB8hMQyc6jEosbpuVWh4). Preview only; no Production deployment.

## Scope and limitations

- QA330/QA332 use disposable synthetic fixtures and rollback. QA332's actor-scoped SELECT policy is test-only and does not establish live Supabase Production RLS behavior.
- All PostgreSQL runtime evidence is from disposable CI databases. It is not a Production assessment and does not establish a confirmed vulnerability.
- The authorization relationship between `demand_id` and `tenant_id` remains blocked on an approved business ownership model.
- `docs/MKT-1.2_LEGACY_DRAFT_IDEMPOTENCY_CONTRACT.md` remains **PROPOSAL ONLY — NOT APPROVED**; draft-key scope, retention, browser persistence, replay response and storage architecture require product approval.
- MKT-1.3 numeric canonicalization remains subject to a product decision; no normalization rule is inferred.
- No Production data, migration, persistent grant/RLS policy, secret or PostgreSQL configuration was changed. No Production deployment, merge, force-push or branch-protection change was performed.

## Canonical register handling

The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was fetched by path and by a requested line range, but the GitHub file-content connector returned an empty body for this approximately 2 MB file. The existing CI #1536 append was readable and confirms the established supplemental append convention. To avoid replacing the canonical register with incomplete content, this verified CI #1537 evidence is stored as a separate `QIMA_V1_FUNCTION_REGISTER_*_APPEND.md` artifact. The canonical monolithic file is not claimed to have been modified in this commit.
