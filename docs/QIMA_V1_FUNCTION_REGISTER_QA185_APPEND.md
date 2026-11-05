# QimaTrade V1 Function Register — QA185 addendum

> Append-only supplement for `docs/QIMA_V1_FUNCTION_REGISTER.md`.
> The canonical register at the QA184 baseline is blob `41c26372c351e197c93d149241a1d3825a576ac6` (1,072,613 bytes). The GitHub file-content connector returned the blob metadata but not its body because the file exceeds its supported retrieval size. To avoid replacing or truncating the historical register without its full contents, this QA entry is kept in a separate, reviewable addendum.

## QA185 — unavailable first duplicated demandId

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`
- **Test commit:** `3812f476b418a5b54b78c6943b628b7958422423`
- **Scenario:** submit a UUID-shaped but unavailable first `demandId`, followed by a different valid-looking duplicate.
- **Fixture:** Supabase client is mocked with `demand: null`; no remote database is queried.
- **Expected/observed assertions in the test:** HTTP 400 with `Demand not found or unavailable.`; one authenticated-user lookup; profile lookup for the authenticated user; exactly one demand lookup using the first UUID; no product-master lookup; zero offer insertions; null insert payload.
- **Contract characterized:** `FormData.get("demandId")` uses the first multipart occurrence. The later duplicate is not used. An unavailable first reference stops processing before product lookup and offer insertion.
- **Security interpretation:** this is a deterministic unit/integration-style characterization with a mocked Supabase client. It is not evidence of a production authorization bypass or a confirmed vulnerability.
- **CI status at this addendum revision:** pending; record final run URLs and exact results in the next revision.
- **Safety:** no application handler, SQL, migration, Supabase production data, policy, deployment, merge, or branch-protection setting changed.

## Register maintenance note

The canonical register's QA184 tail was inspected from commit `0eca4833bae236f321992bbc2abaa0f49ac330bd`. Its current blob is over 1 MiB and the connector did not return the file body, so a complete replacement of the canonical file could not be performed safely in this run. This addendum preserves the QA185 record without truncating the canonical history.


## QA185 — final validation reconciliation (5 November 2026, 02:29 KST)

- **Test commit:** `3812f476b418a5b54b78c6943b628b7958422423`.
- **QIMA CI #769:** [run 41866475929](https://github.com/meridane/QimaTrade-MVP/actions/runs/41866475929) — **SUCCESS**; both jobs completed successfully. The browser log confirms **204/204 Playwright tests passed (6.7 s)**, including the QA185 first-unavailable-`demandId` regression. The isolated PostgreSQL CREATE_OFFER/concurrency/idempotency job and both RLS regression scripts also completed successfully.
- **CodeQL #726:** [run 41866475738](https://github.com/meridane/QimaTrade-MVP/actions/runs/41866475738) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Combined status:** Vercel reports a rate-limit failure for the free deployment quota; this is separate from the successful GitHub Actions and CodeQL checks. No quota bypass or production deployment was attempted.
- **Conclusion:** QA185 is validated by CI #769 (204/204) and CodeQL #726. The route test uses a mocked Supabase client; the PostgreSQL/RLS checks use isolated CI fixtures. This does not establish a production authorization defect or a confirmed vulnerability.

## QA186 — first duplicated demand lookup returns an error (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Test commit:** `63fc91271aef8e1a1a1b5a53c56331df8ae491ae`.
- **Scenario:** the first multipart `demandId` is `50000000-0000-4000-8000-000000000198`; a second, valid-looking `DEMAND_ID` follows. The mocked lookup returns a demand-shaped data fixture together with a simulated lookup error, to exercise the explicit `demandError` short-circuit branch.
- **Expected assertions:** HTTP 400 with `Demand not found or unavailable.`; one authenticated-user lookup; one profile lookup; exactly one demand lookup using the first value; no product-master lookup; zero offer insertions; null insert payload.
- **Contract characterized:** a lookup error stops the handler before product lookup and insertion, even when the mock also supplies a demand-shaped data value. The later multipart duplicate is not used.
- **CI status at this addendum revision:** pending. Record the final CI and CodeQL run URLs, exact Playwright count, and any failures after the run completes.
- **Security interpretation:** the scenario is a deterministic mocked-client test of the handler's explicit error branch. It is not evidence of a production vulnerability or remote authorization bypass.
- **Safety:** no production Supabase data, production migration, policy, production deployment, merge, or branch-protection setting was changed.


## QA186 — final validation reconciliation (5 November 2026, 03:42 KST)

- **Test commit:** `63fc91271aef8e1a1a1b5a53c56331df8ae491ae`.
- **QIMA CI #770:** [run 41878233257](https://github.com/meridane/QimaTrade-MVP/actions/runs/41878233257) — **SUCCESS**; both jobs completed successfully. The browser log confirms **205/205 Playwright tests passed (6.8 s)**, including QA186. The isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency job and both RLS regression scripts also completed successfully.
- **CodeQL #727:** [run 41878233565](https://github.com/meridane/QimaTrade-MVP/actions/runs/41878233565) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined commit status is **SUCCESS** for the preview deployment.
- **Conclusion:** QA186 is validated by CI #770 (205/205), CodeQL #727, and the successful Vercel preview status. Its route-level Supabase behavior is exercised with a mocked client; isolated PostgreSQL/RLS CI fixtures are separate checks. This does not establish a production authorization defect or a confirmed vulnerability.

## QA187 — first duplicated productMasterId lookup returns an error (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Test commit:** `8af73c6d882e6d4b7d6270f29d1562070287d840`.
- **Scenario:** the first multipart `productMasterId` is `50000000-0000-4000-8000-000000000299`; a different valid `PRODUCT_MASTER_ID` is appended as the second occurrence. No demand is supplied, isolating the explicit product-master lookup path.
- **Mock:** `productMaster: null` with `productMasterError: { message: "simulated product master lookup failure" }`.
- **Expected assertions:** HTTP 400 with `PRODUCT_MASTER_NOT_FOUND`; one authenticated-user lookup; one profile lookup; no demand lookup; exactly one product-master ID lookup using the first value followed by the active-status filter; zero offer insertions; null insert payload.
- **Contract characterized:** `FormData.get("productMasterId")` uses the first multipart occurrence. A product-master lookup error stops processing before offer insertion; the later valid duplicate is not used.
- **CI status at this addendum revision:** pending. Record final CI and CodeQL run URLs and exact Playwright results after the new commit is validated.
- **Security interpretation:** this is a deterministic mocked-client regression test of the handler's error branch. It is not evidence of a production vulnerability, authorization bypass, or live database behavior.
- **Safety:** no production Supabase data, production migration, policy, production deployment, merge, or branch-protection setting was changed.


## QA187 — final validation reconciliation (5 November 2026, 03:42 KST)

- **Test commit:** `8af73c6d882e6d4b7d6270f29d1562070287d840`.
- **QIMA CI #772:** [run 41890133325](https://github.com/meridane/QimaTrade-MVP/actions/runs/41890133325) — **SUCCESS**; both jobs completed successfully. The browser log confirms **206/206 Playwright tests passed (6.7 s)**, including QA187. TypeScript, production build, Chromium installation, and the dependency-audit gate all completed successfully. The isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency job and both RLS regression scripts also completed successfully.
- **CodeQL #728:** [run 41890133249](https://github.com/meridane/QimaTrade-MVP/actions/runs/41890133249) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** the combined status for the tested HEAD `793a803c0f3c5f14242c61412471e15e9456ac22` remained **PENDING** at the time of this record; no deployment failure was confirmed.
- **Conclusion:** QA187 is validated by CI #772 (206/206), CodeQL #728, and the isolated PostgreSQL/RLS checks. The route-level product-master lookup uses a mocked Supabase client; it does not establish live database behavior or a production authorization defect.
- **Safety:** no production Supabase data, production migration, policy, production deployment, merge, or branch-protection setting was changed.


## QA188 — file as first duplicated productMasterId (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Test commit:** `249b3e23822164095e95c1b4ac38db7ca522b964`.
- **Scenario:** submit a `File` as the first multipart `productMasterId` value, followed by a valid-looking `EXPLICIT_PRODUCT_MASTER_ID` string.
- **Expected assertions:** HTTP 400 with `Invalid offer form fields.`; the injected Supabase-client factory is never called (`factoryCalls === 0`), so no authentication, profile lookup, demand lookup, product lookup, or offer insertion can occur through the handler.
- **Contract characterized:** `productMasterId` is included in `textFormFields`; the handler validates the first `FormData.get("productMasterId")` value before creating the Supabase client. A later duplicate does not replace a first file value.
- **CI status at this addendum revision:** not yet run on the isolated work branch. The repository's observed PR checks are triggered by pull-request commits; after fast-forwarding this tested change onto PR #26, record the resulting GitHub Actions and CodeQL run URLs and exact outcomes.
- **Security interpretation:** this is a deterministic mocked-client input-validation regression test. It does not establish a production vulnerability, authorization bypass, or live database behavior.
- **Safety:** no production Supabase data, production migration, policy, production deployment, merge, or branch-protection setting was changed.


## QA188 — final validation reconciliation (5 November 2026, 04:36 KST)

- **Test commit:** `249b3e23822164095e95c1b4ac38db7ca522b964`.
- **Documentation commit:** pending in the current work branch at the time this entry was prepared.
- **QIMA CI #774:** [run 41898283132](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898283132) — **SUCCESS**; both jobs completed successfully. The browser job confirms **207/207 Playwright tests passed (5.4 s)**, including QA188. TypeScript, dependency audit, production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency tests, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **CodeQL #730:** [run 41898283153](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898283153) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** Preview remained **PENDING** on the validated HEAD; no Vercel failure was confirmed and no production deployment was attempted.
- **Conclusion:** QA188 is validated by CI #774 (207/207), CodeQL #730, and the isolated PostgreSQL/RLS checks. The route-level request uses a mocked Supabase-client factory and proves only the handler's early input rejection in this test setup.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA188 — final documentation HEAD preview reconciliation (5 November 2026, 04:37 KST)

- **Test commit:** `249b3e23822164095e95c1b4ac38db7ca522b964`; **validated test HEAD:** `6b4775a8a0a1acf2d913e8326431d58c5168f976`.
- **QIMA CI #774:** [run 41898283132](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898283132) — **SUCCESS**, 207/207 Playwright tests and both CI jobs succeeded.
- **CodeQL #730:** [run 41898283153](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898283153) — **SUCCESS**.
- **Documentation HEAD:** `8623e010e77c8f375945cd7ce625d98984e0bf81` appended QA188 to the canonical register and this addendum. The docs-only commit did not produce a new QIMA CI or CodeQL workflow run; its check-runs showed only the Vercel Preview Comments success.
- **Vercel:** the documentation HEAD status is **FAILURE** with the target `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`, indicating the free deployment quota. This is separate from CI #774 and CodeQL #730, which both succeeded.
- **Safety:** no quota workaround or production deployment was attempted.


## QA189 — empty first duplicated productMasterId (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Test commit:** `0c9ea68406209320f229c7081ca004360a7fd1a7`.
- **Scenario:** submit an empty first multipart `productMasterId` value, followed by a valid-looking `EXPLICIT_PRODUCT_MASTER_ID` duplicate.
- **Assertions:** HTTP 303; no demand lookup; no product-master lookup; exactly one offer insertion; inserted `product_master_id: null`, `lifecycle: "draft"`, and `offer_type: "supplier_offer"`.
- **Implementation contract:** `FormData.get("productMasterId")` selects the first occurrence; `trim() || null` normalizes the empty first value to `null`. The later valid-looking duplicate is not used.
- **QIMA CI #776:** [run 41898804426](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898804426) — **PENDING** at this record; exact Playwright result is not yet available. The expected suite count is 208 after adding QA189 to the previously validated 207 tests.
- **CodeQL #732:** [run 41898804329](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898804329) — **IN PROGRESS** at this record.
- **Vercel:** the tested commit reports the free-plan deployment rate-limit failure (`build-rate-limit`). This is not evidence of a Next.js build failure; GitHub Actions build status remains pending separately.
- **Security interpretation:** the route-level test uses a mocked Supabase client and characterizes first-value normalization only. It does not establish production authorization behavior or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, or configuration was changed; no production deployment, merge, or branch-protection change was performed.


## QA189 — interim validation reconciliation (5 November 2026)

- **QIMA CodeQL #732:** [run 41898804329](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898804329) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **QIMA CI #776:** [run 41898804426](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898804426) — **IN PROGRESS** at this check. Dependency audit, TypeScript, and Next.js production build have succeeded. Chromium installation and isolated PostgreSQL CREATE_OFFER integration/concurrency tests are still running; Playwright and the RLS regression steps have not yet completed. No CI failure has been reported.
- **Expected browser suite:** 208 tests (207 previously validated + QA189); the exact result remains unconfirmed until the job finishes.
- **Vercel:** the current PR HEAD reports the free-plan deployment rate-limit failure (`build-rate-limit`), separate from the in-progress GitHub Actions workflow.
- **Interpretation and safety:** QA189 remains pending final CI validation. Its route-level assertions use a mocked Supabase client; no production vulnerability is inferred. No production data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA189 — CI cancellation reconciliation (5 November 2026)

- **Test commit:** `0c9ea68406209320f229c7081ca004360a7fd1a7`.
- **QIMA CI #776:** [run 41898804426](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898804426) — **CANCELLED** before the browser test step. Dependency audit, TypeScript, and Next.js production build completed successfully. Chromium installation was cancelled; Playwright was skipped. The PostgreSQL CREATE_OFFER integration step was cancelled after setup; the RLS steps were skipped. Therefore QA189 has no confirmed Playwright result and remains unvalidated by CI; no test failure was reported.
- **QIMA CodeQL #732:** [run 41898804329](https://github.com/meridane/QimaTrade-MVP/actions/runs/41898804329) — **SUCCESS**.
- **Vercel:** the PR head reports the free-plan deployment rate-limit failure (`build-rate-limit`), separate from GitHub Actions.
- **Next validation:** the next code-bearing PR update includes QA190 and will re-run the suite; QA189 remains part of that suite.
- **Security interpretation:** the route test uses a mocked Supabase client; cancellation is not evidence of a defect or a vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA190 — whitespace-only first duplicated productMasterId (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Test commit:** `9200837b521b0fe23eb5ee1bae9d6335c400ac37`.
- **Scenario:** submit a whitespace-only first multipart `productMasterId` value, followed by a valid-looking `EXPLICIT_PRODUCT_MASTER_ID` duplicate.
- **Assertions:** HTTP 303; no demand lookup; no product-master lookup; exactly one offer insertion; inserted `product_master_id: null`, `lifecycle: "draft"`, and `offer_type: "supplier_offer"`.
- **Implementation contract:** `FormData.get("productMasterId")` selects the first occurrence; `trim() || null` normalizes the whitespace-only first value to `null`. The later valid-looking duplicate is not used.
- **CI status:** pending promotion of this code-bearing commit to PR #26. The expected browser suite is **209 tests**: 207 previously validated tests plus QA189 and QA190. Record the actual CI and CodeQL results after the PR checks complete.
- **Security interpretation:** this route-level regression uses a mocked Supabase client and characterizes normalization only; it does not establish production authorization behavior or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.



## QA189–QA190 — final validation reconciliation (5 November 2026, 06:10 KST)

- **Validated PR HEAD:** `ee11b26a16477c4186d47537fa5fb0714f0c5ff2`; PR #26 remains open and draft, based on `main`. Git comparison: 696 commits ahead, 0 behind.
- **QIMA CI #779:** [run 41899458921](https://github.com/meridane/QimaTrade-MVP/actions/runs/41899458921) — **SUCCESS**, both jobs completed successfully. The browser log confirms **209/209 Playwright tests passed (6.6 s)**, including QA189 and QA190. Dependency audit, TypeScript, Next.js production build, Chromium, and browser tests succeeded. Isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS tests succeeded.
- **QIMA CodeQL #735:** [run 41899458607](https://github.com/meridane/QimaTrade-MVP/actions/runs/41899458607) — **SUCCESS**.
- **Vercel:** the PR HEAD combined status reports **FAILURE** with target `build-rate-limit` (free-plan deployment quota). This is separate from successful CI and CodeQL; no quota workaround or production deployment was attempted.
- **Conclusion:** QA189 and QA190 are validated by the complete 209-test run #779. The earlier CI #776 cancellation remains recorded as historical and is superseded for validation by #779.
- **Security interpretation:** route tests use a mocked Supabase client and characterize handler behavior only; they do not establish production database behavior, authorization correctness, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA191 — non-string product_master_id in demand scope (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Test commit:** `b534e356f8bbac2cb2b14078f3866e51832940a5`.
- **Scenario:** submit a valid `demandId`; mocked demand scope contains numeric `product_master_id: 42`; no explicit product-master ID is submitted.
- **Expected assertions:** HTTP 303; one demand lookup; zero product-master lookups; one offer insertion; `demand_id` preserved; `product_master_id: null`; market falls back to `South Korea`; lifecycle `draft`; offer type `supplier_offer`.
- **Implementation contract:** only a string `scope.product_master_id` is accepted for fallback. A numeric value becomes `null` and is not used in a product-master query.
- **CI status:** pending promotion to PR #26. Expected browser suite: **210 tests** (209 previously validated + QA191). Record actual CI/CodeQL outcomes after completion.
- **Security interpretation:** mocked-client regression for type-safe scope fallback only; not proof of a production vulnerability or authorization bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA191 — final validation reconciliation (5 November 2026, 06:51 KST)

- **Validated PR HEAD:** `07b42e19f5285feccf793297fa80108cc0b80926`; PR #26 is open and draft, based on `main`. Git comparison: 699 commits ahead, 0 behind.
- **QIMA CI #780:** [run 41913916242](https://github.com/meridane/QimaTrade-MVP/actions/runs/41913916242) — **SUCCESS**, both jobs completed successfully. The browser log confirms **210/210 Playwright tests passed**. Dependency installation and audit, TypeScript, Next.js production build, Chromium, and browser tests succeeded. Isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS scripts all succeeded.
- **QIMA CodeQL #736:** [run 41913916012](https://github.com/meridane/QimaTrade-MVP/actions/runs/41913916012) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on the validated PR HEAD is **SUCCESS** (Preview target returned by GitHub). This is a Preview status only, not a production deployment.
- **Conclusion:** QA191 is validated by the complete 210-test run #780. The earlier CI status recorded as pending is superseded by this completed result.
- **Security interpretation:** the route-level regression uses a mocked Supabase client and characterizes type-safe scope fallback only; it does not establish production database behavior, authorization correctness, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA192 — explicit productMasterId takes precedence over empty demand scope (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Scenario:** submit a valid `demandId` and explicit `productMasterId`; the mocked demand returns `scope: { product_master_id: "" }`.
- **Assertions:** HTTP 303; exactly one demand lookup; product-master lookup uses the explicit form ID and `status = active`; exactly one offer insertion; inserted `demand_id` is preserved and `product_master_id` equals the explicit form ID; market falls back to `South Korea`; lifecycle `draft`; offer type `supplier_offer`.
- **Implementation contract:** the handler initializes `productMasterId` from the explicit form field and only consults the demand scope when that value is empty. An empty scope value therefore cannot erase or replace a non-empty explicit ID.
- **CI status:** pending for the new test-bearing PR commit. Expected browser suite: **211 tests** (210 previously validated + QA192); record the exact result after GitHub Actions completes.
- **Security interpretation:** deterministic mocked-client regression for source precedence only; not proof of a production vulnerability or authorization bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.


## QA192 — final validation reconciliation (5 November 2026, 07:29 KST)

- **Validated PR HEAD:** `eb8137ce128fbd21a8b120dd5faeaa412a5d62bd`; PR #26 remains open and draft, based on `main`. Git comparison previously confirmed 700 commits ahead and 0 behind.
- **QIMA CI #781:** [run 41920221494](https://github.com/meridane/QimaTrade-MVP/actions/runs/41920221494) — **SUCCESS**, both jobs completed successfully. The browser log confirms **211/211 Playwright tests passed (6.5 s)**, including QA192 (explicit `productMasterId` takes precedence over an empty `scope.product_master_id`). TypeScript, dependency audit, Next.js production build, Chromium, browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #737:** [run 41920221453](https://github.com/meridane/QimaTrade-MVP/actions/runs/41920221453) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on this validated PR HEAD is **SUCCESS** (Preview only; not a production deployment).
- **Conclusion:** QA192 is validated by CI #781 (211/211). The pending note in the initial QA192 entry is superseded by this reconciliation.
- **Security interpretation:** the route regression uses a mocked Supabase client and verifies source precedence only; it does not establish production database behavior, authorization correctness, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA193 — whitespace-only product_master_id in demand scope (5 November 2026)

- **Files:** `tests/e2e/legacy-offers-route-contract.spec.ts` and `lib/offers/create-legacy-offer.ts`.
- **Scenario:** submit a valid demand whose mocked `scope.product_master_id` is a string containing only spaces; no explicit `productMasterId` is supplied.
- **Previous behavior:** the scope fallback accepted the untrimmed whitespace string as truthy, causing a product-master lookup with a blank-looking identifier.
- **Change:** trim string-valued `scope.product_master_id` and normalize an empty result to `null`, matching the existing normalization of the explicit form field.
- **Assertions:** HTTP 303; exactly one demand lookup; no product-master lookup; exactly one offer insertion; inserted `product_master_id: null`, preserved `demand_id`, market fallback `South Korea`, lifecycle `draft`, and offer type `supplier_offer`.
- **CI status:** pending for this code-bearing commit. Expected browser suite: **212 tests** (211 previously validated plus QA193). Record actual CI and CodeQL results after GitHub Actions completes.
- **Security interpretation:** regression test uses a mocked Supabase client and covers input normalization only; it is not evidence of a production vulnerability or authorization bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA193 — final validation reconciliation (5 November 2026, 08:12 KST)

- **Validated PR HEAD:** `27b5ce5c37dbd8220785b69cb1063ed577c36d29`; PR #26 remains open, draft, and mergeable, based on `main`. Git comparison: **701 commits ahead, 0 behind**.
- **QIMA CI #782:** [run 41926034614](https://github.com/meridane/QimaTrade-MVP/actions/runs/41926034614) — **SUCCESS**, both jobs completed. The browser job log confirms **212 Playwright tests passed**. Dependency installation and audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #738:** [run 41926034637](https://github.com/meridane/QimaTrade-MVP/actions/runs/41926034637) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on this PR HEAD is **SUCCESS** (Preview only; not a production deployment).
- **Conclusion:** QA193 is validated by CI #782. Its earlier pending note is superseded by this reconciliation.
- **Security interpretation:** the regression uses a mocked Supabase client and covers input normalization only; it does not establish production database behavior, authorization correctness, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA194 — whitespace explicit productMasterId falls back to demand scope (5 November 2026, 08:12 KST)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Scenario:** submit a valid `demandId`, set explicit `productMasterId` to a whitespace-only string, and have the mocked demand return a valid string `scope.product_master_id`.
- **Expected behavior:** explicit form input is trimmed to `null`; the handler then resolves the product-master ID from the demand scope and validates that product as active.
- **Assertions:** HTTP 303; exactly one demand lookup; product-master lookup uses the scope ID and `status = active`; exactly one offer insertion; inserted `demand_id` is preserved and `product_master_id` equals the scope ID; market fallback `South Korea`; lifecycle `draft`; offer type `supplier_offer`.
- **Implementation contract:** `productMasterIdFromForm` is trimmed before fallback. A whitespace-only explicit value is treated as absent, allowing the already-trimmed scope fallback.
- **CI status:** pending for the QA194 test commit. Expected browser suite: **213 tests** (212 previously validated + QA194); record actual GitHub Actions and CodeQL results after completion.
- **Security interpretation:** deterministic mocked-client regression for input normalization/fallback precedence; not evidence of a production vulnerability or authorization bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA194 — final validation reconciliation (5 November 2026, 08:12 KST)

- **Validated PR HEAD:** `584e0a468079ad876ce6e62568c581b4db6a54d0`; PR #26 remains open, draft, and mergeable, based on `main`. Git comparison: **704 commits ahead, 0 behind**.
- **QIMA CI #783:** [run 41932093340](https://github.com/meridane/QimaTrade-MVP/actions/runs/41932093340) — **SUCCESS**, both jobs completed. The browser job log confirms **213/213 Playwright tests passed**. Dependency installation and audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #739:** [run 41932093087](https://github.com/meridane/QimaTrade-MVP/actions/runs/41932093087) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on this validated PR HEAD is **SUCCESS** (Preview only; not a production deployment).
- **Conclusion:** QA194 is validated by CI #783 (213/213). The pending note in the initial QA194 entry is superseded by this reconciliation.
- **Security interpretation:** deterministic mocked-client regression for input normalization/fallback precedence; not evidence of a production vulnerability or authorization bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA194 — final validation on documented PR HEAD (5 November 2026, 08:12 KST)

- **Validated PR HEAD:** `22836a992cd38659b76c9d478fae5dc2f8777d4d`; PR #26 remains open and draft, based on `main`. Git comparison: **706 commits ahead, 0 behind**.
- **QIMA CI #784:** [run 41932439144](https://github.com/meridane/QimaTrade-MVP/actions/runs/41932439144) — **SUCCESS**, both jobs completed. The browser job log confirms **213/213 Playwright tests passed**. Dependency installation and audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #740:** [run 41932439257](https://github.com/meridane/QimaTrade-MVP/actions/runs/41932439257) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on this exact HEAD is **FAILURE**, with target `upgradeToPro=build-rate-limit`. This is a deployment-quota/rate-limit result, not evidence of a source compilation or test failure. The earlier QA194 code-bearing HEAD had Vercel status **PENDING** when checked; no successful Preview is claimed. No production deployment was performed.
- **Conclusion:** QA194 is validated by CI #784 (213/213) and CodeQL #740. The earlier QA194 reconciliation for the test-bearing HEAD is supplemented by this exact-HEAD record.
- **Security interpretation:** deterministic mocked-client regression for input normalization/fallback precedence; not evidence of a production vulnerability or authorization bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA195 — trim surrounding whitespace from demand scope product_master_id (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `f603292181da6fb44afa13d921dcd92fde219099`; PR #26 was open, draft, mergeable, based on `main`, 710 commits ahead and 0 behind.
- **Prior validation:** QIMA CI #786 (run 41933339146) completed successfully; the browser job log confirms **213 Playwright tests passed**. Both CI jobs (typecheck/audit/build/browser and isolated PostgreSQL CREATE_OFFER/RLS suites) succeeded. QIMA CodeQL #742 (run 41933339231) completed successfully.
- **Vercel:** combined status on the starting HEAD is **FAILURE** with target `upgradeToPro=build-rate-limit`; this is a deployment quota/rate-limit condition, not a source compilation or test failure. No Preview success is claimed for this HEAD.
- **Scenario:** submit a valid `demandId` without an explicit `productMasterId`; the mocked demand scope contains a valid product UUID padded with leading and trailing spaces.
- **Expected behavior:** the scope fallback trims the string before querying `product_masters`, so the lookup uses the canonical UUID and the inserted offer stores that normalized ID.
- **Assertions:** HTTP 303; exactly one demand lookup; product-master lookup uses the trimmed UUID and `status = active`; exactly one offer insertion; inserted `demand_id` is preserved, `product_master_id` equals the normalized UUID, market falls back to `South Korea`, lifecycle is `draft`, and offer type is `supplier_offer`.
- **Implementation contract:** `scope.product_master_id` is accepted only when it is a string, then `trim()` is applied and an empty result becomes `null`. This test covers normalization of a non-empty padded value.
- **Validation:** QIMA CI #787 (run 41943068255) completed with **SUCCESS**; both jobs passed and the browser job log confirms **214/214 Playwright tests passed**. Dependency audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded. QIMA CodeQL #743 (run 41943068246) completed with **SUCCESS**. The combined Vercel status on this exact HEAD was **SUCCESS** (Preview only; no production deployment).
- **Security interpretation:** deterministic mocked-client regression for input normalization; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.



## QA196 — handle a null demand scope without a product association (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `045f0290475fc982e42d93b6be49dcd30c132b3c`; PR #26 was open, draft, and mergeable, based on `main`, 711 commits ahead and 0 behind.
- **Prior validation (QA195):** QIMA CI #787 (run 41943068255) completed with **SUCCESS**; both jobs passed and the browser job log confirms **214/214 Playwright tests passed**. Dependency audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded. QIMA CodeQL #743 (run 41943068246) completed with **SUCCESS**. Combined Vercel status on the exact starting HEAD was **SUCCESS** (Preview only; no production deployment).
- **Scenario:** submit a valid `demandId`; the mocked demand has `scope: null`, and the form has no explicit `productMasterId`.
- **Expected behavior:** the handler treats a null scope as an empty object, does not derive a product ID, skips the `product_masters` lookup, and inserts the draft supplier offer with `product_master_id = null` while preserving the demand association and target market.
- **Assertions:** HTTP 303; exactly one demand lookup; zero product-master lookups; exactly one offer insertion; inserted `demand_id` equals the demand ID, `product_master_id` is null, market is `South Korea`, lifecycle is `draft`, and offer type is `supplier_offer`.
- **Implementation contract:** `typeof demand.scope === "object" && demand.scope !== null` guards object access; null and non-object scope values resolve to an empty object.
- **CI status:** pending for the QA196 test-bearing commit. Expected browser suite: **215 tests** (214 previously validated + QA196); record the exact GitHub Actions and CodeQL results after completion.
- **Security interpretation:** deterministic mocked-client regression for null-scope handling; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA196 — final validation reconciliation (5 November 2026, 12:09 KST)

- **Validated PR HEAD:** `229ba836b966e0c80a49bc36ca4978e8b5b159ee`; PR #26 remains open and draft, based on `main`. Git comparison: **712 commits ahead, 0 behind**.
- **QIMA CI #788:** [run 41950017465](https://github.com/meridane/QimaTrade-MVP/actions/runs/41950017465) — **SUCCESS**, both jobs completed. The browser job log confirms **215/215 Playwright tests passed (5.4 s)**. Dependency installation and audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #744:** [run 41950017491](https://github.com/meridane/QimaTrade-MVP/actions/runs/41950017491) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on this exact HEAD is **SUCCESS** (Preview only; no production deployment).
- **Conclusion:** QA196 is validated by CI #788 (215/215). The earlier pending note is superseded by this reconciliation.
- **Security interpretation:** deterministic mocked-client regression for null-scope handling; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA197 — primitive string demand scope is treated as empty (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `229ba836b966e0c80a49bc36ca4978e8b5b159ee`; PR #26 is open and draft, based on `main`, **712 commits ahead and 0 behind**.
- **Prior validation (QA196):** QIMA CI #788 (run 41950017465) completed with **SUCCESS**; both jobs passed and the browser job log confirms **215/215 Playwright tests passed (5.4 s)**. Dependency audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded. QIMA CodeQL #744 (run 41950017491) completed with **SUCCESS**. Combined Vercel status on this exact HEAD was **SUCCESS** (Preview only; no production deployment).
- **Scenario:** submit a valid `demandId` without an explicit `productMasterId`; the mocked demand returns a primitive string scope (`"legacy-scope"`).
- **Expected behavior:** because a string is not an object, the handler treats the scope as an empty object, does not derive a product ID, skips the `product_masters` lookup, and inserts the draft supplier offer with `product_master_id = null` while preserving the demand association and target market.
- **Assertions:** HTTP 303; exactly one demand lookup; zero product-master lookups; exactly one offer insertion; inserted `demand_id` equals the demand ID, `product_master_id` is null, market is `South Korea`, lifecycle is `draft`, and offer type is `supplier_offer`.
- **Implementation contract:** the scope fallback is guarded by `typeof demand.scope === "object" && demand.scope !== null`; a primitive string is converted to an empty object before reading `product_master_id`.
- **CI status:** pending for the QA197 test-bearing commit. Expected browser suite: **216 tests** (215 previously validated + QA197); record exact GitHub Actions, CodeQL, and Preview outcomes after completion.
- **Security interpretation:** deterministic mocked-client regression for non-object scope handling; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.




## QA197 — final validation reconciliation (5 November 2026, 12:20 KST)

- **Validated PR HEAD:** `455250935fe47d336fcc1fef724b66417d4d475b`; PR #26 is open, draft, mergeable, based on `main`. Git comparison: **715 commits ahead, 0 behind**.
- **QIMA CI #789:** [run 41960076027](https://github.com/meridane/QimaTrade-MVP/actions/runs/41960076027) — **SUCCESS**, both jobs completed. The browser job log confirms **216/216 Playwright tests passed (6.7 s)**, including QA197. Dependency installation from the committed lockfile, dependency audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #745:** [run 41960076042](https://github.com/meridane/QimaTrade-MVP/actions/runs/41960076042) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel:** combined status on this exact HEAD is **SUCCESS** (Preview only; no production deployment).
- **Conclusion:** QA197 is validated by CI #789 (216/216). The pending note in the initial QA197 entry is superseded by this reconciliation.
- **Security interpretation:** deterministic mocked-client regression for primitive scope handling; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA198 — array demand scope without a product association (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `455250935fe47d336fcc1fef724b66417d4d475b`; PR #26 is open, draft, mergeable, based on `main`, **715 commits ahead and 0 behind**.
- **Prior validation (QA197):** QIMA CI #789 (run 41960076027) completed with **SUCCESS**; both jobs passed and the browser job log confirms **216/216 Playwright tests passed (6.7 s)**. Dependency installation and audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded. QIMA CodeQL #745 (run 41960076042) completed with **SUCCESS**. Combined Vercel status on this exact HEAD was **SUCCESS** (Preview only; no production deployment).
- **Scenario:** submit a valid `demandId` without an explicit `productMasterId`; the mocked demand returns an array scope (`["legacy-scope"]`).
- **Expected behavior:** arrays satisfy JavaScript's `typeof value === "object"`, but the array has no `product_master_id` property. The handler should derive no product ID, skip the `product_masters` lookup, and insert the draft supplier offer with `product_master_id = null`, preserving the demand association and target market.
- **Assertions:** HTTP 303; exactly one demand lookup; zero product-master lookups; exactly one offer insertion; inserted `demand_id` equals the demand ID, `product_master_id` is null, market is `South Korea`, lifecycle is `draft`, and offer type is `supplier_offer`.
- **CI status:** pending for the QA198 test-bearing commit. Expected browser suite: **217 tests** (216 previously validated + QA198); record exact GitHub Actions, CodeQL, and Preview outcomes after completion.
- **Security interpretation:** deterministic mocked-client regression for array-scope property handling; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## Canonical register retrieval limitation (5 November 2026)

- The GitHub file reader returned the canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` blob SHA `a692e4f55171efd43a9600fab15e9bc4766206e8` but returned an empty content payload for both UTF-8 and base64 reads, including line-range reads. The raw GitHub fetch also rejected the file as oversized.
- To avoid replacing a 1 MB+ canonical register with partial or guessed content, this run leaves that canonical file unchanged and records the verified QA197 reconciliation plus QA198 entry in this append-only companion register.
- This is a tooling/size limitation, not evidence that the canonical file is empty or absent. The canonical update remains outstanding until its complete contents can be read safely.



