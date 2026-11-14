# QIMA V1 Function Register — QA341 append

Date: 2026-11-11 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`  
Work branch: `work/qa341-independent-draft-idempotency-contract-20261111-1942`

## Starting-state verification

- PR #26 was **OPEN**, **DRAFT**, unmerged, and reported mergeable.
- PR head at start: `2f8aa843e7e54b5e837e1d2049bb9b4a17e2b1da` (`docs(qima): close QA340 validation record`).
- PR metadata: 1,413 commits, 93 changed files; base `main`; no commits behind according to the previously recorded branch comparison.
- No submitted reviews or inline review threads were returned by GitHub.
- The head's QIMA CI run **#1233** ([run 43002336880](https://github.com/meridane/QimaTrade-MVP/actions/runs/43002336880)) was **SUCCESS, 3/3 jobs**. Its jobs were: TypeScript/audit/build/browser, PostgreSQL 16 integration, and PostgreSQL 17.6 compatibility. All job conclusions were success.
- Playwright on that code head: **347/347 passed**. PostgreSQL 16 and 17.6 checks passed; the PostgreSQL 17.6 version guard reported `server_version_num=170006`.
- CodeQL **#1184** ([run 43002336655](https://github.com/meridane/QimaTrade-MVP/actions/runs/43002336655)) was **SUCCESS**.
- Vercel status on that starting code/documentation head was **SUCCESS**, Preview [8qAVyZdgmLxvaudPk4v9yfQWPE4y](https://vercel.com/bmk1/qimatrade-mvp/8qAVyZdgmLxvaudPk4v9yfQWPE4y). Preview only.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was requested from the PR branch. GitHub returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but an empty content body in this read. The canonical file was not modified or replaced.

## QA341 — independent draft idempotency contract design

### Evidence reviewed

- `app/offers/new/page.tsx`: the independent draft browser request sends `Accept: application/json`, same-origin credentials, and `FormData`; no idempotency field or header is currently included.
- `app/api/offers/route.ts`: delegates to `createLegacyOfferHandler`.
- `lib/offers/create-legacy-offer.ts`: derives the provider actor from the authenticated profile, generates a fresh `randomUUID()` on each POST, inserts directly into `offers`, and returns the generated ID on success. It does not read or persist an idempotency key. Demand, Product Master, price, and currency can be NULL for the independent draft.
- `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`: the existing `execute_create_offer_v1` action path requires tenant, membership, demand, active Product Master, price, currency, and an idempotency key. It uses a tenant/key advisory lock and replays a completed matching result.
- `tests/sql/fixtures/create-offer-schema.sql`: the disposable fixture models `idempotency_keys.tenant_id` as NOT NULL and a unique `(tenant_id, key)` constraint. This fixture is not a fresh Production catalog inspection.

### Finding and interpretation

QA340's deterministic synthetic browser test allows the first INSERT to complete in the local mock PostgREST fixture, drops the browser-facing response, and retries the unchanged form. The current handler creates a fresh UUID on the retry; the fixture observes two rows.

This establishes the current behavior of the isolated test setup and the absence of a stable operation key in the inspected source. It does **not** establish that duplicate offers were created in Supabase Production, that Production accepts the same sequence, or that a Production vulnerability is confirmed.

The existing tenant-scoped action RPC is not a drop-in replacement for the independent-draft route. Calling it unchanged would reject valid independent drafts; relaxing its required business inputs would broaden a shared contract and requires review.

### Documentation change

Created `docs/MKT-1.2_LEGACY_DRAFT_IDEMPOTENCY_CONTRACT.md` as a proposal-only design record. It documents:

- current UI, route, handler, and RPC facts;
- required idempotency semantics (stable retry key, canonical payload binding, replay, key misuse, concurrency, atomicity, and retention);
- three architecture options, with a dedicated tenantless draft operation recommended for discussion only;
- decisions still requiring approval (key scope, retention, browser persistence, replay status, cross-tab behavior, and storage model);
- a disposable regression matrix and implementation gate.

**No option is approved.** No handler, shared RPC, schema, migration, RLS policy, grant, or production configuration was changed.

### Validation after documentation-only change

- Work branch created from the exact starting PR head: `work/qa341-independent-draft-idempotency-contract-20261111-1942`.
- Contract document commit: `d01eb8277017e207e095913844a2dfc4055518ec`.
- After that commit, GitHub returned no PR-triggered workflow runs for the commit. This is expected from both `.github/workflows/ci.yml` and `.github/workflows/codeql.yml`, which specify `paths-ignore: docs/**` for pull-request and push events.
- The last code validation remains CI #1233 and CodeQL #1184 on the unchanged code head `2f8aa843e7e54b5e837e1d2049bb9b4a17e2b1da`. This documentation-only commit did not rerun code or browser tests.
- The Vercel combined status for the documentation commit was still **PENDING** at the time of this append; it is not treated as a successful Preview.
- No CI failure was observed for QA341; the code workflows were skipped by their documented path filters.

## Safety boundary

- This is contract design, not implementation or approval.
- No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.


## QA341 — final documentation-head verification

- Contract document commit: `d01eb8277017e207e095913844a2dfc4055518ec`.
- Register append commit: `053904420f3f73ea33c03fa4071b57971cacd0d7`.
- The register append was fetched back from the work branch and its contents verified (5,787 characters); the contract note was also fetched back and verified (11,448 characters).
- GitHub Actions workflow-run lookup for the register append commit returned no PR-triggered runs. This is expected because both CI and CodeQL workflows declare `paths-ignore: docs/**` for push and pull-request events. No code or test files changed in QA341.
- The last applicable code validation therefore remains **QIMA CI #1233** (run `43002336880`, **SUCCESS, 3/3 jobs**, 347/347 Playwright) and **CodeQL #1184** (run `43002336655`, **SUCCESS**) on unchanged code HEAD `2f8aa843e7e54b5e837e1d2049bb9b4a17e2b1da`.
- Vercel on the register append commit returned **FAILURE** with target `build-rate-limit` / `api-deployments-free-per-day`. This is a Preview quota limitation, not a GitHub Actions failure. No retry or quota bypass was attempted.
- No test is reported as newly passing in QA341; QA341 is a documentation-only contract-design task. No CI failure occurred.



## QA341 — PR synchronization validation closure

After the two documentation commits were fast-forwarded to PR #26, GitHub evaluated the full pull request and triggered the PR synchronization workflows on HEAD `0aec9e6a8d2840b761389abdd08ee93d1ac7ed71`.

- **QIMA CI #1234** ([run 43006397844](https://github.com/meridane/QimaTrade-MVP/actions/runs/43006397844)) — **SUCCESS, 3/3 jobs**.
  - Browser/build job: **347/347 Playwright tests passed, 0 failed**; npm ci, npm audit enforcement, TypeScript, Next.js build, Chromium, and artifact/report steps completed successfully.
  - PostgreSQL 16 integration/cleanup job: **SUCCESS**.
  - PostgreSQL 17.6 compatibility job: **SUCCESS**; the existing 17.6 version guard and CREATE_OFFER/RLS/ACL regression steps completed.
- **CodeQL #1185** ([run 43006397956](https://github.com/meridane/QimaTrade-MVP/actions/runs/43006397956)) — **SUCCESS**.
- The CI logs include intentional negative SQL assertions such as `IDEMPOTENCY_KEY_REUSE`, wrapper-owner rejection, and prepared-transaction cleanup guards. Their test steps and jobs succeeded; these log entries are not CI failures.
- Vercel on PR HEAD `0aec9e6` returned **FAILURE** with `build-rate-limit` / `api-deployments-free-per-day`. No retry or quota bypass was attempted.
- These workflows ran on the unchanged application/test code from QA340; QA341 adds documentation only. No new QA341 application or database test is claimed.
- The earlier lookup immediately after the first docs commit occurred before the work branch was fast-forwarded to the PR. The PR synchronization event then triggered CI #1234 and CodeQL #1185 despite `paths-ignore: docs/**`, because the pull request as a whole contains non-documentation changes.

