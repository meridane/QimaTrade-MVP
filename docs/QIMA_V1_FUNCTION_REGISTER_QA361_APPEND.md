# QIMA V1 Function Register — QA361 Append

Date: 2026-11-12 (KST)

## Scope

Protect the existing post-rejection non-mutation assertions in OFFER-QA-73, OFFER-QA-74, and OFFER-QA-75. This is a source-level regression guard; it does not select or implement a numeric canonicalization policy.

## Initial state checked

- Repository: `meridane/QimaTrade-MVP`.
- PR #26: OPEN, DRAFT, mergeable, not merged; base `main`; head branch `fix/create-offer-status-contract`.
- Initial comparison: 1,513 commits ahead of `main`, zero behind.
- Initial checks: QIMA CI #1297 SUCCESS and CodeQL #1247 SUCCESS.
- Human reviews: 0; inline review threads: 0.
- The canonical register ended at QA360 before this append.

## Finding and change

Added `tests/sql/test-create-offer-numeric-replay-contract.sh` and wired it into the Verify job in `.github/workflows/ci.yml`.

The static guard extracts the replay assertion segments from the existing `DO $qa73_assert$`, `DO $qa74_assert$`, and `DO $qa75_assert$` blocks. It requires exactly four replay paths:

1. OFFER-QA-73 — JSONB numeric-scale replay.
2. OFFER-QA-74 — typed quantity-scale replay.
3. OFFER-QA-74 — typed price-scale replay.
4. OFFER-QA-75 — nested `p_attributes` numeric-scale replay.

For every path it requires:
- exactly one `execute_create_offer_v1` replay call;
- captured exception text and an exact `IDEMPOTENCY_KEY_REUSE` assertion before persisted-state checks;
- exact-one checks for the original idempotency row, including `request_hash`, `execution_id`, and `result`;
- the original completed action execution, including `input`, `result`, and `object_id`;
- the original offer and its business fields;
- the original `ACTION_SUCCEEDED` event, including object identity and payload;
- at least four `v_count <> 1` guards per replay path;
- no direct DML/DDL statements in the replay assertion segment.

The script also verifies that the new contract test is wired into the Verify job.

No changes were made to `tests/sql/create-offer-runtime.sql`, the integration runner, migrations, SQL functions, request hashes, or numeric behavior. The four existing runtime replay paths remain the source of behavioral evidence; QA361 protects their assertions from accidental removal.

## Validation

- Local source preflight: PASS; all four replay segments were found and each satisfied the nine static contract checks.
- QIMA CI #1299: **SUCCESS**, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43172940662.
  - Verify step “Verify numeric replay rejection preserves original persisted state”: SUCCESS.
  - Log marker: `QA361 PASS: all four rejected numeric replay paths retain exact-one idempotency, execution, offer, and ACTION_SUCCEEDED state assertions.`
  - PostgreSQL 16 integration: SUCCESS.
  - PostgreSQL 17.6 compatibility: SUCCESS; exact server-version guard passed.
  - npm ci, npm audit at the high threshold, TypeScript, Next.js build, Chromium installation: SUCCESS.
  - Playwright: **347 passed in 10.6 seconds**.
  - Existing QA353/QA354 harness jobs retain their expected individual failure conclusions; their independent assertions succeeded. The skipped harness remains skipped and its dependent assertion succeeded.
  - Overall QIMA CI conclusion: SUCCESS.
- CodeQL #1249: **SUCCESS**, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43172940726.
- Vercel combined status for code HEAD `4f339c1a87024cebdf9d63b65167d9e2a7a17ca5`: SUCCESS (Preview status only), https://vercel.com/bmk1/qimatrade-mvp/5KG322hNy4ZibirBsgMRyz5Bt4cg.

## Commits and branch

- Work branch: `work/qa361-numeric-replay-post-rejection-contract-20261112-1604`.
- `fe349044cd11ec7ca2aaaf9d72392d0febbbaadb` — add numeric replay non-mutation contract test.
- `4f339c1a87024cebdf9d63b65167d9e2a7a17ca5` — wire the test into the Verify job.
- The work branch was fast-forwarded to PR #26 after a compare confirmed it was two commits ahead and zero behind. No force update was used.

## Evidence boundary and safety

- QA361 is a static source-contract test. It does not independently prove a Production incident, vulnerability, or runtime behavior.
- The underlying QA73/QA74/QA75 replay tests execute in disposable PostgreSQL CI fixtures; their observed CI success is not a Production test.
- MKT-1.2 remains unapproved. MKT-1.3 remains characterization/decision required. No key scope, retention, numeric equivalence, canonicalization, precision, or legacy-hash compatibility decision was invented.
- No Supabase Production data, migration, schema, SQL function, RLS policy, grant, secret, or persistent configuration was modified.
- No Production deployment, PR merge, force update, or branch-protection change was performed.

## Next step

Keep MKT-1.2 and MKT-1.3 blocked pending explicit product approval. A useful next non-blocking task is a read-only audit that the QA73/QA74/QA75 fixture seeds use unique keys and remain isolated within the disposable integration database. Do not change numeric normalization or replay semantics without approval.