## Canonical register update completed (5 November 2026, 12:22 KST)

- The complete canonical register blob was recovered through the Git data API (1,084,084 characters before the update).
- QA197 final validation reconciliation and the QA198 pending test entry were appended to `docs/QIMA_V1_FUNCTION_REGISTER.md` without replacing or truncating prior content.
- New canonical blob: `1b3b83bcc14e979f1bb110ff3ac13b6f68329eae` (1,087,804 characters).
- This supersedes the earlier tooling-limitation note: the ordinary file reader and raw-file endpoint could not return the oversized file, but the Git blob endpoint provided the complete text. No content was inferred or reconstructed from partial excerpts.



## QA198 — final validation on the test-bearing commit (5 November 2026, 12:23 KST)

- **Test-bearing PR HEAD:** `31f9ccd564c7d628bdeb14601ce3e4ad81601a73`; this commit contains the QA198 array-scope regression test.
- **QIMA CI #790:** [run 41961140475](https://github.com/meridane/QimaTrade-MVP/actions/runs/41961140475) — **SUCCESS**, both jobs completed. The browser job log confirms **217/217 Playwright tests passed (4.7 s)**, including QA198 at `legacy-offers-route-contract.spec.ts:2607`. Dependency installation, audit, TypeScript, Next.js build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #746:** [run 41961140471](https://github.com/meridane/QimaTrade-MVP/actions/runs/41961140471) — **SUCCESS**.
- **Vercel:** combined status on the test-bearing commit was **PENDING**; no Preview success is claimed for that SHA.
- **Conclusion:** QA198 is validated by CI #790 (217/217) and CodeQL #746. The later documentation-only HEAD `f45df253b5ddd8f2bf914120041f41af372928e2` had CI #791 and CodeQL #747 in progress when this entry was written.
- **Security interpretation:** mocked-client regression only; not proof of production database behavior, authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA198 — final validation reconciliation on documentation HEAD (5 November 2026, 13:15 KST)

