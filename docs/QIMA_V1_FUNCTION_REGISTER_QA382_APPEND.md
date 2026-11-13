# QA382 — CREATE_OFFER request-hash field coverage

Date: 2026-11-13 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch: `fix/create-offer-status-contract`  
Status: **STATIC REGRESSION PASS — FULL CI PENDING**

## Initial state verified

- PR #26: OPEN, DRAFT, mergeable, not merged; base `main`, head `074f2d30be683a3bdfe1ec57f766a7015ea68450`.
- Comparison with `main`: 1,677 commits ahead, zero behind; 156 files changed.
- Latest code commit: `074f2d30be683a3bdfe1ec57f766a7015ea68450`.
- QIMA CI [#1386](https://github.com/meridane/QimaTrade-MVP/actions/runs/43406823843): **SUCCESS**. PostgreSQL 16 and 17.6 both emitted the explicit QA381 passed marker. Verify passed with 347/347 Playwright tests.
- CodeQL [#1335](https://github.com/meridane/QimaTrade-MVP/actions/runs/43406825403): **SUCCESS**. Vercel combined status for that HEAD: **SUCCESS**.
- The canonical register was read through its Git blob SHA because the file-content wrapper returned an empty body for the 1.77 MB document. The blob content was complete; no partial replacement was used.

## QA381 closure

QA381 is closed after CI #1386 emitted its explicit success marker on both PostgreSQL 16 and 17.6. The four `createrole_self_grant` settings (empty, `set`, `inherit`, `set,inherit`) matched the catalog, effective membership, direct SELECT, SET ROLE and cleanup expectations. QA371's host-side port readiness correction also passed on both versions.

## Objective

Add a small static regression guard for the effective request-hash mapping in `public.execute_create_offer_v1`. The migration already hashes the complete effective business request; QA382 makes that mapping explicit and resistant to accidental field omission.

This is a static contract check. It does not change the hash, select a new canonicalization policy, or assert that a particular numeric lexical normalization is desired.

## Changes

1. Added `tests/sql/test-create-offer-request-hash-contract.sh`.
   - Requires exactly one `v_hash := md5(jsonb_build_object(...))` block.
   - Requires each of the 16 effective business-input mappings exactly once: input, name, demand, Product Master, provider actor, quantity, price, currency, conditions, market, geography, attributes, documentation status, lifecycle, offer type and pricing model.
   - Requires the existing `coalesce(p_attributes, '{}'::jsonb)` mapping.
   - Keeps tenant ID and idempotency key as the operation scope rather than direct members of the business-payload hash.
   - Confirms the existing disposable runtime suite still references all 16 parameters, changed-payload rejection, and the same-key/two-tenant request-hash characterization.
   - Requires the Verify job to execute the new contract exactly once.

2. Updated `.github/workflows/ci.yml` to run the static contract in Verify after the numeric replay contract.

3. Updated the canonical function register and QA371/QA381 appendices with CI #1386 final evidence. Added this QA382 appendix.

## Existing decision gates deliberately unchanged

- MKT-1.1: the demand-to-tenant/response-eligibility business rule still needs an approved ownership and eligibility model. The historical read-only schema snapshot is not treated as a current source of policy.
- MKT-1.2: independent-draft idempotency key scope, retention, browser persistence, replay response, cross-tab semantics and storage architecture remain **PROPOSAL ONLY — NOT APPROVED**.
- MKT-1.3: numeric precision/scale equivalence, JSONB numeric normalization, NULL/empty semantics and hash-version compatibility remain **DECISION REQUIRED — NOT APPROVED**.

QA382 does not implement or infer any of those decisions. It preserves the current hash mapping while the product contract remains pending.

## Validation

- Pre-publication content check: the current migration contains exactly one request-hash block and all 16 expected key/expression pairs; the existing SQL runtime contains the corresponding parameter references, `IDEMPOTENCY_KEY_REUSE` assertions and cross-tenant hash-scope assertion.
- CI validation of the new static contract: **PENDING** on the new HEAD. Do not claim QA382 PASS until the new Verify job executes the script successfully.
- Runtime PostgreSQL behavior is unchanged by this static-only guard. QA381's PostgreSQL 16/17.6 result is recorded separately above.

## Safety

- No application code, SQL function, migration, schema, RLS policy, grant, secret, Production data or persistent PostgreSQL configuration changed.
- No Supabase Production access or write was performed.
- No Production deployment, PR merge, force update or branch-protection change was performed.
- The existing MKT-1.1/MKT-1.2/MKT-1.3 business and product decisions remain open; no policy is inferred.


## CI #1387 — validation intermédiaire QA382 (13 novembre 2026)

- QIMA CI [#1387](https://github.com/meridane/QimaTrade-MVP/actions/runs/43408788151) : **EN COURS** au dernier contrôle.
- Verify : **SUCCESS**. Le nouveau contrôle `Verify CREATE_OFFER request-hash field coverage` a terminé **SUCCESS** et émis explicitement : `QA382 PASS: the effective CREATE_OFFER request hash maps all 16 business inputs exactly once, keeps tenant/idempotency scope separate, and retains the existing disposable replay assertions.`
- npm audit au seuil high configuré, TypeScript, build Next.js, installation Chromium et Playwright : **SUCCESS**, avec **347/347** tests navigateur.
- CodeQL [#1336](https://github.com/meridane/QimaTrade-MVP/actions/runs/43408787889) : **SUCCESS**. Statut Vercel Preview sur ce HEAD : **SUCCESS**.
- Les jobs PostgreSQL 16 et 17.6 étaient encore dans l'étape `Characterize full CREATE_OFFER runner write privileges`. Aucun nouveau marqueur QA381 n'était disponible pour le HEAD QA382 au dernier contrôle; le workflow global reste donc en cours. Ce n'est ni un échec ni une nouvelle réussite runtime.
- La clôture QA381 reste fondée sur CI #1386, qui a émis le marqueur explicite sur les deux versions. CI #1387 constitue une revalidation supplémentaire sur le HEAD QA382.
