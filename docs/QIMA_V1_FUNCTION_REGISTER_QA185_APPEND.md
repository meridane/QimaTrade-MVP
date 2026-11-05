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