- **Validated PR HEAD:** `34f1671f1390ca34044df1324da76958464b5de7`; PR #26 remains open and draft, based on `main`.
- **QIMA CI #792:** [run 41961392938](https://github.com/meridane/QimaTrade-MVP/actions/runs/41961392938) — **SUCCESS**, both jobs completed. Dependency audit, TypeScript, Next.js build, Chromium/browser smoke tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS succeeded. The same QA198 test code was explicitly confirmed as **217/217** by CI #790.
- **QIMA CodeQL #748:** [run 41961392855](https://github.com/meridane/QimaTrade-MVP/actions/runs/41961392855) — **SUCCESS**, no new alerts in PR-changed code.
- **Vercel:** commit status **FAILURE** with `Deployment rate limited — retry in 24 hours.` This is the Preview deployment quota, not a confirmed build failure; no Preview success is claimed.
- **Safety/security:** mocked tests do not establish production vulnerability; no production Supabase data, migration, policy, configuration, deployment, merge, or branch protection was changed.


## QA199 — explicit product lookup failure must not fall back to demand scope (5 November 2026)

- **Test:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Scenario:** explicit `productMasterId` is non-empty and differs from a valid-looking `scope.product_master_id`; the explicit lookup is simulated as unavailable/erroring.
- **Expected:** HTTP 400 with `PRODUCT_MASTER_NOT_FOUND`; only the explicit ID is looked up with `status = active`; no retry using the scope ID; no offer insertion.
- **Expected suite size:** 218 Playwright tests after adding QA199 (217 previously validated + 1).
- **CI/CodeQL/Preview:** pending on the new test-bearing PR HEAD.
- **Interpretation:** mocked-client regression for precedence behavior only, not evidence of production vulnerability or authorization bypass.


## QA199 — final validation reconciliation (5 November 2026, 14:12 KST)

- **Validated PR HEAD:** `6baf40283312cc054751ea55c7c2faaf028e3c4b`; PR #26 is open, draft, mergeable, based on `main`, 724 commits ahead and 0 behind.
- **QIMA CI #793:** [run 41966801129](https://github.com/meridane/QimaTrade-MVP/actions/runs/41966801129) — **SUCCESS**, both jobs completed. The browser job log confirms **218/218 Playwright tests passed (7.8 s)**, including QA199 at `legacy-offers-route-contract.spec.ts:2632`. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #749:** [run 41966801169](https://github.com/meridane/QimaTrade-MVP/actions/runs/41966801169) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment).
- **Conclusion:** QA199 is validated by CI #793 (218/218), CodeQL #749, and the Preview status. The earlier QA199 pending note is superseded by this entry.
- **Security interpretation:** deterministic mocked-client regression for source precedence on product lookup failure; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA200 — demand-scope fallback product lookup failure (5 November 2026, 14:12 KST)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `6baf40283312cc054751ea55c7c2faaf028e3c4b`; PR #26 remains open and draft, based on `main`.
- **Scenario:** submit a valid `demandId` with no explicit `productMasterId`; the mocked demand scope contains `product_master_id = PRODUCT_MASTER_ID`, while the fallback product lookup returns a simulated error and no product.
- **Expected behavior:** HTTP 400 with `PRODUCT_MASTER_NOT_FOUND`; lookup only the scope-derived ID with `status = active`; no offer insertion.
- **Assertions:** one authenticated-user lookup; one profile lookup; one demand lookup; product lookup for `PRODUCT_MASTER_ID` followed by `status = active`; zero offer insertions; null insert payload.
- **Expected browser suite:** **219 tests** (218 previously validated + QA200).
- **CI/CodeQL/Preview:** pending on the new test-bearing PR HEAD; record exact workflow IDs, outcomes, and the Preview status after completion.
- **Security interpretation:** deterministic mocked-client regression for the scope fallback failure path; not proof of production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA200 — final validation reconciliation (5 November 2026, 15:14 KST)

- **Validated PR HEAD:** `07a737560ad3d7ca0f75f9ee6148c7b2708d3d9c`; PR #26 is open and draft, based on `main`, 727 commits ahead and 0 behind.
- **QIMA CI #794:** [run 41972673845](https://github.com/meridane/QimaTrade-MVP/actions/runs/41972673845) — **SUCCESS**; both the browser/typecheck/audit/build job and isolated PostgreSQL CREATE_OFFER/concurrency/idempotency/RLS job completed successfully. The browser smoke-test step is successful; the exact aggregate Playwright count was not available from the fetched job metadata and is not asserted here.
- **QIMA CodeQL #750:** [run 41972673848](https://github.com/meridane/QimaTrade-MVP/actions/runs/41972673848) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment).
- **Conclusion:** QA200's test-bearing HEAD has successful QIMA CI, CodeQL, and Preview checks. This reconciliation supersedes the pending note in the initial QA200 entry.
- **Security interpretation:** the route-level test uses a mocked Supabase client; it does not prove live database behavior, authorization correctness, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA201 — scope fallback product lookup error takes precedence over returned data (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `07a737560ad3d7ca0f75f9ee6148c7b2708d3d9c`; PR #26 is open, draft, mergeable, based on `main`.
- **Scenario:** submit a valid `demandId` without an explicit `productMasterId`; the mocked demand scope contains `PRODUCT_MASTER_ID`. The mocked product lookup deliberately returns a product-shaped `data` value together with a non-null simulated error, exercising the handler's `productError || !product` guard.
- **Expected behavior:** HTTP 400 with `PRODUCT_MASTER_NOT_FOUND`; one demand lookup; one product lookup by the scope-derived ID followed by the `status = active` filter; no offer insertion.
- **Assertions:** one authenticated-user lookup; one profile lookup; one demand lookup; exactly the expected product lookup filters; zero offer insertions; null insert payload.
- **Expected browser suite:** 220 tests (the prior QA200 target of 219 plus QA201); this is an expectation, not a result.
- **CI/CodeQL/Preview:** pending on the new test-bearing PR HEAD. Record exact run URLs, outcomes, and the exact browser test count after completion.
- **Security interpretation:** this is a synthetic mocked-client test of error-precedence logic. The data-plus-error combination is intentionally defensive and does not establish that Supabase returns this combination in production, nor does it prove a vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## Canonical register retrieval limitation — 5 November 2026

- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` blob at the starting PR HEAD is `3dba1d25ecc73ddff31d9d48143c18e4200b41d1`. The GitHub file connector returned its blob metadata but an empty content body for both UTF-8 and base64 retrieval because the file is over 1 MiB.
- A raw-file fetch and a read-only container clone were also unavailable in this run. The canonical file was therefore not rewritten: doing so without its complete original content could truncate its history.
- QA200 reconciliation and QA201 are recorded in this append-only companion register. The canonical register remains unchanged pending a safe full-content retrieval path.


## QA201 — final validation reconciliation (5 November 2026, 16:40 KST)

- **Validated PR HEAD:** `d4ff1d3a619ada3ffd4f0bc1e0c1bcd71520e795`; PR #26 remains open and draft, based on `main`, **729 commits ahead and 0 behind**.
- **QIMA CI #795:** [run 41979357573](https://github.com/meridane/QimaTrade-MVP/actions/runs/41979357573) — **SUCCESS**, both jobs completed. The browser job log confirms **220/220 Playwright tests passed (7.0 s)**, including QA201 at `legacy-offers-route-contract.spec.ts:2701). Dependency installation, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #751:** [run 41979357561](https://github.com/meridane/QimaTrade-MVP/actions/runs/41979357561) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment).
- **Conclusion:** QA201 is validated by CI #795 (**220/220**), CodeQL #751, and the Preview status. The prior pending note is superseded.
- **Security interpretation:** deterministic mocked-client regression only. The data-plus-error combination does not establish actual Supabase production behavior or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA202 — scope fallback lookup returns no product without an error (5 November 2026)

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`.
- **Starting PR HEAD:** `d4ff1d3a619ada3ffd4f0bc1e0c1bcd71520e795`; PR #26 is open and draft, based on `main`, **729 commits ahead and 0 behind**.
- **Scenario:** submit a valid `demandId` without an explicit `productMasterId`; the mocked demand scope contains `PRODUCT_MASTER_ID`. The product lookup returns `data: null` and `error: null` (the mock's default when `productMasterError` is omitted).
- **Expected behavior:** HTTP 400 with `PRODUCT_MASTER_NOT_FOUND`; exactly one lookup for the scope-derived product ID followed by `status = active`; no offer insertion.
- **Assertions:** one authenticated-user lookup; one profile lookup; one demand lookup; exact product lookup filters; zero offer insertions; null insert payload.
- **Expected browser suite:** **221 tests** (220 previously validated + QA202); this is an expectation, not a result.
- **CI/CodeQL/Preview:** pending on the QA202 test-bearing commit. Record exact workflow IDs, outcomes, and the exact browser test count after completion.
- **Security interpretation:** deterministic mocked-client regression for the `!product` branch when the lookup error is null; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## Canonical register retrieval and update completed (5 November 2026, 16:40 KST)

- The complete canonical blob was recovered from GitHub's Git blob endpoint using the exact starting blob SHA `3dba1d25ecc73ddff31d9d48143c18e4200b41d1` (**1,095,955 characters**). This safely resolves the ordinary file-reader limitation recorded above.
- The QA201 final validation reconciliation and QA202 pending test entry were appended to this complete content; prior history was preserved without reconstruction from partial excerpts.
- This supersedes the earlier statement that the canonical update remained outstanding.


## QA202 — final validation reconciliation (5 November 2026, 16:40 KST)

- **Validated PR HEAD:** `26a276e27c562aa2197202f23f06e90a5931813c`; PR #26 is open, based on `main`, **732 commits ahead and 0 behind**.
- **QIMA CI #796:** [run 41989121234](https://github.com/meridane/QimaTrade-MVP/actions/runs/41989121234) — **SUCCESS**, both jobs completed. The browser job log confirms **221/221 Playwright tests passed (4.7 s)**; QA202 passed at `legacy-offers-route-contract.spec.ts:2733`. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #752:** [run 41989121265](https://github.com/meridane/QimaTrade-MVP/actions/runs/41989121265) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **PENDING** on this exact HEAD when checked; no Preview success is claimed.
- **Conclusion:** QA202 is validated by CI #796 (**221/221**) and CodeQL #752. Vercel Preview remains pending.
- **Security interpretation:** deterministic mocked-client regression for a null product row with a null lookup error; it validates the handler's `!product` branch but does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA202 — final validation reconciliation on documentation HEAD (5 November 2026, 16:40 KST)

- **Validated PR HEAD:** `97ff7e18f8c7b60fe43b343125df6d09f0689ad9`; PR #26 remains open, based on `main`, **734 commits ahead and 0 behind**.
- **QIMA CI #797:** [run 41989361453](https://github.com/meridane/QimaTrade-MVP/actions/runs/41989361453) — **SUCCESS**, both jobs completed. The browser job log confirms **221/221 Playwright tests passed (5.4 s)**, including QA202 at `legacy-offers-route-contract.spec.ts:2733`. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #753:** [run 41989361452](https://github.com/meridane/QimaTrade-MVP/actions/runs/41989361452) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment). This supersedes the earlier pending Preview status recorded for the test-bearing HEAD before the documentation-only follow-up.
- **Conclusion:** QA202 is validated on the latest documentation HEAD by CI #797 (**221/221**), CodeQL #753, and Preview status.
- **Security interpretation:** deterministic mocked-client regression only; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA202 — final validation reconciliation on canonical HEAD (5 November 2026, 17:22 KST)

- **Validated PR HEAD:** `b8276192e2d22cda5fec613461ae1933a959a705`; PR #26 is open and draft, based on `main`, **736 commits ahead and 0 behind**.
- **QIMA CI #798:** [run 41989603378](https://github.com/meridane/QimaTrade-MVP/actions/runs/41989603378) — **SUCCESS**, both jobs completed. The browser job log confirms **221/221 Playwright tests passed (6.6 s)**, including QA202 at `legacy-offers-route-contract.spec.ts:2733`. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #754:** [run 41989603377](https://github.com/meridane/QimaTrade-MVP/actions/runs/41989603377) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **FAILURE** on the checked commit status, with `api-deployments-free-per-day` / `build-rate-limit`. A separate PR comment contains an earlier Ready Preview deployment, but it cannot be tied conclusively to this exact HEAD; no new Preview success is claimed for this reconciliation.
- **Conclusion:** QA202 is validated by CI #798 (**221/221**) and CodeQL #754. Vercel Preview status for the exact HEAD is not confirmed successful.
- **Security interpretation:** deterministic mocked-client regression only; it does not prove production database behavior, an authorization bypass, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA203 — generic errors for legacy offer creation (5 November 2026, 17:22 KST)

- **Starting PR HEAD:** `b8276192e2d22cda5fec613461ae1933a959a705`; PR #26 is open and draft, based on `main`, **736 commits ahead and 0 behind**.
- **Source finding:** `lib/offers/create-legacy-offer.ts` returned raw `insertError.message` from the Supabase offer insert and raw `Error.message` from the outer exception handler in HTTP 500 responses.
- **Change:** both unexpected failure paths now return the stable public response `{ error: "Unable to create the offer." }`. Known validation/authentication responses remain unchanged. No exception details are returned to the client.
- **Regression coverage:** updated the existing insert-error and Supabase-client-initialization rejection tests to require the generic response and assert that the sentinel internal messages are absent. The Playwright suite count remains **221** because two existing tests were strengthened rather than adding new test cases.
- **Expected validation:** 221 Playwright tests on the QA203 HEAD; this is an expectation until CI completes.
- **CI/CodeQL/Preview:** pending on the QA203 test/code-bearing commit. Record exact workflow IDs, outcomes, and browser count after completion.
- **Security interpretation:** source inspection identified an internal-error disclosure path and the code now returns a generic public error. The deterministic mocked-client tests verify only the response contract; they do not establish that a production disclosure was exploited or that a confirmed vulnerability existed.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA203 — final validation reconciliation on the code-bearing HEAD (5 November 2026, KST)

- **Validated PR HEAD:** `df4dcf2668fce9c6864c26673f51e82b3cb2b652`; PR #26 remained open and draft, based on `main`, **737 commits ahead and 0 behind**.
- **QIMA CI #799:** [run 41994352970](https://github.com/meridane/QimaTrade-MVP/actions/runs/41994352970) — **SUCCESS**, both jobs completed. The browser job log confirms **221/221 Playwright tests passed (8.4 s)**, including the two strengthened generic-error regressions. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #755:** [run 41994353041](https://github.com/meridane/QimaTrade-MVP/actions/runs/41994353041) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment).
- **Conclusion:** QA203 is validated by CI #799 (**221/221**), CodeQL #755, and the successful Preview status on the exact HEAD.
- **Security interpretation:** source inspection identified raw internal exception messages in two legacy-route HTTP 500 paths and the code now returns a generic public message. Mocked-client regressions verify the response contract only; they do not establish that a production disclosure was exploited or that a confirmed vulnerability existed.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA204 — sanitize unexpected Universal CREATE_OFFER errors (5 November 2026, KST)

- **Starting PR HEAD:** `df4dcf2668fce9c6864c26673f51e82b3cb2b652`; PR #26 was open and draft, based on `main`, **737 commits ahead and 0 behind**.
- **Source finding:** `app/api/actions/create-offer/route.ts` returned arbitrary `Error.message` text from the Universal Action Runtime or Supabase/PostgREST RPC failures in HTTP 400 responses.
- **Change on code/test HEAD:** `95bd82e2e19fb84e8ca0b85db656415e9c3475c3` — an exact allowlist of documented CREATE_OFFER domain codes is preserved; all other thrown errors now return `{ error: "ACTION_FAILED" }` with HTTP 500. Raw database/RPC and unexpected exception text is not returned to the client.
- **Regression coverage:** two existing route tests were strengthened for execution-RPC and action-definition-RPC failures; one test was added to confirm that the exact allowlisted `INVALID_PRICE` code remains available to clients. Expected browser suite count: **222** (221 prior tests plus one new test).
- **Allowlisted codes:** `ACTION_NOT_PUBLISHED`, `ACTION_HANDLER_NOT_FOUND`, `UNAUTHENTICATED`, `TENANT_REQUIRED`, `IDEMPOTENCY_KEY_REQUIRED`, `ACTION_INPUT_REQUIRED`, `TENANT_ACCESS_DENIED`, `PROFILE_ACTOR_NOT_FOUND`, `INVALID_PROVIDER_ACTOR`, `INVALID_QUANTITY`, `INVALID_PRICE`, `INVALID_CURRENCY`, `PRODUCT_MASTER_NOT_FOUND`, `DEMAND_NOT_FOUND`, `IDEMPOTENCY_KEY_REUSE`, and `ACTION_ALREADY_RUNNING`. Matching is exact; arbitrary message prefixes or suffixes are not allowlisted.
- **Validation on code/test HEAD:** QIMA CI #800 [run 42004698684](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004698684) — **IN PROGRESS** at documentation time; npm audit and TypeScript had succeeded, production build and isolated PostgreSQL/browser jobs were still running. QIMA CodeQL #756 [run 42004698483](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004698483) — **IN PROGRESS**. Vercel combined status — **PENDING**; Preview Comments check had succeeded. Final outcomes and exact Playwright count must be reconciled after completion.
- **Security interpretation:** source inspection confirms that raw exception text was passed to the response; the new exact-code allowlist prevents unrecognized RPC/runtime text from crossing the route boundary. Synthetic HTTP/RPC mocks verify this response contract only and do not prove a production disclosure or exploitation.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.
