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


## QA204 — validation reconciliation after the code/test workflow (5 November 2026, KST)

- **Code/test HEAD:** `95bd82e2e19fb84e8ca0b85db656415e9c3475c3`.
- **QIMA CI #800:** [run 42004698684](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004698684) — overall conclusion **CANCELLED** after the subsequent documentation-only commit triggered a newer PR workflow. This is not recorded as a full CI success. The browser job's completed log nevertheless confirms **222/222 Playwright tests passed (5.7 s)**, including both generic-RPC-error regressions and the exact `INVALID_PRICE` allowlist case. The PostgreSQL integration/RLS job completed **SUCCESS**; npm audit, TypeScript, Next.js build, Chromium installation, browser tests, and job cleanup steps all completed successfully before the workflow-level cancellation.
- **QIMA CodeQL #756:** [run 42004698483](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004698483) — **SUCCESS**.
- **Vercel on the code/test HEAD:** combined status remained **PENDING** when checked; the Vercel Preview Comments check completed **SUCCESS**. No Preview deployment success is claimed for this exact code/test HEAD.
- **Documentation HEAD at reconciliation time:** `dd14bb996bf2ad2a391234bea1409d225bbd4d78`. QIMA CI #801 [run 42004885883](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004885883) and CodeQL #757 [run 42004885859](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004885859) were **IN PROGRESS**. On CI #801, npm audit, TypeScript, and production build had succeeded; Chromium installation and isolated PostgreSQL tests were still running. Vercel combined status was **PENDING**.
- **Conclusion:** the QA204 browser regressions are confirmed **222/222**, the isolated PostgreSQL/RLS job passed, and CodeQL #756 passed. A full successful CI conclusion for the current documentation HEAD is still pending; do not label the cancelled CI #800 as SUCCESS.
- **Security interpretation:** deterministic route/RPC mocks verify exact error-code allowlisting and generic fallback behavior only. They do not prove a production disclosure, exploitation, or confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA204 — final validation on the complete code-and-documentation HEAD (5 November 2026, KST)

- **Validated HEAD:** `dd14bb996bf2ad2a391234bea1409d225bbd4d78`; this documentation HEAD contains the QA204 route change and regression tests from parent commit `95bd82e2e19fb84e8ca0b85db656415e9c3475c3`.
- **QIMA CI #801:** [run 42004885883](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004885883) — **SUCCESS**, both jobs completed. Browser logs confirm **222/222 Playwright tests passed (5.9 s)**, including the two generic RPC error cases and exact allowlisted `INVALID_PRICE` case. npm install, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #757:** [run 42004885859](https://github.com/meridane/QimaTrade-MVP/actions/runs/42004885859) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment).
- **Conclusion:** QA204 is fully validated on the complete code-and-documentation HEAD by CI #801 (**222/222**), CodeQL #757, and the successful Preview status. CI #800 on the preceding code/test-only commit was cancelled after the documentation follow-up; its browser log still recorded 222/222 and its PostgreSQL job passed, but the full-success claim is based on CI #801.
- **Latest documentation-only HEAD at reconciliation time:** `21128b5335215d173debe14d7b450795cae0d4fc`. QIMA CI #802 [run 42005174341](https://github.com/meridane/QimaTrade-MVP/actions/runs/42005174341) and CodeQL #758 [run 42005174331](https://github.com/meridane/QimaTrade-MVP/actions/runs/42005174331) were **IN PROGRESS**. On CI #802, npm audit and TypeScript had succeeded; production build and isolated PostgreSQL integration were still running. Vercel combined status was **FAILURE** with `api-deployments-free-per-day` / `build-rate-limit`; this is a Preview quota limit, not a compilation failure.
- **Security interpretation:** deterministic route/RPC mocks verify the API error response contract only; they do not prove a production disclosure, exploitation, or confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA204 — final validation reconciliation on canonical PR HEAD (5 November 2026, 19:47 KST)

- **Validated PR HEAD:** `18b1369087a4ce76f6dade6b4989d22dc4d2926c`; PR #26 remains open and draft, based on `main`, **741 commits ahead and 0 behind**.
- **QIMA CI #803:** [run 42005382356](https://github.com/meridane/QimaTrade-MVP/actions/runs/42005382356) — **SUCCESS**, both jobs completed. The browser job log confirms **222/222 Playwright tests passed (7.9 s)**. Dependency installation from the committed lockfile, npm audit, TypeScript, Next.js production build, Chromium installation, browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #759:** [run 42005382202](https://github.com/meridane/QimaTrade-MVP/actions/runs/42005382202) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **FAILURE** on this exact HEAD, target URL `upgradeToPro=build-rate-limit`; this is a Preview deployment quota limit, not evidence of a compilation failure. No successful Preview deployment is claimed for this exact HEAD.
- **Conclusion:** QA204 is validated on the canonical PR HEAD by CI #803 (**222/222**), CodeQL #759, and the successful isolated PostgreSQL/RLS job. Vercel Preview is blocked by quota.
- **Security interpretation:** the exact allowlist and generic fallback are verified by deterministic route/RPC mocks; these tests do not establish a production disclosure, exploitation, or confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA205 — require exact CREATE_OFFER public error-code matches (5 November 2026, 19:47 KST)

- **Starting PR HEAD:** `18b1369087a4ce76f6dade6b4989d22dc4d2926c`; PR #26 is open and draft, based on `main`, **741 commits ahead and 0 behind**.
- **Test file:** `tests/e2e/create-offer-route-contract.spec.ts`.
- **Scenario:** the mocked `execute_create_offer_v1` RPC returns HTTP 400 with each of these messages: `INVALID_PRICE: database constraint failed`, `INVALID_PRICE database constraint failed`, and `database constraint failed: INVALID_PRICE`.
- **Expected behavior:** all three messages are rejected by the exact allowlist and produce HTTP 500 with exactly `{ error: "ACTION_FAILED" }`; no diagnostic/database suffix or prefix is returned. The existing exact `INVALID_PRICE` test remains the positive control and must continue to return HTTP 400 with `{ error: "INVALID_PRICE" }`.
- **Regression coverage:** one new Playwright test containing three deterministic RPC-message variants. Expected browser suite: **223 tests** (222 previously validated + QA205).
- **CI/CodeQL/Preview:** pending on the new QA205 test-bearing HEAD; record exact workflow IDs, job outcomes, and browser count after completion.
- **Security interpretation:** this test verifies exact string matching in a mocked RPC failure path only. It does not prove that production RPCs emit these messages, that a disclosure was exploited, or that a confirmed vulnerability exists.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA205 — final validation on PR HEAD (5 November 2026, 20:18 KST)

- **Validated PR HEAD:** `293a79359c884434d60bff2c139b7adae9c5788c`; PR #26 is open and draft, based on `main`, **742 commits ahead and 0 behind**; mergeable state was `clean`. No submitted reviews or unresolved review threads were present at this check.
- **QIMA CI #804:** [run 42013903013](https://github.com/meridane/QimaTrade-MVP/actions/runs/42013903013) — **SUCCESS**, both jobs completed. Browser log confirms **223/223 Playwright tests passed (5.8 s)**. npm install, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #760:** [run 42013903124](https://github.com/meridane/QimaTrade-MVP/actions/runs/42013903124) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview only; no production deployment).
- **Conclusion:** QA205 is validated on the current PR HEAD by CI #804 (**223/223**), CodeQL #760, and successful Preview status.
- **Security interpretation:** the three diagnostic-message variants are deterministic mocked RPC responses; passing tests verifies exact string matching only. They do not prove that production emitted such messages or that a disclosure was exploited.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA206 — reconcile Universal CREATE_OFFER public error allowlist (5 November 2026, 20:18 KST)

- **Starting PR HEAD:** `293a79359c884434d60bff2c139b7adae9c5788c`; PR #26 open/draft, **742 ahead / 0 behind**.
- **Sources reviewed:** `app/api/actions/create-offer/route.ts`, `lib/actions/engine.ts`, `lib/actions/runtime.ts`, and `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql`.
- **SQL exception inventory:** the CREATE_OFFER SQL function raises exactly these 15 named codes: `UNAUTHENTICATED`, `TENANT_REQUIRED`, `IDEMPOTENCY_KEY_REQUIRED`, `ACTION_INPUT_REQUIRED`, `TENANT_ACCESS_DENIED`, `PROFILE_ACTOR_NOT_FOUND`, `INVALID_PROVIDER_ACTOR`, `INVALID_QUANTITY`, `INVALID_PRICE`, `INVALID_CURRENCY`, `PRODUCT_MASTER_NOT_FOUND`, `DEMAND_NOT_FOUND`, `ACTION_NOT_PUBLISHED`, `IDEMPOTENCY_KEY_REUSE`, and `ACTION_ALREADY_RUNNING`.
- **Engine classification:** `ACTION_NOT_PUBLISHED` and `ACTION_HANDLER_NOT_FOUND` are emitted by the action engine. `ACTION_NOT_PUBLISHED` is also emitted by the SQL function and remains a public domain response. `ACTION_HANDLER_NOT_FOUND` means the server has no registered handler for the action; it is an internal dispatch/configuration failure, not a caller-correctable domain error. It was therefore removed from the public allowlist and must map to generic HTTP 500 `ACTION_FAILED`.
- **Direct route responses:** `INVALID_REQUEST_BODY`, `NAME_AND_DEMAND_REQUIRED`, `TENANT_MEMBERSHIP_REQUIRED`, and `TENANT_SELECTION_REQUIRED` are returned directly before the catch boundary; they are not members of the thrown-error allowlist. Existing direct validation/authentication responses remain unchanged.
- **Regression matrix added:** one Playwright test exercises all 15 exact SQL domain codes as mocked RPC errors and expects the exact HTTP 400 body. It also exercises the exact internal `ACTION_HANDLER_NOT_FOUND` message at the definition-RPC boundary and expects generic HTTP 500 `ACTION_FAILED`. The existing unpublished-action test remains the engine-side positive coverage for `ACTION_NOT_PUBLISHED`.
- **Expected browser suite:** **224 tests** (223 previously validated + QA206). Validation on the new HEAD is pending; do not claim a pass until CI logs confirm it.
- **Security interpretation:** the matrix uses deterministic RPC mocks and source-level inventory. It validates public error classification, not live Supabase behavior or a confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA206 — final validation on canonical PR HEAD (5 November 2026, 21:46 KST)

- **Validated PR HEAD:** `1c699c13a2031bdc6e61b0eb2e14e0ea08a79f39`; PR #26 remains open and draft, based on `main`, **743 commits ahead and 0 behind**, mergeable. No submitted reviews or unresolved inline review threads were present at this check.
- **QIMA CI #805:** [run 42018291242](https://github.com/meridane/QimaTrade-MVP/actions/runs/42018291242) — **SUCCESS**, both jobs completed. Browser job log confirms **224/224 Playwright tests passed (7.1 s)**, including the QA206 15-code SQL-domain matrix and internal `ACTION_HANDLER_NOT_FOUND` masking case. Dependency installation from the committed lockfile, npm audit, TypeScript, Next.js production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #761:** [run 42018292063](https://github.com/meridane/QimaTrade-MVP/actions/runs/42018292063) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this exact HEAD (Preview status only; no production deployment).
- **Conclusion:** QA206 is validated on the actual PR HEAD by CI #805 (**224/224**), CodeQL #761, and successful Preview status.
- **Security interpretation:** the SQL-code matrix uses source inspection and deterministic RPC mocks; the internal dispatch failure is simulated at the route boundary and separately covered by action-engine unit tests. This verifies classification and response behavior, not live production RPC behavior, exploitation, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA207 — add a source-level error-contract drift guard (5 November 2026, 21:46 KST)

- **Starting PR HEAD:** `1c699c13a2031bdc6e61b0eb2e14e0ea08a79f39`; PR #26 is open/draft, based on `main`, **743 commits ahead and 0 behind**.
- **Source review:** the public CREATE_OFFER allowlist in `app/api/actions/create-offer/route.ts` contains the 15 exact SQL domain codes. The migration `20261027090000_fix_create_offer_action_status_contract.sql` emits those codes; the isolated low-level `create_offer_v1` fixture emits an overlapping subset. The action engine separately emits `ACTION_NOT_PUBLISHED` and internal `ACTION_HANDLER_NOT_FOUND`.
- **Planned regression:** add a Playwright source-contract test that parses the route allowlist, migration `RAISE EXCEPTION` codes, low-level SQL fixture codes, and action-engine error codes. Assert that the route allowlist equals the migration code set, fixture codes are a subset, `ACTION_NOT_PUBLISHED` remains public, and `ACTION_HANDLER_NOT_FOUND` remains internal.
- **Expected browser suite:** **225 tests** (224 previously validated + QA207). Validation is pending until the new commit's CI logs confirm the result.
- **Scope:** test-only change plus append-only documentation; no production migration or data change.
- **Security interpretation:** this is a static source/fixture consistency guard. It does not establish live database behavior or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA207 — pre-CI regex correction (5 November 2026, 21:47 KST)

- **Initial implementation commit:** `5474e212a0dd8d0876e9626e35d09161b7954c84`.
- **Review finding:** source review caught over-escaped regular-expression literals in the newly added static contract test before any QA207 success was claimed. The follow-up replaces them with the intended whitespace/grouping expressions.
- **Preflight:** the corrected extraction was checked against the current branch sources: 15 route allowlist codes, 15 migration codes, and 8 low-level fixture codes. Route/migration sets match exactly; all fixture codes are a subset; engine errors include `ACTION_NOT_PUBLISHED` and `ACTION_HANDLER_NOT_FOUND`.
- **Validation:** QA207 remains pending until GitHub Actions confirms the complete browser suite (expected **225 tests**) on the corrected commit.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA207 — final validation on corrected PR HEAD (5 November 2026, 21:53 KST)

- **Validated code/test HEAD:** `277533f7999ccee682ec95c4ba2c4373df46b152`; PR #26 remains open and draft, based on `main`, **745 commits ahead and 0 behind**, mergeable. The branch still has 44 files in its overall PR diff.
- **Initial draft attempt:** commit `5474e212a0dd8d0876e9626e35d09161b7954c84`, QIMA CI #806 [run 42030428027](https://github.com/meridane/QimaTrade-MVP/actions/runs/42030428027) — **FAILURE** in TypeScript at `tests/e2e/create-offer-route-contract.spec.ts:1091` (`TS1508: Unexpected ')'`). The source regex literals were over-escaped. Build and browser tests were skipped on this draft; the failure was a test-source compile error, not a failing assertion. Its PostgreSQL job was cancelled when the corrected commit superseded it. CodeQL #762 [run 42030428346](https://github.com/meridane/QimaTrade-MVP/actions/runs/42030428346) — **SUCCESS**; Vercel Preview status — **SUCCESS** on that draft commit.
- **Correction:** commit `277533f7999ccee682ec95c4ba2c4373df46b152` uses correctly escaped regex literals. A preflight against the branch sources confirmed 15 public allowlist codes, 15 migration codes, and 8 low-level fixture codes; the route/migration sets match exactly, all fixture codes are a subset, and the engine emits both `ACTION_NOT_PUBLISHED` and `ACTION_HANDLER_NOT_FOUND` while only the former is public.
- **QIMA CI #807:** [run 42030543705](https://github.com/meridane/QimaTrade-MVP/actions/runs/42030543705) — **SUCCESS**, both jobs completed. Browser logs confirm **225/225 Playwright tests passed (4.4 s)**; npm ci, dependency audit, TypeScript, Next.js production build, Chromium installation, browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #763:** [run 42030543672](https://github.com/meridane/QimaTrade-MVP/actions/runs/42030543672) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on the corrected code/test HEAD (Preview only; no production deployment).
- **Conclusion:** QA207 is validated on the corrected code/test HEAD by CI #807 (**225/225**), CodeQL #763, and successful Preview status. The initial CI #806 failure is retained as history and is not represented as a passing run.
- **Security interpretation:** this static source/fixture contract guard checks code-set consistency. Its assertions and route mocks do not establish live production database behavior, exploitation, or a confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA208 — enforce RFC 6750 Bearer credential syntax (5 November 2026, 22:21 KST)

- **Starting PR HEAD:** `b4af593599387dd01059937afd41f5abe7525b75`; PR #26 is open and draft, based on `main`, 746 commits ahead and 0 behind, mergeable. The branch has 44 files in its overall PR diff.
- **Baseline reconciliation:** QA207 is validated on the PR HEAD by QIMA CI #808 [run 42030903305](https://github.com/meridane/QimaTrade-MVP/actions/runs/42030903305), with **225/225 Playwright tests passed (5.2 s)**; PostgreSQL CREATE_OFFER integration/concurrency/idempotency, both RLS regression jobs, npm ci, dependency audit, TypeScript, Next.js build and Chromium all succeeded. CodeQL #764 [run 42030903379](https://github.com/meridane/QimaTrade-MVP/actions/runs/42030903379) succeeded. Vercel combined Preview status was success on this exact HEAD.
- **Finding:** the route used `/^Bearer +(\\S+)$/i`, which enforced the SP separator but accepted any non-whitespace credential characters. RFC 6750's `b64token` grammar is narrower: one or more ASCII letters/digits or `- . _ ~ + /`, followed only by optional trailing `=` padding. For example, comma/colon characters and interior padding should be rejected by the route parser before Auth is called. This is a parser-contract hardening finding; it does not show that Supabase accepted such credentials or that an authentication bypass occurred.
- **Change:** replace the broad non-whitespace capture with `/^Bearer +([-A-Za-z0-9._~+\\/]+={0,})$/i`. The scheme remains case-insensitive, one or more literal SP separators remain accepted, and valid RFC 6750 token characters plus trailing padding are preserved. HTAB and malformed token punctuation are rejected before any Supabase request.
- **Regression:** add one Playwright case with three malformed credentials (comma, colon, and non-trailing `=`) asserting HTTP 401, `UNAUTHENTICATED`, and zero mocked Supabase requests; also verify a valid credential using the allowed punctuation alphabet and trailing padding reaches Auth unchanged. Existing repeated-space and tab-separator cases remain in place.
- **Expected browser suite:** **226 tests** (225 previously validated + QA208). Validation is pending until GitHub Actions confirms the complete suite on the published commit.
- **Scope:** one route parser change, one regression test, and append-only register updates. No database or migration changes.
- **Security interpretation:** the route parser's acceptance of a broader syntactic token alphabet is confirmed by source inspection; authentication rejection/acceptance is not inferred from mocks. This is not evidence of an authentication bypass or confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA208 — pre-publication test-source correction (5 November 2026, 22:23 KST)

- **Work-branch draft:** `3dee837b265cf8abdf8cd7921cd743914abf8cae` contained escaped template-literal delimiters in the newly inserted Playwright test because the patch was authored as a raw template string.
- **Review outcome:** inspection of the generated Git diff caught the malformed source before the work branch was advanced to the PR branch. The test now builds the Authorization value with ordinary string concatenation (`"Bearer " + credential`), avoiding nested-template escaping entirely.
- **Publication/CI:** the malformed draft was never pushed to `fix/create-offer-status-contract` and no CI success is claimed for it. The corrected follow-up commit is the only QA208 commit intended for the PR branch.
- **Safety:** no production data, migration, policy, configuration, deployment, merge, or branch-protection setting was changed.

## QA208 — history correction for preflight draft (5 November 2026, 22:24 KST)

- **Accuracy correction:** the first work-branch commit `3dee837b265cf8abdf8cd7921cd743914abf8cae` did contain escaped template-literal delimiters in the new test. The corrected commit `9a257e48597278defc6136578b04490b5a9c5324` was created as its child to preserve fast-forward history. Consequently, the draft commit is an ancestor in the PR branch history; it was not the PR branch tip and the PR branch was advanced only to the corrected child.
- **Validation status:** no CI success is claimed for the malformed intermediate tree. The published PR HEAD contains the corrected test source and RFC 6750 route parser. The earlier wording that the draft was never present in the PR branch history is superseded by this correction.
- **Safety:** no production data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA209 — RFC 6750 WWW-Authenticate challenge for CREATE_OFFER (5 November 2026, 23:32 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 749 commits ahead of `main`, 0 behind, with 44 files in the overall diff. Starting HEAD: `59eadd55fb529b48ad98b9df84a727638942f180`.
- **Baseline verification:** QIMA CI #810 [run 42035568348](https://github.com/meridane/QimaTrade-MVP/actions/runs/42035568348) completed successfully. Its browser job confirms **226 Playwright tests passed (8.9 s)**; npm install, dependency audit, TypeScript, Next.js production build, Chromium/browser tests and the isolated PostgreSQL CREATE_OFFER, legacy-message RLS and participant self-enrollment jobs all succeeded. QIMA CodeQL #766 [run 42035568164](https://github.com/meridane/QimaTrade-MVP/actions/runs/42035568164) succeeded. The combined Vercel status on the starting HEAD was success (Preview status only).
- **Compatibility review:** existing tests and `tests/e2e/auth-smoke.spec.ts` assert HTTP 401 and JSON `{ error: "UNAUTHENTICATED" }`; they do not assert response headers. QA209 therefore adds `WWW-Authenticate` while preserving the existing status and JSON body.
- **Change:** missing or syntactically malformed Bearer credentials now receive `WWW-Authenticate: Bearer realm="qimatrade"` without an error parameter. A syntactically valid credential rejected by Supabase Auth with HTTP 401 receives `WWW-Authenticate: Bearer realm="qimatrade", error="invalid_token"`. The JSON body remains exactly `{ error: "UNAUTHENTICATED" }` and the status remains 401.
- **Error classification:** the `invalid_token` challenge parameter is emitted only when no user is returned or Supabase Auth reports status 401. Other Auth error statuses retain the generic Bearer realm challenge, avoiding an unsupported claim that every Auth service error means an invalid token.
- **Regression:** add one Playwright case covering missing credential, non-Bearer credential and a syntactically valid token rejected by Auth. It checks the exact challenge header, unchanged HTTP/body contract, and that malformed credentials make no Supabase request while a rejected token causes only the Auth lookup.
- **Expected browser suite:** 227 tests (226 baseline + QA209). Validation is pending until GitHub Actions completes on the published HEAD.
- **Scope:** one route helper, response-header capture in the existing test helper, one regression test, and append-only documentation. No migration, database, tenant authorization, or public JSON/status contract change.
- **Standards interpretation:** the challenge header is a protocol interoperability improvement. The mocked Auth response verifies route mapping only; it does not prove live Supabase token behavior or a production authentication vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA209 — Auth error classification follow-up (5 November 2026, 23:38 KST)

- **QA209 baseline result:** commit `7bc63ee604e97404ded3236ed3ad40f9caf0317d` passed QIMA CI #811 [run 42046693979](https://github.com/meridane/QimaTrade-MVP/actions/runs/42046693979), including **227/227 Playwright tests passed (7.6 s)**, npm ci, dependency audit, TypeScript, Next.js build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS. QIMA CodeQL #767 [run 42046694057](https://github.com/meridane/QimaTrade-MVP/actions/runs/42046694057) succeeded. Vercel combined Preview status was success.
- **Review correction:** Supabase Auth can return `user = null` alongside an Auth error for statuses other than 401. The initial predicate `!user || userError?.status === 401` would therefore attach `error="invalid_token"` to a non-401 Auth service failure. This was a classification imprecision in the newly added challenge metadata, not evidence of a production authentication issue.
- **Correction:** use `userError ? userError.status === 401 : !user`. The `invalid_token` challenge parameter is now emitted only for an Auth 401 (or a null user without an accompanying error); non-401 Auth service errors receive the generic Bearer realm challenge.
- **Regression:** the existing QA209 test now includes a synthetic Auth 503 response. It verifies the route preserves its existing HTTP 401/JSON contract while omitting the `invalid_token` parameter. The mock returns a distinct `server_error` body for the 503 case.
- **Expected browser suite:** remains 227 tests; the QA209 follow-up validation is pending on the new HEAD.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA209 — final validation of RFC 6750 challenge contract (5 November 2026, 23:43 KST)

- **Validated HEAD:** `27fdc996fa2d37e3627194fc6ddd3207c6e1a2af`. PR #26 remains open, draft, unmerged and mergeable; branch is 751 commits ahead of `main`, 0 behind, with 44 files in the overall diff.
- **QIMA CI #812:** [run 42047341098](https://github.com/meridane/QimaTrade-MVP/actions/runs/42047341098) — **SUCCESS**. Browser logs confirm **227/227 Playwright tests passed (4.9 s)**, including the QA209 missing/malformed credential, invalid-token 401 and synthetic Auth 503 challenge cases. npm ci, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #768:** [run 42047341068](https://github.com/meridane/QimaTrade-MVP/actions/runs/42047341068) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this HEAD (Preview only; no production deployment).
- **Final behavior:** missing or malformed credentials retain HTTP 401 and JSON `{ error: "UNAUTHENTICATED" }`, with `WWW-Authenticate: Bearer realm="qimatrade"`. A token rejected by Auth with status 401 receives the same JSON/status plus `error="invalid_token"`. A synthetic Auth 503 preserves the existing JSON/status and receives the realm-only challenge; it is not mislabeled as an invalid token.
- **Conclusion:** QA209 and its Auth-error-classification follow-up are validated on `27fdc99` by 227/227 Playwright, full PostgreSQL/RLS CI, CodeQL and successful Preview status. No failure is reported on this final HEAD.
- **Security interpretation:** tests use mocked Auth responses and verify route contract mapping; they do not establish live Supabase behavior, an authentication bypass, or a confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA210 — authenticate before parsing an unauthenticated request body (6 November 2026, 00:54 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 752 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `ef659c81066371f418b5f30884f0afe4adfb309b`.
- **Baseline checks:** QIMA CI #813 [run 42047670412](https://github.com/meridane/QimaTrade-MVP/actions/runs/42047670412) completed successfully. Both jobs succeeded: dependency install/audit, TypeScript, production build, Chromium/browser tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS. QIMA CodeQL #769 [run 42047670348](https://github.com/meridane/QimaTrade-MVP/actions/runs/42047670348) succeeded. The Vercel combined status on the starting HEAD is failure with a target URL indicating the Preview build-rate quota limit; this is not evidence of a source compilation failure.
- **Change:** add a focused Playwright regression proving that a request with a missing Authorization header and malformed JSON is rejected at the authentication gate first. The expected response remains HTTP 401, JSON `{ error: "UNAUTHENTICATED" }`, and `WWW-Authenticate: Bearer realm="qimatrade"`; no Auth, REST, or RPC request may be issued.
- **Why this boundary matters:** request parsing must not reveal body-validation behavior to a caller who has not supplied credentials. This test locks the current auth-before-body-parse ordering without changing the route or public response contract.
- **Expected browser suite:** 228 tests (227 baseline + QA210). Validation remains pending until GitHub Actions completes on the published commit.
- **Auth availability decision gate:** QA209 currently maps a synthetic Supabase Auth 503 to the legacy HTTP 401/JSON `UNAUTHENTICATED` response with a realm-only challenge. Changing this to propagate HTTP 503 would alter the public HTTP contract and client retry semantics. No status change is made without an explicit compatibility/product decision; the existing characterization test remains in place.
- **Scope:** one Playwright regression and append-only documentation. No application code, SQL migration, database, tenant authorization rule, or public API behavior is changed.
- **Security interpretation:** this test uses a mocked Auth boundary and verifies ordering/response mapping only. It does not establish a production vulnerability, live Supabase availability behavior, or an authentication bypass.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA210 — final validation (6 November 2026, 01:56 KST)

- **Validated HEAD:** `f3650b16075e3dbfbdebacd19d794afee1489daf`. PR #26 remains open, draft, unmerged and mergeable; branch is 753 commits ahead of `main`, 0 behind, with 44 files in the overall diff.
- **QIMA CI #814:** [run 42060060509](https://github.com/meridane/QimaTrade-MVP/actions/runs/42060060509) — **SUCCESS**. The browser job log confirms **228/228 Playwright tests passed (5.6 s)**, including QA210. npm ci, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #770:** [run 42060060400](https://github.com/meridane/QimaTrade-MVP/actions/runs/42060060400) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this HEAD (Preview only; no production deployment).
- **Conclusion:** QA210 is validated on `f3650b1` by 228/228 Playwright, full PostgreSQL/RLS CI, CodeQL and successful Preview status. No failure is reported on this HEAD.
- **Security interpretation:** the mocked request proves the route's ordering and response mapping only; it does not establish a production vulnerability or live Supabase behavior.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA211 — authenticated malformed JSON stops before profile and tenant access (6 November 2026, 02:00 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 753 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `f3650b16075e3dbfbdebacd19d794afee1489daf`.
- **Baseline checks:** QIMA CI #814 [run 42060060509](https://github.com/meridane/QimaTrade-MVP/actions/runs/42060060509) completed successfully. The browser job log confirms **228/228 Playwright tests passed (5.6 s)**. npm ci, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded. QIMA CodeQL #770 [run 42060060400](https://github.com/meridane/QimaTrade-MVP/actions/runs/42060060400) succeeded. The combined Vercel status on the starting HEAD is success (Preview only).
- **Change:** strengthen the existing authenticated malformed-JSON regression. It now asserts HTTP 400 with the exact body `{ error: "INVALID_REQUEST_BODY" }`, no `WWW-Authenticate` challenge, exactly one request to `/auth/v1/user`, and forwarding of the normalized Bearer token. No profile, membership, or RPC request may occur.
- **Ordering contract:** QA210 covers malformed JSON with no credential and expects zero Supabase requests. QA211 complements it with a valid mocked credential and proves authentication occurs once before body parsing, while profile/tenant/RPC access does not begin after parsing fails.
- **Expected browser suite:** remains **228 tests**; QA211 strengthens one existing test rather than adding another. Validation is pending until GitHub Actions completes on the published QA211 HEAD.
- **Scope:** one existing Playwright test and append-only updates to both function registers. No application code, SQL migration, database, tenant authorization rule, or public API behavior is changed.
- **Security interpretation:** this is a mocked route-ordering regression, not evidence of an authentication bypass, data exposure, or confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA212 — authenticated semantic validation stops before profile and tenant access (6 November 2026, 02:45 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 756 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `5cbf843d4e0ecd4e78ea411f2bd69c278de9d0b4`.
- **Baseline checks:** QIMA CI #815 [run 42070470018](https://github.com/meridane/QimaTrade-MVP/actions/runs/42070470018) completed successfully. Both jobs succeeded: dependency install/audit, TypeScript, Next.js production build, Chromium/browser smoke tests, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS. The job-step summary confirms the browser test step succeeded; it does not expose an exact Playwright count in this read. QIMA CodeQL #771 [run 42070469990](https://github.com/meridane/QimaTrade-MVP/actions/runs/42070469990) succeeded. The combined Vercel status is success on this HEAD (Preview only).
- **Change:** add one Playwright regression using a valid mocked Bearer credential and syntactically valid JSON with one invalid business field at a time: blank offer name, zero quantity, negative price, and unsupported currency. Each case must return HTTP 400 with its exact existing validation code, issue exactly one request to `/auth/v1/user`, and forward the normalized Bearer token. No profile lookup, tenant membership lookup, action-definition RPC, or execution RPC may occur.
- **Ordering contract:** QA210/QA211 cover malformed JSON before and after authentication. QA212 covers valid JSON that fails semantic validation, proving that authentication precedes validation while profile/tenant/action execution remains after all early input checks.
- **Expected browser suite:** 229 tests (228 baseline + one new QA212 test). Validation is pending until GitHub Actions completes on the published QA212 HEAD.
- **Scope:** one Playwright regression and append-only updates to the canonical and supplementary function registers. No application code, SQL migration, database, tenant authorization rule, or public API behavior is changed.
- **Security interpretation:** the test uses a mocked Supabase Auth/REST boundary and verifies request ordering and response mapping only. It does not establish a production vulnerability, data exposure, or live Supabase behavior.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA212 — final validation (6 November 2026, 03:11 KST)

- **Validated HEAD:** `1037768bbaf9618431aeec9069d38515b4b06741`. PR #26 remains open, draft, unmerged and mergeable; branch `fix/create-offer-status-contract` is 757 commits ahead of `main`, 0 behind, with 44 files in the overall diff.
- **QIMA CI #816:** [run 42078131376](https://github.com/meridane/QimaTrade-MVP/actions/runs/42078131376) — **SUCCESS**. Browser job logs confirm **229/229 Playwright tests passed (5.0 s)**, including QA212. npm install, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #772:** [run 42078131193](https://github.com/meridane/QimaTrade-MVP/actions/runs/42078131193) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this HEAD (Preview only; no production deployment).
- **Conclusion:** QA212 is validated on `1037768` by 229/229 Playwright tests, full PostgreSQL/RLS CI, CodeQL and successful Preview status.
- **Security interpretation:** the mocked route test verifies request ordering and validation mapping only; it does not establish a production vulnerability or live Supabase behavior.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA213 — characterize Auth transport failures without exposing diagnostics (6 November 2026, 03:11 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 757 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `1037768bbaf9618431aeec9069d38515b4b06741`.
- **Baseline checks:** QIMA CI #816 [run 42078131376](https://github.com/meridane/QimaTrade-MVP/actions/runs/42078131376) completed successfully. Browser logs confirm **229/229 Playwright tests passed (5.0 s)**. npm install, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded. QIMA CodeQL #772 [run 42078131193](https://github.com/meridane/QimaTrade-MVP/actions/runs/42078131193) succeeded. The combined Vercel status on the starting HEAD is success (Preview only).
- **Change:** extend the existing route-test mock with a deterministic transport-failure mode for the Supabase Auth `/auth/v1/user` fetch. Add one Playwright regression asserting the current route contract: HTTP 401, JSON `{ error: "UNAUTHENTICATED" }`, realm-only `WWW-Authenticate` challenge, no transport diagnostic in the public body, and no profile, tenant-membership or RPC request. Any retry requests made by the Auth client must remain confined to the Auth endpoint and carry the normalized Bearer credential.
- **Compatibility:** preserve the existing handling of Auth HTTP 503 and the public HTTP/JSON contract. This test characterizes a mocked fetch rejection; it does not decide whether Auth outages should become HTTP 503.
- **Expected browser suite:** 230 tests (229 baseline + one new QA213 test). Validation is pending until GitHub Actions completes on the published QA213 code commit.
- **Scope:** one Playwright helper and one regression, plus append-only updates to both function registers. No application code, SQL migration, database, tenant authorization rule, or production API behavior is changed.
- **Security interpretation:** the mocked network failure verifies error mapping and request boundaries only. It is not evidence of a live Supabase outage, a confirmed information disclosure, or a production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA213 — final validation of Auth transport-failure handling (6 November 2026, 03:11 KST)

- **Validated code HEAD:** `b1e3c234518458811c03842bfc26d2730ebe5595`. PR #26 remains open, draft, unmerged and mergeable; branch `fix/create-offer-status-contract` is 758 commits ahead of `main`, 0 behind, with 44 files in the overall diff.
- **QIMA CI #818:** [run 42082316820](https://github.com/meridane/QimaTrade-MVP/actions/runs/42082316820) — **SUCCESS**. Browser job logs confirm **230/230 Playwright tests passed (5.3 s)**, including QA213. npm install, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #773:** [run 42082316656](https://github.com/meridane/QimaTrade-MVP/actions/runs/42082316656) — **SUCCESS**, with no new alerts reported for the pull-request code.
- **Vercel:** no Vercel deployment/check/status was reported for this QA213 HEAD at final inspection. The prior HEAD had a successful combined Preview status; that result is not carried forward or claimed for this commit.
- **Observed SDK logging:** Supabase Auth logs the deliberately injected `ECONNRESET` exception to the CI job log while converting it to an Auth error. This expected test-harness log does not appear in the public HTTP JSON response; the regression confirms the route returns only `{ error: "UNAUTHENTICATED" }` with the realm-only challenge.
- **Conclusion:** QA213 is validated on `b1e3c23` by 230/230 Playwright tests, full PostgreSQL/RLS CI and CodeQL. No failure is reported on this code HEAD.
- **Security interpretation:** the mocked fetch rejection verifies route mapping and request boundaries only. It is not evidence of a live Supabase outage, confirmed information disclosure, or production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

### QA213 register-publication validation (6 November 2026, 03:11 KST)

- **QIMA CI #819:** [run 42082680711](https://github.com/meridane/QimaTrade-MVP/actions/runs/42082680711) — **SUCCESS** on documentation HEAD `d4f2d2809112ce46fbfaad81c4ce4492d3ddfe4a`. Browser logs reconfirm **230/230 Playwright tests passed (5.9 s)**; dependency install/audit, TypeScript, Next.js build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #774:** [run 42082680713](https://github.com/meridane/QimaTrade-MVP/actions/runs/42082680713) — **SUCCESS**, no new alerts reported.
- **Vercel:** no Vercel check or deployment status was attached to this documentation HEAD at inspection.
- **Conclusion:** both function-register updates and the QA213 test source are validated on `d4f2d28` by the complete CI and CodeQL workflows.

## QA214 — exact non-disclosure contract for profile and tenant-membership lookup errors (6 November 2026, 04:36 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 760 commits ahead of `main`, 0 behind, with 44 files in the overall diff. Starting HEAD: `e7bf419455f86315897e09b920fac9bf8857111e`.
- **Baseline checks:** QIMA CI #820 [run 42083107646](https://github.com/meridane/QimaTrade-MVP/actions/runs/42083107646) — **SUCCESS**. Browser job logs confirm **230/230 Playwright tests passed (4.5 s)**. Dependency installation/audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded. QIMA CodeQL #775 [run 42083107294](https://github.com/meridane/QimaTrade-MVP/actions/runs/42083107294) — **SUCCESS**. Vercel combined status on the starting HEAD — **SUCCESS** (Preview only).
- **Change:** strengthen the existing profile-lookup and tenant-membership-lookup error tests. The mocked PostgREST failures now include private sentinel values in `message`, `details` and `hint`, plus SQLSTATE-like code `XX000`. The public response is asserted with exact equality: `{ error: "PROFILE_ACTOR_NOT_FOUND" }` or `{ error: "TENANT_MEMBERSHIP_REQUIRED" }`, respectively. The tests also assert HTTP 403, no `WWW-Authenticate` header, exact request ordering, propagation of the same authenticated Bearer credential, and no subsequent tenant lookup (after profile failure) or RPC access.
- **Expected browser suite:** 230 tests; QA214 strengthens two existing tests and adds no new test case. Validation is pending on the newly published QA214 HEAD until GitHub Actions completes.
- **Scope:** one Playwright test file and append-only updates to both function registers. No application code, SQL migration, database, tenant authorization rule, or public API behavior is changed.
- **Security interpretation:** synthetic PostgREST errors verify response mapping and request boundaries only. They do not establish a production information disclosure, data exposure, or confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


### QA214 final validation and CI reconciliation (6 November 2026, 04:40 KST)

- **Code-only validation attempt — QIMA CI #821:** [run 42095770757](https://github.com/meridane/QimaTrade-MVP/actions/runs/42095770757) was **CANCELLED** after the PR branch advanced to include the register updates. Before cancellation, the browser step completed with **230/230 Playwright tests passed (5.6 s)**, and the isolated CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS steps all completed successfully. Because the overall workflow conclusion is cancelled, it is not counted as a full CI success. QIMA CodeQL #776 [run 42095770927](https://github.com/meridane/QimaTrade-MVP/actions/runs/42095770927) — **SUCCESS** on the code-only commit.
- **Final QA214 HEAD:** `5a2026647a30637a36d0fe97312fe3baa868d775`. QIMA CI #822 [run 42095917995](https://github.com/meridane/QimaTrade-MVP/actions/runs/42095917995) — **SUCCESS**. Browser job logs confirm **230/230 Playwright tests passed (6.2 s)**. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #777:** [run 42095918091](https://github.com/meridane/QimaTrade-MVP/actions/runs/42095918091) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on final QA214 HEAD `5a20266` (Preview only; no production deployment).
- **Conclusion:** QA214 is validated on `5a20266` by 230/230 Playwright tests, complete PostgreSQL/RLS CI, CodeQL and successful Preview status. The cancelled #821 attempt is retained as an intermediate history item and is not represented as a passing workflow.
- **Security interpretation:** diagnostic sentinel values exist only in the deterministic PostgREST test fixture. Exact-response assertions verify route mapping and request boundaries; they are not evidence of a live information disclosure, data exposure, or confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA215 — profile and tenant-membership upstream HTTP error matrix (6 November 2026, 05:55 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 765 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `5bd584df3ab6f300acd964b8d5aa38cad6d92e1b`.
- **Baseline checks:** QIMA CI #823 [run 42096312217](https://github.com/meridane/QimaTrade-MVP/actions/runs/42096312217) — **SUCCESS**; both jobs and all listed steps completed successfully. Browser job logs confirm **230/230 Playwright tests passed (7.5 s)**. Dependency installation, npm audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded. QIMA CodeQL #778 [run 42096312156](https://github.com/meridane/QimaTrade-MVP/actions/runs/42096312156) — **SUCCESS**. The combined status for the starting HEAD reports Vercel **FAILURE** with `build-rate-limit`; this is a Preview quota limitation, not a confirmed application build failure.
- **Change:** add one Playwright matrix regression that exercises profile lookup and tenant-membership lookup failures for simulated upstream HTTP statuses 401, 403 and 500. For each of the six mocked cases, assert the existing public HTTP 403 contract, exact generic JSON error (`PROFILE_ACTOR_NOT_FOUND` or `TENANT_MEMBERSHIP_REQUIRED`), absence of PostgREST diagnostic sentinels/SQLSTATE from the body, no `WWW-Authenticate` challenge, the expected request sequence, and no downstream tenant lookup or RPC after the relevant failure.
- **Compatibility:** no route code or public response contract is changed. The test records the current behavior that the handler normalizes profile/membership lookup failures to HTTP 403 regardless of the mocked upstream status. Any future change to this mapping requires a separate compatibility review.
- **Expected browser suite:** 231 tests (230 baseline + one new matrix test containing six mocked scenarios). Validation remains pending until GitHub Actions completes on the published QA215 HEAD.
- **Scope:** one Playwright test and append-only updates to the canonical and supplementary function registers. No application code, SQL migration, database, tenant authorization rule, or production API behavior is changed.
- **Security interpretation:** all upstream errors and sentinel diagnostics are deterministic test fixtures. The assertions characterize response mapping and request boundaries only; they do not establish a live Supabase information disclosure, data exposure, or confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

### QA215 final validation and CI reconciliation (6 November 2026, 05:55 KST)

- **Validated test HEAD:** `3c140be11e92642d965ca1bd1ae2f8fc5f8f45f4`. PR #26 remains open, draft, unmerged and mergeable; branch `fix/create-offer-status-contract` is 766 commits ahead of `main`, 0 behind, with 44 files in the overall diff.
- **QIMA CI #824:** [run 42108097852](https://github.com/meridane/QimaTrade-MVP/actions/runs/42108097852) — **SUCCESS**; both jobs completed successfully. Browser job logs confirm **231/231 Playwright tests passed (6.9 s)**, including QA215's six mocked upstream-status scenarios. npm installation, dependency audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #779:** [run 42108097854](https://github.com/meridane/QimaTrade-MVP/actions/runs/42108097854) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **SUCCESS** on validated test HEAD `3c140be` (Preview only; no production deployment).
- **Conclusion:** QA215 is validated on `3c140be` by 231/231 Playwright tests, complete isolated PostgreSQL/RLS CI, CodeQL and successful Preview status. The six profile/membership cases preserve the current HTTP 403 public mapping for simulated upstream 401, 403 and 500 responses.
- **Security interpretation:** PostgREST diagnostic sentinels and upstream status codes are deterministic test fixtures. The tests characterize the handler's existing mapping and request boundaries only; they do not establish live Supabase behavior, an information disclosure, or a confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA216 — CREATE_OFFER RPC error-boundary matrix (6 November 2026, 07:06 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 767 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `e9c4e23c6dd80581dbd545320eb769463114e6aa`.
- **Baseline checks:** QIMA CI #825 [run 42108420695](https://github.com/meridane/QimaTrade-MVP/actions/runs/42108420695) — **SUCCESS**; PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS, participant self-enrollment RLS, dependency installation/audit, TypeScript, Next.js build and browser-test job all completed successfully. QIMA CodeQL #780 [run 42108420650](https://github.com/meridane/QimaTrade-MVP/actions/runs/42108420650) — **SUCCESS**. Combined Vercel status on starting HEAD — **SUCCESS** (Preview only).
- **Change:** add two Playwright tests for the Universal CREATE_OFFER RPC boundary. The first exercises `get_action_definition_v1` with mocked upstream HTTP 400, 401, 403 and 500 responses; each case must return HTTP 500 with exact public JSON `{ error: "ACTION_FAILED" }`, omit the private diagnostic sentinel and stop before `execute_create_offer_v1`. The second exercises `execute_create_offer_v1` with the same four mocked statuses and asserts the same generic public response, no diagnostic disclosure, and the expected request sequence.
- **Request-boundary assertions:** both matrices verify the Auth, profile and membership lookups that precede the RPC, exact RPC ordering, and forwarding of the same Bearer credential to every mocked request. Definition lookup failure must prevent execution RPC; execution failure occurs only after a successful published-definition lookup.
- **Compatibility:** no route/runtime code or public response mapping is changed. Generic upstream RPC diagnostics continue to map to HTTP 500 and `ACTION_FAILED`. The existing exact allowlisted SQL domain-code test remains the separate coverage for legitimate business errors such as `INVALID_PRICE`.
- **Expected browser suite:** 233 tests (231 baseline + two new matrix tests; each test covers four mocked upstream statuses). Validation is pending until GitHub Actions completes on the published QA216 test commit.
- **Scope:** one Playwright file plus append-only updates to the canonical and supplementary function registers. No application code, SQL migration, database, tenant authorization rule, or production API behavior is changed.
- **Security interpretation:** all upstream HTTP statuses and private diagnostic strings are deterministic test fixtures. These tests characterize the route's error mapping and request ordering only; they do not establish live Supabase behavior, an information disclosure, or a confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting is changed.

### QA216 final validation and CI reconciliation (6 November 2026, 07:06 KST)

- **Validated test HEAD:** `a93b22402fea4eb30c5759ff8ad66a12e3c81117`. PR #26 remains open, draft, unmerged and mergeable; branch `fix/create-offer-status-contract` is 768 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **QIMA CI #826:** [run 42118859120](https://github.com/meridane/QimaTrade-MVP/actions/runs/42118859120) — **SUCCESS**; both jobs completed successfully. Browser job logs confirm **233/233 Playwright tests passed (8.3 s)**, including QA216's four mocked HTTP statuses for each RPC boundary. npm installation, npm audit, TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #781:** [run 42118859314](https://github.com/meridane/QimaTrade-MVP/actions/runs/42118859314) — **SUCCESS**; JavaScript/TypeScript analysis completed.
- **Vercel combined status:** **SUCCESS** on validated test HEAD `a93b224` (Preview only; no production deployment).
- **Conclusion:** QA216 is validated on `a93b224` by 233/233 Playwright tests, complete isolated PostgreSQL/RLS CI, CodeQL and successful Preview status. The two matrices cover mocked upstream HTTP 400, 401, 403 and 500 for action-definition lookup and execution RPC. Definition lookup failure prevents execution RPC; both failures map to exact generic HTTP 500 JSON without exposing the private diagnostic sentinel.
- **Compatibility:** no route/runtime code, public response mapping, SQL migration, or business authorization rule was changed. Existing exact allowlisted SQL domain-error handling remains covered separately.
- **Security interpretation:** upstream statuses and private diagnostic strings are deterministic test fixtures. The tests characterize the handler's current error mapping and request sequence only; they do not establish live Supabase behavior, an information disclosure, or a confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.

## QA217 — non-Error rejection propagation in the action engine (6 November 2026, 07:27 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Branch `fix/create-offer-status-contract` is 769 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `ed4e80c297ce7f683e07bd0852acd93fefe1ffb3`.
- **Baseline checks:** QIMA CI #827 [run 42119301941](https://github.com/meridane/QimaTrade-MVP/actions/runs/42119301941) — **SUCCESS**; both PostgreSQL/RLS and browser/typecheck/audit/build jobs completed successfully. Browser logs confirm **233/233 Playwright tests passed (5.9 s)**. QIMA CodeQL #782 [run 42119301828](https://github.com/meridane/QimaTrade-MVP/actions/runs/42119301828) — **SUCCESS**. Combined Vercel status on the starting HEAD — **SUCCESS** (Preview only).
- **Coverage audit:** `tests/e2e/action-engine.spec.ts` already verifies propagation of `Error` instances from both `getDefinition` and a registered handler, including call counts and no retry. QA217 avoids duplicating those cases.
- **Change:** add two regression tests for JavaScript rejection values that are not `Error` instances: an object rejection from `getDefinition`, and a string rejection from the registered handler. Assert that `executeAction` preserves the exact rejection value by identity/equality, calls each dependency exactly once, and never invokes the handler when definition lookup rejects.
- **Expected browser suite:** 235 tests (233 baseline + two focused rejection-shape tests). This is an expectation only; validation remains pending until GitHub Actions completes on the published QA217 code commit.
- **Scope:** one action-engine Playwright test file plus append-only updates to the canonical and supplementary function registers. No runtime engine code, route behavior, SQL migration, database, tenant authorization rule, or production API behavior is changed.
- **Security interpretation:** rejection values are deterministic in-process test fixtures. These tests characterize promise rejection propagation and call counts only; they do not establish a live service failure, information disclosure, or confirmed production vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting is changed.


## QA218 — additional inherited Object.prototype handler keys (6 November 2026, 08:36 KST)

- **Starting PR state:** PR #26 is open and unmerged; its description still identifies the change as a draft for review. Branch `fix/create-offer-status-contract` was 770 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `beffb7efefed89e9abf20c58dbace90b1de6b245`.
- **Baseline checks:** QIMA CI #828 [run 42121897800](https://github.com/meridane/QimaTrade-MVP/actions/runs/42121897800) — **SUCCESS**; browser job logs confirm **235/235 Playwright tests passed (8.9 s)**, and the isolated PostgreSQL CREATE_OFFER/concurrency and both RLS regression scripts passed. QIMA CodeQL #783 [run 42121897705](https://github.com/meridane/QimaTrade-MVP/actions/runs/42121897705) — **SUCCESS**. Vercel Preview status on the starting HEAD — **SUCCESS**.
- **Coverage audit:** `tests/e2e/action-engine.spec.ts` already checks inherited `toString` and `constructor` keys, as well as malformed registries and custom prototypes. The engine uses `Object.prototype.hasOwnProperty.call` before reading the handler. QA218 extends the existing inherited-key matrix rather than changing runtime behavior.
- **Change:** add `__proto__` and `hasOwnProperty` to `inheritedObjectPrototypeHandlerKeys`. The existing loop creates one regression case per key and asserts the key is not an own property, `executeAction` rejects with `ACTION_HANDLER_NOT_FOUND`, the definition is read once, and no other handler runs.
- **Expected browser suite:** 237 tests (235 baseline + two new loop cases). This is an expectation only until the Playwright step completes.
- **Published code commit:** `332b88b3137095984c819c7300f719b2279b24ea` — `test(actions): cover additional inherited prototype handler keys`. The diff changes only the key fixture in `tests/e2e/action-engine.spec.ts`.
- **Current validation on the code commit:** QIMA CI #829 [run 42130922864](https://github.com/meridane/QimaTrade-MVP/actions/runs/42130922864) — **IN PROGRESS** at documentation time. npm install, npm audit, TypeScript, production build, isolated PostgreSQL CREATE_OFFER/concurrency and both RLS scripts have completed successfully; Playwright Chromium installation is still running and browser tests have not started. QIMA CodeQL #784 [run 42130922870](https://github.com/meridane/QimaTrade-MVP/actions/runs/42130922870) — **SUCCESS**. Vercel Preview status on the code commit — **SUCCESS**.
- **Scope:** one existing action-engine test fixture plus this append-only addendum. No runtime engine code, route behavior, SQL migration, Supabase database, tenant authorization rule, or production API behavior is changed.
- **Security interpretation:** the special property names are deterministic in-process test inputs. These tests characterize own-property lookup and handler dispatch only; they do not establish a production prototype-pollution issue or confirmed vulnerability.
- **Canonical register limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` remains a >1 MiB historical file; the GitHub file-content connector returned its blob SHA but no body. It was not replaced or truncated. This QA record is preserved in this supplementary append-only register.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA219 — validate the action handler result envelope (6 November 2026, 09:51 KST)

- **Starting PR state:** PR #26 is open, draft and unmerged. Before QA219, branch `fix/create-offer-status-contract` was 772 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff. Starting HEAD: `5543581913077560c73bd30e7a7bf8392bbd871f`.
- **Baseline checks:** QIMA CI #830 [run 42131151009](https://github.com/meridane/QimaTrade-MVP/actions/runs/42131151009) — **SUCCESS**; the browser job log confirms **237 Playwright tests passed**, and the isolated PostgreSQL CREATE_OFFER/concurrency plus legacy-message and participant self-enrollment RLS regression jobs completed successfully. QIMA CodeQL #785 [run 42131150949](https://github.com/meridane/QimaTrade-MVP/actions/runs/42131150949) — **SUCCESS**. The combined Vercel status on the starting HEAD was **SUCCESS** (Preview only).
- **Contract review:** `ActionResult` requires a non-empty `executionId` string and a terminal `status` of `succeeded` or `failed`. Before QA219, `executeAction` returned the handler promise directly and did not check the resolved runtime value. The CREATE_OFFER route reads `result.status`, so validating the engine boundary avoids treating a malformed handler result as a valid ActionResult.
- **Runtime change:** add a narrow `isActionResult` guard in `lib/actions/engine.ts`. It requires an object (not null or an array), own `executionId` and `status` properties, a non-blank string execution ID, and a status equal to `succeeded` or `failed`. Await the handler once; throw the internal `ACTION_RESULT_INVALID` error for a malformed result. The route does not allowlist that internal code, so its existing catch boundary continues to return the generic `ACTION_FAILED` response without exposing the internal detail.
- **Regression coverage:** add four malformed-result cases to `tests/e2e/action-engine.spec.ts`: `null`, missing `executionId`, blank `executionId`, and unsupported `running` status. Add a positive control proving a valid `failed` ActionResult remains accepted. Every malformed case asserts one definition lookup and one handler invocation; no retry or synthetic success is introduced.
- **Expected browser suite:** 242 tests (237 baseline + four invalid-result cases + one valid-failed-result control). This is an expectation only; it is not a pass claim until the Playwright job on the published commit completes.
- **Published code commit:** `386ff62f67b357a6fe42a51eca70d5daf149f232` — `fix(actions): validate action handler result envelope`. The commit changes only `lib/actions/engine.ts` and `tests/e2e/action-engine.spec.ts`.
- **Scope and compatibility:** the change validates only the required ActionResult envelope fields already declared by `lib/actions/types.ts`; it does not alter the public response mapping, CREATE_OFFER SQL contract, idempotency behavior, or tenant authorization rules. Valid `succeeded` and `failed` results remain supported.
- **Initial post-publication status:** immediately after moving the PR branch to the code commit, GitHub Actions had not yet associated any pull-request workflow run with the new SHA; the Vercel status was **PENDING**. Recheck the exact code and final documentation HEADs before treating validation as complete.
- **Final validation on PR HEAD `f6ffaa5c312639c5f7664fd2757296034533a079`:** QIMA CI #833 [run 42146558932](https://github.com/meridane/QimaTrade-MVP/actions/runs/42146558932) — **SUCCESS**; browser log confirms **246/246 Playwright tests passed (6.8 s)**, including all four QA220 malformed optional-field cases and the valid optional-field control. npm ci, npm audit, TypeScript, production build, Chromium installation, PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS all completed successfully. QIMA CodeQL #788 [run 42146558983](https://github.com/meridane/QimaTrade-MVP/actions/runs/42146558983) — **SUCCESS**. Vercel deployment `dpl_3Jce7yfrphFDFYujqJ4zBW4Tha9y` is **READY** for this exact SHA; Preview: https://qimatrade-mvp-git-fix-create-offer-status-contract-bmk1.vercel.app.
- **Canonical register limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` is a >1 MiB historical file. The GitHub file-content connector returned its blob SHA `757b099679c51b417630ca03c413e46c143e510a` but an empty body; the raw-content fetch also failed because the file is too large. It was not replaced or truncated. This QA record is maintained in this supplementary append-only register until the canonical file can be safely retrieved in full.
- **Security interpretation:** malformed ActionResult values are deterministic in-process test fixtures. These tests verify the runtime contract and caller boundary only; they do not establish a production exploit or confirmed vulnerability.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA220 — validate optional ActionResult fields (6 November 2026, 10:48 KST)

- **Starting PR state:** PR #26 is open, draft and unmerged. Branch `fix/create-offer-status-contract` starts at `a9f2ebc41d844e38ca8d73637d0737b2866793ed`, 774 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **Baseline checks:** QIMA CI #832 [run 42140121327](https://github.com/meridane/QimaTrade-MVP/actions/runs/42140121327) — **SUCCESS**; the browser log confirms **242 Playwright tests passed (6.8 s)**. The separate isolated PostgreSQL CREATE_OFFER/concurrency/idempotency and both RLS regression steps also completed successfully. QIMA CodeQL #787 [run 42140121339](https://github.com/meridane/QimaTrade-MVP/actions/runs/42140121339) — **SUCCESS**. The combined Vercel status on the starting HEAD was **SUCCESS** (Preview only).
- **Contract review:** `ActionResult` declares optional `objectId?: string | null` and `result?: Record<string, unknown>`. The QA219 runtime guard checked required `executionId` and `status`, but did not validate optional fields when present. The proposed CREATE_OFFER SQL JSONB payload contains a string `objectId` and omits `result`; absence of `result` must remain valid.
- **Runtime change:** extend the existing guard so a present `objectId` must be a string or null, and a present `result` must be a non-null, non-array object. An omitted or explicitly undefined optional property remains equivalent to absence. Required `executionId` and terminal status checks are unchanged.
- **Regression coverage:** add four invalid handler-result cases: numeric `objectId`, null `result`, array `result`, and primitive `result`. Strengthen the valid failed-result control with `objectId: null` and an empty object `result`, preserving the supported optional shape.
- **Expected browser suite:** 246 tests (242 baseline + four invalid optional-field cases). This is an expectation only until the Playwright job on the published commit completes.
- **Published commits:** runtime validation `660d84d8863293693c9ddcabc919c29a10b8d8e5` (`fix(actions): validate optional ActionResult fields`); regression tests `b22553697d634cf36aa7865fc0aefb4a48623294` (`test(actions): cover optional ActionResult field validation`); initial QA220 addendum `f6ffaa5c312639c5f7664fd2757296034533a079`. All are ancestors of the published PR branch.
- **Compatibility/scope:** no SQL, RPC payload, public HTTP mapping, idempotency, or tenant-authorization behavior is changed. The guard follows the existing TypeScript `ActionResult` declaration and preserves omitted optional fields.
- **Canonical register limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` is a >1 MiB historical file. The GitHub file-content connector returns blob metadata but an empty body; it is not safe to replace it without retrieving the complete history. This QA record is therefore preserved in this supplementary append-only register, and the canonical file is left untouched.
- **Security interpretation:** all new malformed values are deterministic in-process test fixtures. They characterize runtime type validation only and do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA220 — final documentation-head reconciliation (6 November 2026, 10:56 KST)

- **Documentation-only HEAD:** `f7b159d3bfb3e7f483b3be886ea31b49ac0fb7ce` updated the QA220 register after the code/test validation. No application or test source changed in this commit.
- **QIMA CI #834** [run 42146729990](https://github.com/meridane/QimaTrade-MVP/actions/runs/42146729990) — **SUCCESS**; the browser job log independently confirms **246/246 Playwright tests passed (5.5 s)**. Both jobs succeeded: dependency installation/audit, TypeScript, production build, Chromium, Playwright, isolated PostgreSQL CREATE_OFFER/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS.
- **QIMA CodeQL #789** [run 42146730294](https://github.com/meridane/QimaTrade-MVP/actions/runs/42146730294) — **SUCCESS**.
- **Vercel on exact documentation-only SHA:** GitHub combined status returned **FAILURE** with the target `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`. A direct Vercel deployment lookup for SHA `f7b159d3bfb3e7f483b3be886ea31b49ac0fb7ce` returned zero deployments. This is recorded as a Preview quota/availability limitation; it is not a failed application build. The earlier code/test SHA `f6ffaa5...` has a separate READY Preview deployment, recorded above.
- **Conclusion:** QA220 code and tests are validated by CI #833 (246/246), PostgreSQL/RLS, CodeQL #788, and a READY Preview for the code/test SHA. The documentation-only HEAD is independently validated by CI #834 and CodeQL #789; no Preview was created for that exact documentation-only SHA.
- **Safety:** no production Supabase data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA221 — preserve the actual CREATE_OFFER SQL result shape (6 November 2026, 11:03 KST)

- **Starting PR state:** PR #26 is open, draft and unmerged. Starting HEAD `a6a029f6f099e2b594e82a303044af9504281c4c`; branch `fix/create-offer-status-contract` is 779 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **Baseline checks:** QIMA CI #835 [run 42147213497](https://github.com/meridane/QimaTrade-MVP/actions/runs/42147213497) — **SUCCESS**; browser log confirms **246 Playwright tests passed (7.4 s)**. Both browser/build and isolated PostgreSQL CREATE_OFFER/concurrency/idempotency plus both RLS regression jobs succeeded. QIMA CodeQL #790 [run 42147213433](https://github.com/meridane/QimaTrade-MVP/actions/runs/42147213433) — **SUCCESS**. Vercel has no Preview deployment for the documentation-only starting SHA due the current build-rate-limit status; the previously validated code/test SHA `f6ffaa5...` retains a READY Preview.
- **SQL contract inspected:** the proposed branch migration `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql` constructs the public JSONB result with `status`, `executionId`, `objectType`, and `objectId`; it does not include a `result` key. The `ActionResult.result` property is optional and must remain optional at runtime.
- **Regression coverage:** add one positive action-engine test using that exact CREATE_OFFER SQL result shape: a UUID execution ID, `status: succeeded`, `objectType: Offer`, and a UUID `objectId`, with no `result` property. Assert the handler runs once, the extra `objectType` is preserved, and `result` remains absent.
- **Expected browser suite:** 247 tests (246 baseline + one SQL-shape compatibility case). This is an expectation only until the Playwright step completes on the published commit.
- **Scope:** test-only change. No runtime code, SQL migration, Supabase database, public HTTP contract, idempotency behavior, or tenant authorization behavior is modified.
- **Canonical register limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` remains a >1 MiB historical file; its GitHub file-content connector response contains the blob SHA but an empty body, including for line-range requests. It is not safe to replace without the complete content. This entry is preserved in the append-only QA register.
- **Security interpretation:** the SQL result shape is read from a proposed repository migration and the new test uses an in-process fixture. It does not prove production migration application or a production vulnerability.
- **Published test commit:** `27ad3dcc44e9079672779e214be17f3430df27a8` (`test(actions): cover CREATE_OFFER SQL result shape`), included in the published PR branch through the subsequent append-only documentation commit.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA221 — final validation reconciliation (6 November 2026, 11:10 KST)

- **Published test commit:** `27ad3dcc44e9079672779e214be17f3430df27a8`. It adds one positive action-engine regression for the actual CREATE_OFFER SQL JSONB shape: `status`, `executionId`, `objectType`, and `objectId`, with no `result` property.
- **QIMA CI #836** [run 42147491112](https://github.com/meridane/QimaTrade-MVP/actions/runs/42147491112) — **SUCCESS**; the browser job log confirms **247/247 Playwright tests passed (7.1 s)** and explicitly records the QA221 SQL-shape test as passed. Both CI jobs succeeded, including npm ci/audit, TypeScript, production build, Chromium, PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS.
- **QIMA CodeQL #791** [run 42147491231](https://github.com/meridane/QimaTrade-MVP/actions/runs/42147491231) — **SUCCESS**.
- **Vercel for exact test SHA `36907e4975dec10bf7ce3b066d8ff4528debff3b`:** GitHub combined status is **FAILURE** with target `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`; direct Vercel deployment history returns zero Preview deployments for this SHA. This is recorded as the existing Preview quota/availability limitation, not as a failed application build. The earlier QA220 code/test SHA `f6ffaa5...` has a separate READY Preview deployment.
- **Conclusion:** QA221 is validated by CI #836 (247/247), the isolated PostgreSQL and RLS jobs, and CodeQL #791. A new Preview was not created for this test SHA because of the Vercel build-rate-limit status.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA222 — require own ActionDefinition contract fields (6 November 2026, 11:16 KST)

- **Starting PR state:** PR #26 is open, draft and unmerged. Starting HEAD `b1227a2561c0f4276cadcb8b4dffab512bbc4d64`; branch `fix/create-offer-status-contract` is 782 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **Baseline checks:** QIMA CI run [42148791346](https://github.com/meridane/QimaTrade-MVP/actions/runs/42148791346) — **SUCCESS**; the browser job log confirms **247/247 Playwright tests passed (8.1 s)**, with 0 failed test lines. The isolated PostgreSQL CREATE_OFFER/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS steps also succeeded. QIMA CodeQL run [42148791333](https://github.com/meridane/QimaTrade-MVP/actions/runs/42148791333) — **SUCCESS**. GitHub combined Vercel status on the starting HEAD — **SUCCESS** (Preview).
- **Contract review:** `ActionDefinition` requires `actionKey`, `version`, and `status`. The engine already rejects null, unpublished, retired, and mismatched definitions, but property reads could accept matching values inherited from a custom prototype rather than present as own fields.
- **Runtime change:** add an `isActionDefinition` guard requiring a non-array object with own `actionKey`, `version`, and `status` fields of the declared primitive/enum types. Keep the existing published-status, action-key, and version equality checks. A null-prototype object with all three own fields remains valid.
- **Regression coverage:** add three negative cases, each inheriting exactly one required field (`actionKey`, `version`, or `status`) while the other two are own fields; each must return `ACTION_NOT_PUBLISHED` before invoking a handler. Add one positive control proving a complete null-prototype definition is accepted.
- **Expected browser suite:** 251 tests (247 baseline + four QA222 cases). This is an expectation only until Playwright completes on the published PR commit.
- **Scope:** action-engine runtime contract and unit-style Playwright tests only. No SQL migration, RPC payload, public HTTP mapping, idempotency behavior, tenant authorization, or Supabase production state is changed.
- **Canonical register:** the complete `docs/QIMA_V1_FUNCTION_REGISTER.md` blob was retrieved by SHA `757b099679c51b417630ca03c413e46c143e510a` (1,173,887 characters) and preserved before appending this entry; no truncation or reconstruction from excerpts was used.
- **Security interpretation:** inherited-property definitions are deterministic in-process fixtures. The tests characterize runtime contract validation only; they do not establish a production exploit or confirmed vulnerability.
- **Work branch:** `work/offer-qa-222-action-definition-own-fields-20261106-1116`; runtime commit `c29bc75cb66435560472e458709c74e76aaf51a2`; test commit `6f339ae4aa66280d90e26d4d1d84bdf8855d2e90`. Publication to the PR branch and final CI results are pending.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting is changed.


## QA222 — final code/test validation reconciliation (6 November 2026, 11:18 KST)

- **Published QA222 commits:** runtime guard `c29bc75cb66435560472e458709c74e76aaf51a2`; regression tests `6f339ae4aa66280d90e26d4d1d84bdf8855d2e90`. Both are included in PR HEAD `05fb176a5378d191080b1987ae11c44f5fd0b8fa`.
- **QIMA CI #838** [run 42149583689](https://github.com/meridane/QimaTrade-MVP/actions/runs/42149583689) — **SUCCESS**. The browser job log confirms **251/251 Playwright tests passed (5.3 s)** with 0 failed test lines. Both CI jobs succeeded: npm ci, npm audit, TypeScript, Next.js production build, Chromium, Playwright, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS.
- **QIMA CodeQL #793** [run 42149583686](https://github.com/meridane/QimaTrade-MVP/actions/runs/42149583686) — **SUCCESS**.
- **Vercel on exact QA222 HEAD:** GitHub combined status is **FAILURE** with target `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`. This is the existing Preview build-rate-limit/availability condition, not a failed Next.js build; the GitHub Actions production build succeeded. No production deployment was attempted.
- **Conclusion:** QA222 is validated by CI #838 (251/251), isolated PostgreSQL and RLS tests, and CodeQL #793. The Vercel Preview check is blocked by the provider quota/availability status.
- **Scope/safety:** no SQL migration, Supabase production data, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA222 — final documentation-head reconciliation (6 November 2026, 11:20 KST)

- **Documentation-only HEAD:** `a614a75bcad78683ce69be3f939d2c6fd55be80e` updated both function registers after QA222 code/test validation. No application or test source changed in this documentation-only update.
- **QIMA CI #839** [run 42149817898](https://github.com/meridane/QimaTrade-MVP/actions/runs/42149817898) — **SUCCESS**; the browser job log confirms **251/251 Playwright tests passed (5.7 s)** with 0 failed test lines. Both jobs succeeded, including npm ci/audit, TypeScript, Next.js production build, Chromium, Playwright, isolated PostgreSQL CREATE_OFFER/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS.
- **QIMA CodeQL #794** [run 42149817794](https://github.com/meridane/QimaTrade-MVP/actions/runs/42149817794) — **SUCCESS**.
- **Vercel on exact documentation-only SHA:** GitHub combined status is **FAILURE** with target `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`. This is the Preview build-rate-limit/availability condition, not a failed application build; the GitHub Actions production build succeeded. No production deployment was attempted.
- **Conclusion:** the QA222 code/test SHA is validated by CI #838 (251/251), PostgreSQL/RLS, and CodeQL #793. The documentation-only HEAD `a614a75` is independently validated by CI #839 and CodeQL #794. Vercel Preview remains unavailable due the quota status.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA222 — second documentation-head validation reconciliation (6 November 2026, 11:22 KST)

- **Documentation-only HEAD:** `6e8876296e955b45166cc06b59ae6a9242bfcdbf` contains the QA222 final validation record for the preceding documentation head; this SHA changed only the two function registers.
- **QIMA CI #840** [run 42150012525](https://github.com/meridane/QimaTrade-MVP/actions/runs/42150012525) — **SUCCESS**; browser job confirms **251/251 Playwright tests passed (7.1 s)** with 0 failed test lines. Both jobs succeeded: npm ci/audit, TypeScript, production build, Chromium, Playwright, isolated PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy-message RLS, and participant self-enrollment RLS.
- **QIMA CodeQL #795** [run 42150012540](https://github.com/meridane/QimaTrade-MVP/actions/runs/42150012540) — **SUCCESS**.
- **Vercel on exact SHA `6e8876296e955b45166cc06b59ae6a9242bfcdbf`:** combined status **FAILURE** with `build-rate-limit` target. This remains a Preview quota/availability limitation; the GitHub Actions build succeeded and no production deployment was attempted.
- **Conclusion:** the QA222 implementation and the two-register documentation head are validated by CI #840 (251/251), PostgreSQL/RLS, and CodeQL #795. Vercel Preview remains unavailable due the quota status.
- **Safety:** no production Supabase data, migration, policy, configuration, production deployment, merge, or branch-protection setting was changed.


## QA223 — reject inherited optional ActionResult fields (6 November 2026, 11:30 KST)

- **Starting PR state:** PR #26 open, draft, unmerged and mergeable. Starting HEAD `fe316517c16b718c333d1d386df80708d779d6ed`; branch `fix/create-offer-status-contract` is 792 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **Baseline:** QIMA CI #841 (run 42150231426) and QIMA CodeQL #796 (run 42150231537) both completed successfully. CI #840 confirms 251/251 browser tests for the QA222 code/test baseline. Vercel on the starting HEAD reports `build-rate-limit`; treat this as Preview quota/availability, not an application build failure.
- **Gap:** the `ActionResult` guard checked optional `objectId` and `result` only with own-property checks. An inherited invalid value could therefore be visible to callers while bypassing runtime type validation.
- **Change:** `lib/actions/engine.ts` now rejects inherited `objectId` or `result` properties while preserving own optional fields and null-prototype objects.
- **Tests:** `tests/e2e/action-engine.spec.ts` adds two negative regressions (inherited numeric `objectId`, inherited string `result`) and one positive null-prototype result case. Expected suite: 254 tests; pending CI confirmation.
- **Code commit:** `10f8d1c10c86a220fa5732a6360cb5e0aaea0b6f` on `work/offer-qa-223-action-result-own-optional-fields-20261106-1130`.
- **Canonical register:** full pre-change content was fetched from blob `c407a09e127b64bb0832631f43eb06297c59187c` (1,181,623 characters) and preserved before appending this entry.
- **Interpretation:** synthetic in-process cases characterize the runtime contract only; they do not establish a production exploit or vulnerability.
- **CI/CodeQL:** new-head validation is pending; record final run IDs and outcomes in the next reconciliation.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA224 — reject accessor-backed ActionDefinition fields (6 November 2026, 12:00 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Starting HEAD `f06cebc167d2e883be4c186af13c85a7b5c910e0`; branch `fix/create-offer-status-contract` is 794 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **Baseline validation:** QIMA CI #842 [run 42151446470](https://github.com/meridane/QimaTrade-MVP/actions/runs/42151446470) — **SUCCESS**, including **254/254 Playwright tests** (6.7 s), npm ci/audit, TypeScript, Next.js production build, Chromium, and both isolated PostgreSQL/RLS jobs. QIMA CodeQL #797 [run 42151446480](https://github.com/meridane/QimaTrade-MVP/actions/runs/42151446480) — **SUCCESS**. Vercel combined status on the starting HEAD is **FAILURE** with `build-rate-limit`, a Preview quota/availability condition rather than a GitHub Actions build failure.
- **Review finding:** `isActionDefinition` verified own properties and then read `candidate.actionKey`, `candidate.version`, and `candidate.status`; own accessor properties could therefore execute getters during validation and propagate arbitrary getter exceptions.
- **Runtime change:** validate the three required fields using own property descriptors and require data descriptors. Accessor-backed definitions are rejected as `ACTION_NOT_PUBLISHED` without invoking getters. Descriptor-inspection exceptions (including proxy traps) are normalized to invalid-definition rejection. Plain JSON objects and valid null-prototype data objects remain supported.
- **Regression coverage:** three generated tests install a throwing getter on `actionKey`, `version`, or `status`; each asserts the getter is never called, the definition is looked up once, and no handler is invoked. Existing positive null-prototype definition coverage remains unchanged.
- **Expected browser suite:** 257 tests (254 baseline + three QA224 cases); pending GitHub Actions confirmation.
- **Security interpretation:** accessor and proxy cases are synthetic in-process fixtures. This verifies the runtime contract and exception boundary only; it does not establish a production exploit or confirmed vulnerability.
- **Validation after publication:** CI, CodeQL, and Preview outcomes for the QA224 PR HEAD are pending; reconcile exact run IDs and Playwright totals in a subsequent update.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA225 — normalize Proxy-backed ActionDefinition values (6 November 2026, 12:15 KST)

- **Starting PR state:** PR #26 is open, draft, unmerged and mergeable. Starting HEAD `9db7eed11417f95b3630a85c30c7dfbdd3ba4811`; branch `fix/create-offer-status-contract` is 798 commits ahead of `main`, 0 behind, with 44 files in the overall PR diff.
- **Baseline validation:** QIMA CI #843 [run 42154158360](https://github.com/meridane/QimaTrade-MVP/actions/runs/42154158360) — **SUCCESS**, including **257/257 Playwright tests** (5.7 s), npm ci/audit (0 reported vulnerabilities), TypeScript, Next.js production build, Chromium, isolated PostgreSQL CREATE_OFFER integration/concurrency, legacy-message RLS, and participant self-enrollment RLS. QIMA CodeQL #798 [run 42154158329](https://github.com/meridane/QimaTrade-MVP/actions/runs/42154158329) — **SUCCESS**. Vercel combined status on the starting HEAD is **FAILURE** with `build-rate-limit`; this is a Preview quota/availability limitation, not a GitHub Actions failure.
- **Review finding:** QA224 caught ordinary own accessors and descriptor-inspection exceptions, but a Proxy can still expose a throwing `get` trap after descriptor validation. A revoked Proxy can also throw from `Array.isArray` before the old try/catch boundary.
- **Runtime change:** replace the boolean type guard with `normalizeActionDefinition`, which validates own data descriptors inside one exception boundary and returns a fresh plain `ActionDefinition` snapshot. All later status/key/version comparisons use the snapshot, never the Proxy. `Array.isArray`, descriptor inspection, and revoked-Proxy errors are normalized to `ACTION_NOT_PUBLISHED`.
- **Regression coverage:** add three tests: a throwing `getOwnPropertyDescriptor` trap is normalized and prevents handler invocation; a Proxy with a throwing `get` trap is accepted from its valid data descriptors without invoking the trap and executes the handler once; a revoked Proxy is normalized to `ACTION_NOT_PUBLISHED` and never invokes the handler.
- **Expected browser suite:** 260 tests (257 baseline + three QA225 cases). The first CI attempt caught a test-fixture TypeScript inference issue before Playwright could run; the fixture is now explicitly typed as `ActionDefinition`.
- **Code and register update:** this entry is included with the QA225 code/test change in the same commit. The complete pre-change canonical blob was fetched as `b4b1e535600e257c44c9f55126d9ef39aaab7ce6` (1,187,269 characters) and preserved; the append-only register was fetched in full (166,088 characters) and preserved.
- **Security interpretation:** Proxy and revoked-Proxy fixtures are synthetic in-process tests. They characterize validation and exception boundaries only; they do not establish a production exploit or confirmed vulnerability.
- **First validation attempt:** QIMA CI #844 [run 42155643879](https://github.com/meridane/QimaTrade-MVP/actions/runs/42155643879) — browser job failed at TypeScript check in the revoked-Proxy test fixture because the inline `status` property widened to `string`, which was not assignable to the `ActionDefinition` status union. Playwright and the browser build were skipped; this was a test typing issue, not a runtime test failure. The isolated PostgreSQL job was still running when the correction was prepared. QIMA CodeQL #799 [run 42155643862](https://github.com/meridane/QimaTrade-MVP/actions/runs/42155643862) was in progress at that point.
- **Correction:** type the revoked-Proxy target explicitly as `ActionDefinition` before passing it to `Proxy.revocable`; this preserves the literal status union without changing runtime behavior. A new CI/CodeQL run is triggered by the corrective commit.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA225 follow-up — Proxy fixtures and Promise assimilation (6 November 2026, 13:26 KST)

- **Starting state:** PR #26 open, draft, unmerged and mergeable; branch `fix/create-offer-status-contract`; starting HEAD `a2efe6fc941095fc369eef4298d61751b9709d08`. CI #845 [run 42155760612](https://github.com/meridane/QimaTrade-MVP/actions/runs/42155760612) completed with **FAILURE** in the browser job; its PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment jobs all succeeded. CodeQL #800 [run 42155760618](https://github.com/meridane/QimaTrade-MVP/actions/runs/42155760618) succeeded. Vercel Preview status on the starting HEAD was success.
- **Exact browser result:** 258 tests passed and two QA225 Proxy-definition tests failed. The failures occurred before the engine received the Proxy: returning a Proxy from an `async` dependency triggers Promise thenable assimilation, which probes its `then` property. The valid Proxy fixture threw from its generic `get` trap on that protocol probe. The revoked Proxy fixture was revoked before the async return attempted the same probe, so the rejection originated in the fixture boundary rather than `normalizeActionDefinition`.
- **Test-only correction:** the valid Proxy fixture now returns `undefined` for the Promise protocol's `then` lookup and continues to throw for all other property reads; its assertion still verifies that no business-property `get` trap is invoked. The revoked Proxy fixture now creates `Promise.resolve(revocable.proxy)` while the proxy is live, then revokes it before `executeAction` resumes. This lets the fulfilled Promise deliver the revoked Proxy to the runtime normalizer, where `Array.isArray` throws inside the existing normalization boundary and is converted to `ACTION_NOT_PUBLISHED`.
- **Runtime scope:** no runtime code or business contract changed; this follow-up repairs the two synthetic fixtures so they exercise the intended normalization boundary rather than Promise's pre-handler assimilation protocol.
- **Expected browser suite:** 260 tests, with the two previously failing QA225 cases expected to pass. Confirmation is pending the new GitHub Actions run.
- **Security interpretation:** this is a test-fixture boundary correction. The CI failure does not establish a production vulnerability or a defect in deployed behavior.
- **Safety:** no Supabase production data, migrations, policies, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA226 — ActionResult accessors and Proxy boundary (6 November 2026, 14:58 KST)

- **Starting state:** PR #26 is open, draft, unmerged and mergeable; base `main`; head `fix/create-offer-status-contract` at `6000339af40ace2fd64d43e54b7669264ef4daa4`; 803 commits ahead and zero behind. No PR reviews or inline review threads were present. The canonical register blob was fetched in full and its SHA verified before editing.
- **Previous validation:** QIMA CI #846 [run 42162755740](https://github.com/meridane/QimaTrade-MVP/actions/runs/42162755740) succeeded; the browser log records **260 passed**. PostgreSQL CREATE_OFFER integration/concurrency, legacy-message RLS, and participant self-enrollment RLS jobs all succeeded. QIMA CodeQL #801 [run 42162755837](https://github.com/meridane/QimaTrade-MVP/actions/runs/42162755837) succeeded. Vercel Preview status on the starting HEAD was success.
- **Gap:** the previous `isActionResult` read required and optional fields directly from the handler-returned object after checking own-property presence. An accessor or Proxy `get` trap could therefore execute during validation; a revoked Proxy could also throw during array/reflection checks outside an exception boundary.
- **Runtime change:** replace the boolean predicate with `normalizeActionResult`. It checks array status, enumerates own keys, obtains own property descriptors inside a `try/catch`, rejects accessor descriptors, and snapshots data-property values into a new plain object. Required `executionId` and `status`, optional `objectId` and `result`, and all additional own data fields are preserved; in particular, the CREATE_OFFER SQL result's extra `objectType` field remains present. The normalized result is detached from the original object, so object identity is intentionally no longer preserved while the result shape is preserved.
- **Regression coverage:** four accessor-backed fields (`executionId`, `status`, `objectId`, `result`) are rejected without invoking getters; a Proxy with a throwing `get` trap is snapshotted without invoking business-property reads; a revoked Proxy is normalized to `ACTION_RESULT_INVALID`. Existing valid null-prototype results, failed results, and CREATE_OFFER SQL result shape remain covered.
- **Expected browser suite:** 266 tests (260 baseline + 6 QA226 cases). The code/test commit `ea01dca3904cf5b2304c1868de31f07e5ceaee96` triggered QIMA CI #847 [run 42171764801](https://github.com/meridane/QimaTrade-MVP/actions/runs/42171764801) and CodeQL #802 [run 42171764908](https://github.com/meridane/QimaTrade-MVP/actions/runs/42171764908). At the time of this entry, CI #847 was in progress (dependency audit succeeded; TypeScript was running; PostgreSQL container initialization was running), CodeQL #802 was in progress, and Vercel Preview was pending. Final test results are not yet claimed.
- **Security interpretation:** these are synthetic in-process contract tests. They validate the engine's accessor/Proxy boundary and do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA226 follow-up — preserve inherited-field rejection and isolate Proxy observation (6 November 2026, 15:04 KST)

- **First QA226 validation:** QIMA CI #847 [run 42171764801](https://github.com/meridane/QimaTrade-MVP/actions/runs/42171764801) browser logs recorded **263 passed and 3 failed**. The failures were two pre-existing inherited optional-field regressions (`objectId` and `result`) and the new Proxy get-trap count assertion. TypeScript, dependency audit, and production build passed; CodeQL #802 [run 42171764908](https://github.com/meridane/QimaTrade-MVP/actions/runs/42171764908) succeeded. The run was superseded while PostgreSQL integration was still in progress; it is not counted as a successful full CI. The Vercel check on the subsequent code/test head reported the account's `build-rate-limit` quota, not an application compilation result.
- **Inherited-field correction:** before snapshotting, `normalizeActionResult` now uses `Reflect.has` plus an own-property check for optional `objectId` and `result`. Inherited values are rejected as before; the reflective operations remain inside the same `try/catch`, so throwing Proxy `has` traps are normalized to invalid results.
- **Proxy assertion correction:** the get-trap count and detached-reference state are captured immediately after `executeAction` resolves, before Playwright assertion helpers inspect values. This distinguishes engine-time reads from any later test-framework inspection.
- **Follow-up commits:** `38a06478093862b2e2691e7c0912f934958ceea0` updates the runtime guard; `7decfba76c573965d957d0d0ee084087b79a49bb` updates the Proxy regression assertion.
- **Current validation:** QIMA CI #849 [run 42172054978](https://github.com/meridane/QimaTrade-MVP/actions/runs/42172054978) and CodeQL #804 [run 42172055008](https://github.com/meridane/QimaTrade-MVP/actions/runs/42172055008) were started on the follow-up code head. At this documentation point, npm installation and audit had succeeded, TypeScript had succeeded, production build was still running, PostgreSQL CREATE_OFFER integration was still running, and CodeQL analysis was still in progress. Vercel Preview returned `build-rate-limit`. Final Playwright count and full CI outcome are not yet claimed.
- **Expected browser suite:** 266 tests (260 prior baseline plus six QA226 regression cases); confirmation is pending CI #849.
- **Security interpretation:** these are synthetic in-process tests of object descriptors and Proxy behavior. The earlier test failures and the new passing/pending checks do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA226 validation closure — 6 November 2026 (15:58 KST)

- **Final CI:** QIMA CI #850 [run 42172183516](https://github.com/meridane/QimaTrade-MVP/actions/runs/42172183516) completed successfully with **266/266 Playwright tests passed**. npm audit reported 0 vulnerabilities across all severities; TypeScript, Next.js production build, CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS and participant self-enrollment RLS passed. A transient `ECONNRESET: Auth network connection reset` appeared in the browser log, but the Playwright suite and job completed successfully.
- **Other checks:** CodeQL #805 [run 42172183505](https://github.com/meridane/QimaTrade-MVP/actions/runs/42172183505) succeeded. CI #849 [run 42172054978](https://github.com/meridane/QimaTrade-MVP/actions/runs/42172054978) was cancelled during Chromium installation (Playwright skipped); its PostgreSQL/RLS job passed. CodeQL #804 [run 42172055008](https://github.com/meridane/QimaTrade-MVP/actions/runs/42172055008) succeeded.
- **Preview status:** Vercel on the final QA226 HEAD returned `build-rate-limit`; this is a provider quota limitation, not an application build failure. GitHub Actions production build succeeded.
- **Security/safety:** synthetic regression evidence only; no production exploit is asserted. No Supabase production data, migration, policy, deployment, merge or branch-protection change.

## QA227 — descriptor-safe action handler registry resolution (6 November 2026, 15:58 KST)

- **Gap:** direct `handlers[actionKey]` lookup could invoke an own getter or Proxy `get` trap. A revoked Proxy could also throw during `Array.isArray` or descriptor inspection.
- **Runtime:** add `resolveActionHandler` to accept only an own data-property descriptor whose value is a function. Reflection is contained in `try/catch`; malformed, accessor-backed, throwing and revoked registries map to `ACTION_HANDLER_NOT_FOUND`. Null-prototype registries and Proxy registries with ordinary data descriptors remain supported.
- **Tests:** four regressions cover an own getter (not invoked), a Proxy with a throwing `get` trap (not invoked), a throwing descriptor trap (normalized), and a revoked Proxy registry (normalized). Expected browser suite: 270 tests; CI pending.
- **Interpretation:** synthetic in-process tests only; no production vulnerability is confirmed. Production Supabase and deployment boundaries remain untouched.


## QA227 validation closure — 6 November 2026 (16:08 KST)

- **Final QIMA CI:** CI #851 [run 42178376514](https://github.com/meridane/QimaTrade-MVP/actions/runs/42178376514) completed successfully on QA227 code. The browser job ran **270 tests and all 270 passed** in 6.2 seconds. npm installation, `npm audit --audit-level=high`, TypeScript, Next.js production build and Chromium installation succeeded. The isolated PostgreSQL CREATE_OFFER integration/concurrency suite, legacy-message RLS regression and participant self-enrollment RLS regression all passed.
- **Browser log note:** a transient `ECONNRESET: Auth network connection reset` line appeared during the run, but Playwright completed with 270 passed and the browser job concluded successfully. No test failure is associated with that log line.
- **CodeQL:** QIMA CodeQL #806 [run 42178376552](https://github.com/meridane/QimaTrade-MVP/actions/runs/42178376552) completed successfully.
- **Vercel:** the combined status on the QA227 HEAD remains failure with target `build-rate-limit` (provider/account build quota). GitHub Actions' Next.js production build succeeded; Vercel's quota status is not treated as an application build failure.
- **Security interpretation:** all new cases are synthetic in-process tests of handler registry descriptors and Proxy behavior. They do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA228 — normalize ActionResult reflection-trap failures (6 November 2026, 16:14 KST)

- **Starting state:** PR #26 remained open and draft at `1bdc2cf4475a53e2f71df41a7aa3d2783495cc34`, 817 commits ahead of `main` and zero behind. QA227 was fully validated: QIMA CI #851 [run 42178376514](https://github.com/meridane/QimaTrade-MVP/actions/runs/42178376514) passed **270/270 Playwright tests**; CodeQL #806 [run 42178376552](https://github.com/meridane/QimaTrade-MVP/actions/runs/42178376552) succeeded.
- **Latest-head checks before QA228:** QIMA CI #852 [run 42178618364](https://github.com/meridane/QimaTrade-MVP/actions/runs/42178618364) completed successfully. Its browser job passed **270 tests**, npm audit reported 0 vulnerabilities (0 info/low/moderate/high/critical), TypeScript, Next.js production build, Chromium, and all isolated PostgreSQL CREATE_OFFER/concurrency, legacy-message RLS and participant self-enrollment RLS tests passed. CodeQL #807 [run 42178618343](https://github.com/meridane/QimaTrade-MVP/actions/runs/42178618343) succeeded. The Vercel status remains `build-rate-limit` (provider quota), not a GitHub Actions build failure.
- **Gap selected:** `normalizeActionResult` already encloses reflective inspection in `try/catch`, but the regression suite did not independently exercise exceptions from Proxy `has`, `ownKeys`, and `getOwnPropertyDescriptor` traps. The earlier revoked-Proxy test covered a related boundary but did not identify which reflection operation was failing.
- **Tests:** add three table-driven Playwright regressions. A throwing `has` trap fails the inherited-optional-field check; a throwing `ownKeys` trap fails snapshot enumeration; a throwing `getOwnPropertyDescriptor` trap fails while snapshotting `executionId`. Each test expects the stable `ACTION_RESULT_INVALID` error, exactly one definition lookup, exactly one handler call, and exactly one invocation of the designated trap.
- **Scope:** tests only; no runtime change and no change to the `ActionResult.result` nested-data contract. Expected browser suite: **273 tests** (270 baseline plus three reflection-trap cases); new CI validation pending at commit time.
- **Interpretation:** these are synthetic in-process tests of JavaScript Proxy reflection behavior. They validate exception normalization but do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA228 first CI correction — 6 November 2026 (16:17 KST)

- **First validation:** QIMA CI #853 [run 42179815974](https://github.com/meridane/QimaTrade-MVP/actions/runs/42179815974) started on commit `5b97f5214f65b1070cdf4813547e8850f82e10a5`. Dependency installation and npm audit completed; TypeScript then failed at `tests/e2e/action-engine.spec.ts:1421` with TS2749 because `Proxy` is a runtime constructor value, not a generic TypeScript type. The build and Playwright steps were skipped after the typecheck failure. This is a test-fixture typing error, not a runtime failure. The separate PostgreSQL job was still running when this correction was prepared.
- **Correction:** change the scenario factory return annotation from `Proxy<ActionResult>` to `ActionResult`. The built-in `Proxy` constructor preserves the target's static type, so this accurately types the returned proxy without inventing a generic `Proxy<T>` type.
- **Scope:** test typing only; no engine/runtime change. The three reflection-trap scenarios remain unchanged. A new CI/CodeQL validation is expected on the correction commit.
- **Security interpretation:** synthetic regression tests only; no production exploit or confirmed vulnerability is asserted.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA228 validation closure — 6 November 2026 (16:19 KST)

- **Final QIMA CI:** CI #854 [run 42179998391](https://github.com/meridane/QimaTrade-MVP/actions/runs/42179998391) completed successfully on corrected test commit `19ef111e73d6f901dbc356fa3e05362e843d356f`. Playwright reported **273 passed** in 7.4 seconds. npm audit reported **0 vulnerabilities** (0 info, 0 low, 0 moderate, 0 high, 0 critical). TypeScript, Next.js production build, Chromium installation, and the isolated PostgreSQL CREATE_OFFER integration/concurrency, legacy-message RLS, and participant self-enrollment RLS jobs all succeeded.
- **First-attempt correction:** CI #853 [run 42179815974](https://github.com/meridane/QimaTrade-MVP/actions/runs/42179815974) failed only in the TypeScript job due to the invalid `Proxy<ActionResult>` type annotation in the new test fixture; the PostgreSQL/RLS job succeeded. Playwright was skipped in #853. The annotation was corrected to `ActionResult`, and #854 passed all 273 tests. CodeQL #808 [run 42179815927](https://github.com/meridane/QimaTrade-MVP/actions/runs/42179815927) succeeded on the first QA228 test commit.
- **CodeQL:** CodeQL #809 [run 42179998335](https://github.com/meridane/QimaTrade-MVP/actions/runs/42179998335) completed successfully on the corrected commit.
- **Vercel Preview:** status succeeded on the corrected commit; preview target [QimaTrade Preview](https://vercel.com/bmk1/qimatrade-mvp/AeC1tvB6GFB3Uv66sRMcRY8CBDRP). This is a Preview, not a production deployment.
- **Browser log note:** a transient `ECONNRESET: Auth network connection reset` line appeared during Playwright, but the suite completed with 273 passed and the browser job succeeded. No test failure is associated with that line.
- **Security interpretation:** the three cases are synthetic in-process Proxy reflection tests. They verify exception normalization only and do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA229 — handler thenable boundary regression tests — 6 November 2026 (17:39 KST)

- **Starting point:** PR #26 head `427ae360d451219e7871c1264b88a7f3f7d8e981`, branch `fix/create-offer-status-contract`. The PR remains open and draft. QA228 was reconciled against GitHub: QIMA CI #855 [run 42180227471](https://github.com/meridane/QimaTrade-MVP/actions/runs/42180227471) completed successfully with **273 Playwright tests passed**; TypeScript, production build, npm audit, and isolated CREATE_OFFER PostgreSQL/RLS jobs succeeded. CodeQL #810 [run 42180227496](https://github.com/meridane/QimaTrade-MVP/actions/runs/42180227496) succeeded.
- **Preview note:** the Vercel status on `427ae360d451219e7871c1264b88a7f3f7d8e981` is `failure` with target `build-rate-limit`. This is a provider quota limitation, not evidence of a source build failure; GitHub Actions production build succeeded on the same head.
- **Scope:** tests only. Add three focused cases at the `executeAction` handler boundary: (1) a custom thenable resolving a valid ActionResult is awaited and then normalized into a detached result; (2) a thenable resolving an invalid ActionResult is rejected as `ACTION_RESULT_INVALID`; and (3) a throwing `then` accessor is propagated as the original rejection, with exactly one definition lookup and one handler invocation. This records the existing Promise-assimilation contract without changing runtime semantics.
- **Expected browser suite:** **276 tests** (273 baseline plus three thenable-boundary cases). CI and CodeQL validation for the new commit are pending at this entry.
- **Interpretation:** these are synthetic in-process tests of JavaScript Promise/thenable assimilation and the engine boundary. They do not establish a production exploit or confirmed vulnerability.
- **Safety:** no application runtime, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA229 — final validation reconciliation — 6 November 2026 (18:25 KST)

- **Starting point:** PR #26 head `427ae360d451219e7871c1264b88a7f3f7d8e981`, branch `fix/create-offer-status-contract`. The PR remained open and draft. The three thenable-boundary tests were added without changing runtime semantics.
- **Final QIMA CI:** CI #856 [run 42189498565](https://github.com/meridane/QimaTrade-MVP/actions/runs/42189498565) completed successfully. The browser log confirms **276 Playwright tests passed (4.8 s)**. npm ci, dependency audit, TypeScript, Next.js production build, Chromium installation, and isolated PostgreSQL CREATE_OFFER integration/concurrency, legacy-message RLS, and participant self-enrollment RLS jobs all succeeded.
- **CodeQL:** CodeQL #811 [run 42189498402](https://github.com/meridane/QimaTrade-MVP/actions/runs/42189498402) completed successfully; JavaScript/TypeScript analysis passed.
- **Vercel Preview:** the combined commit status was `success` with target [QimaTrade Preview](https://vercel.com/bmk1/qimatrade-mvp/AptkG4NAJSBwDWWdQijkTnXejkC6). This is a Preview, not a production deployment.
- **Browser log note:** a transient `ECONNRESET: Auth network connection reset` line and Node deprecation warnings appeared in the logs, but the browser suite completed with 276 passed and its job succeeded. No test failure is associated with those log lines.
- **Conclusion:** QA229 is validated by CI #856 (276/276) and CodeQL #811. The three tests characterize JavaScript thenable assimilation at the handler boundary; they do not establish a production exploit or confirmed vulnerability.
- **Safety:** no application runtime, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.

## QA230 — ActionResult optional-field compatibility regression tests — 6 November 2026 (18:25 KST)

- **Starting point:** PR #26 head `a52dd0bb1f6124a506dec83832410491215b9bdc`, branch `fix/create-offer-status-contract`. The PR is open, draft, and mergeable; it is 821 commits ahead of `main`, zero behind, with 44 files in the PR diff and no submitted reviews or review threads.
- **Baseline checks:** QIMA CI #856 [run 42189498565](https://github.com/meridane/QimaTrade-MVP/actions/runs/42189498565) completed successfully with **276 Playwright tests passed**; npm install/audit, TypeScript, production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency, and both RLS regression jobs succeeded. CodeQL #811 [run 42189498402](https://github.com/meridane/QimaTrade-MVP/actions/runs/42189498402) succeeded. Vercel Preview status was `success` for the baseline head.
- **Scope:** tests only. Add two focused cases to `tests/e2e/action-engine.spec.ts`: (1) explicitly present `objectId: undefined` and `result: undefined` remain accepted and remain own properties after normalization; (2) non-enumerable own `objectId` and `result` data properties remain non-enumerable after normalization, while the additional SQL result field `objectType` and nested result data remain available. No runtime or SQL behavior is changed.
- **Contract boundary:** preserve the current shallow-copy behavior. The nested `ActionResult.result` payload contract (JSON-only versus general JavaScript object) remains undecided; no recursive validation or new serialization restriction is introduced without a business decision.
- **Expected browser suite:** **278 tests** (276 baseline plus two compatibility regressions). CI and CodeQL validation for the new commit are pending.
- **Interpretation:** these are synthetic in-process contract tests for JavaScript property descriptors and optional fields. They do not establish a production exploit or confirmed vulnerability.
- **Safety:** no application runtime, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.



## QA230 — final validation reconciliation — 6 November 2026 (20:04 KST)

- **Starting point:** PR #26 head `1bbd0022982c05165f7befa1455e213cb9746ad1`, branch `fix/create-offer-status-contract`. The PR is open, draft, and mergeable; it is 822 commits ahead of `main`, zero behind, with 44 changed files and no submitted reviews or review threads.
- **Final QIMA CI:** CI #857 [run 42195353376](https://github.com/meridane/QimaTrade-MVP/actions/runs/42195353376) completed successfully. The browser job confirms **278 Playwright tests passed (7.7 s)**. npm install, dependency audit, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded.
- **CodeQL:** CodeQL #812 [run 42195353432](https://github.com/meridane/QimaTrade-MVP/actions/runs/42195353432) completed successfully.
- **Vercel Preview:** the combined commit status is `success` with target [QimaTrade Preview](https://vercel.com/bmk1/qimatrade-mvp/FqgWpxJajLgnkMnbQLTXp6bC9XYS). This is a Preview, not a production deployment.
- **Browser log note:** a transient `ECONNRESET: Auth network connection reset` line and Node deprecation warnings appeared, but the browser suite completed with 278 passed. The workflow's dependency-audit step and overall CI job both report success; no audit failure is inferred from the echoed diagnostic line alone.
- **Conclusion:** QA230 is validated by CI #857 (278/278) and CodeQL #812. The tests cover optional fields explicitly set to `undefined` and non-enumerable own fields plus SQL metadata. They do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.

## QA231 — symbol metadata and shallow ActionResult payload compatibility — 6 November 2026 (20:04 KST)

- **Starting point:** PR #26 head `1bbd0022982c05165f7befa1455e213cb9746ad1`, branch `fix/create-offer-status-contract`; open and draft, 822 commits ahead of `main`, zero behind. Baseline CI #857 and CodeQL #812 both succeeded.
- **Scope:** tests only in `tests/e2e/action-engine.spec.ts`. Add (1) a non-enumerable symbol-keyed own data property and verify that its symbol key, value, and enumerability survive the normalizer's `Reflect.ownKeys`/descriptor snapshot; (2) a nested `ActionResult.result` payload and nested object, verifying that the outer result is detached while nested references remain identical. This documents the current shallow-copy contract without changing runtime behavior or deciding a JSON-only business contract.
- **Expected browser suite:** **280 tests** (278 baseline plus two compatibility regressions). CI and CodeQL for the QA231 commit are pending.
- **Interpretation:** synthetic in-process compatibility tests for symbol property copying and shallow reference identity only; they do not establish a production exploit or confirmed vulnerability.
- **Safety:** no application runtime, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA231 — final validation reconciliation — 6 November 2026 (20:17 KST)

- **Starting point:** PR #26 head `15083e000534daf263f16051e8ebb38d9641b1b5`, branch `fix/create-offer-status-contract`. The PR is open, draft, and mergeable; it is **823 commits ahead** of `main`, zero behind, with 44 changed files and no submitted reviews or inline review threads.
- **Final QIMA CI:** CI #858 [run 42207790934](https://github.com/meridane/QimaTrade-MVP/actions/runs/42207790934) completed successfully. The browser job confirms **280 Playwright tests passed**. npm ci, dependency audit, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded.
- **CodeQL:** CodeQL #813 [run 42207790879](https://github.com/meridane/QimaTrade-MVP/actions/runs/42207790879) completed successfully; JavaScript/TypeScript analysis passed.
- **Vercel Preview:** the combined commit status is `success` with target [QimaTrade Preview](https://vercel.com/bmk1/qimatrade-mvp/3nWRqkKkTxUTjN6oyu7Xv1mc3fV2). This is a Preview, not a production deployment.
- **Workflow note:** GitHub Actions emitted a Node.js 20 deprecation warning for several pinned actions; all steps and both CI jobs nevertheless completed successfully. No functional failure is associated with this warning.
- **Conclusion:** QA231 is validated by CI #858 (280/280) and CodeQL #813. The tests characterize symbol-keyed metadata copying and shallow nested-payload reference behavior; they do not establish a production exploit or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA232 — special `__proto__` own-data-property compatibility — 6 November 2026 (20:17 KST)

- **Starting point:** PR #26 head `15083e000534daf263f16051e8ebb38d9641b1b5`, branch `fix/create-offer-status-contract`; open, draft, and mergeable, 823 commits ahead of `main`, zero behind. Baseline CI #858 and CodeQL #813 both succeeded.
- **Scope:** one focused regression test in `tests/e2e/action-engine.spec.ts`. The handler returns an otherwise valid ActionResult with an explicitly defined own data property named `__proto__`. The test verifies that normalization retains the own key and its value while the normalized result keeps `Object.prototype` as its actual prototype. This protects the current `Object.defineProperty` snapshot behavior without changing runtime code.
- **Expected browser suite:** **281 tests** (280 baseline plus one special-key regression). CI and CodeQL for the QA232 commit are pending.
- **Interpretation:** synthetic in-process JavaScript property-copy compatibility coverage only. It does not demonstrate prototype pollution in production or establish a confirmed vulnerability.
- **Safety:** no application runtime, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA232 — final validation reconciliation — 6 November 2026 (21:15 KST)

- **Starting point:** PR #26 head `f0f828a8929ac40c51d43adf007cfa8159a12a1f`, branch `fix/create-offer-status-contract`. The PR remains open and draft; compare against `main` reports 824 commits ahead and zero behind, with 44 changed files. No submitted reviews or review threads are present.
- **Final QIMA CI:** CI #859 [run 42209375252](https://github.com/meridane/QimaTrade-MVP/actions/runs/42209375252) completed successfully. The browser job log confirms **281 Playwright tests passed**. npm install, dependency audit, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded.
- **CodeQL:** CodeQL #814 [run 42209375228](https://github.com/meridane/QimaTrade-MVP/actions/runs/42209375228) completed successfully; JavaScript/TypeScript analysis passed.
- **Vercel Preview:** the combined status for this commit is `success`, with target [QimaTrade Preview](https://vercel.com/bmk1/qimatrade-mvp/BV9yahk6bWDiXVSE4SPYnbCstw8o). This is a Preview, not a production deployment.
- **Conclusion:** QA232 is validated by CI #859 (281/281) and CodeQL #814. The test covers an own data property named `__proto__`; it does not demonstrate prototype pollution in production or establish a confirmed vulnerability.
- **Safety:** no Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.

## QA233 — ActionResult descriptor normalization contract — 6 November 2026 (21:15 KST)

- **Starting point:** PR #26 head `f0f828a8929ac40c51d43adf007cfa8159a12a1f`, branch `fix/create-offer-status-contract`; open and draft, 824 commits ahead of `main`, zero behind. QA232 baseline CI #859 and CodeQL #814 both succeeded.
- **Scope:** one regression test in `tests/e2e/action-engine.spec.ts`. The handler returns an ActionResult whose `objectId`, `result`, and extra SQL metadata `objectType` are non-writable and non-configurable data properties. The normalizer is expected to create a detached outer snapshot, preserve each property's value and original enumerability, preserve the nested result reference, and normalize copied data properties to writable/configurable snapshots.
- **Expected browser suite:** **282 tests** (281 baseline plus one descriptor-contract regression). CI and CodeQL for the QA233 test commit are pending.
- **Interpretation:** synthetic in-process characterization of JavaScript property descriptor behavior and SQL metadata compatibility. It does not establish a production exploit or confirmed vulnerability.
- **Canonical register note:** the canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` blob is larger than the GitHub file-content connector's supported body response; its existing blob was inspected by metadata but not replaced. This append-only QA addendum is updated to preserve history without risking truncation of the canonical register.
- **Safety:** no application runtime, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting is changed.


## QA233 — initial CI failure and fixture correction — 6 November 2026 (21:15 KST)

- **Initial validation:** CI #860 [run 42216443618](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216443618) started for the QA233 commit. npm install and dependency audit completed successfully; the audit summary reported zero vulnerabilities. TypeScript failed before build and browser tests with `TS2322` at `tests/e2e/action-engine.spec.ts(1915,9)`: the fixture was typed as `ActionResult & { objectType: string }` but its object literal omitted the required `objectType` property, which was only added later via `Object.defineProperties`.
- **Correction:** the fixture object literal now includes `objectType: "Offer"` before `Object.defineProperties` tightens that property's descriptor. This preserves the intended non-writable/non-configurable source descriptor while satisfying the declared TypeScript intersection. Correction commit: `357d2f839e64ffbbf629da801995c955d4b0c6d3` on work branch `work/offer-qa-233-typecheck-fixture-fix-20261106-2115`.
- **Initial run interpretation:** CI #860 did not execute Next.js build, Chromium installation, or Playwright because typecheck failed. Therefore no QA233 browser pass/fail count is available from #860. PostgreSQL integration/RLS and CodeQL #815 were still running at the time this note was written; their eventual results must be recorded separately.
- **Next validation:** the corrected commit will be fast-forwarded to PR #26 and must pass a fresh CI/CodeQL run. Do not treat the TypeScript fixture error as an application runtime defect.
- **Safety:** no runtime code, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA233 — final validation reconciliation — 6 November 2026 (21:15 KST)

- **Corrected PR head:** `15ed6b238d50b28ffbc81be83cc28b0b5fc39858`, branch `fix/create-offer-status-contract`. PR #26 remains open, draft, and mergeable; it is 828 commits ahead of `main`, zero behind, with 44 changed files and no submitted reviews or review threads.
- **Initial run:** CI #860 [run 42216443618](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216443618) failed at TypeScript only because the new test fixture's required `objectType` field was declared in an intersection type but omitted from the object literal. npm audit completed and reported zero vulnerabilities. The build and browser tests were skipped after typecheck failed. The isolated PostgreSQL integration/RLS job succeeded. CodeQL #815 [run 42216443645](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216443645) succeeded.
- **Fixture correction:** commit `357d2f839e64ffbbf629da801995c955d4b0c6d3` added `objectType: "Offer"` to the object literal before `Object.defineProperties` sets the intended immutable source descriptor. The correction changes only the test fixture, not runtime behavior.
- **Final QIMA CI:** CI #861 [run 42216615771](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216615771) completed successfully. The browser job log confirms **282 Playwright tests passed**. npm install, npm audit (0 info/low/moderate/high/critical findings in the run's audit summary), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded.
- **CodeQL:** CodeQL #816 [run 42216616220](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216616220) completed successfully.
- **Vercel Preview:** the combined status for corrected head `15ed6b2` is `success`, target [QimaTrade Preview](https://vercel.com/bmk1/qimatrade-mvp/DXWANEY2xyrRtvUoFSVrqzhNBqDJ). This is a Preview, not a production deployment.
- **PostgreSQL log interpretation:** the isolated SQL job includes expected negative-test diagnostics such as `IDEMPOTENCY_KEY_REUSE`; the job conclusion is success and the regression scripts completed. Those expected database errors are not treated as test failures.
- **Conclusion:** QA233 is validated by CI #861 (282/282), CodeQL #816, and a successful Preview status. CI #860's TypeScript fixture failure is resolved and retained in this history. These tests characterize JavaScript descriptor normalization and SQL metadata compatibility; they do not establish a production exploit or confirmed vulnerability.
- **Safety:** no runtime code, SQL, Supabase production data, migration, policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA234 — GitHub Actions Node 24 runtime maintenance — 6 November 2026 (22:49 KST)

- **Starting point:** PR #26 head `f0dba22b447c6137cf4c5c8b174f075f6487183d`, branch `fix/create-offer-status-contract`; open, draft, and mergeable, 829 commits ahead of `main`, zero behind, 44 changed files, no submitted reviews or review threads.
- **Previous validation reconciled:** QIMA CI #862 [run 42216854723](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216854723) completed successfully. The browser job log confirms **282 Playwright tests passed**; npm ci, npm audit, TypeScript, Next.js build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded. CodeQL #817 [run 42216856351](https://github.com/meridane/QimaTrade-MVP/actions/runs/42216856351) succeeded. The combined Vercel Preview status was success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/HNcZxYzTdnmytNAmQ5Auxn83EViw).
- **Maintenance finding:** CI #862 logs emitted the GitHub Actions Node.js 20 deprecation warning for `actions/checkout@v4`, `actions/setup-node@v4`, and `actions/upload-artifact@v4`. Direct inspection of each action's published `action.yml` confirmed these versions declare `runs.using: node20`. The CodeQL v3 `init`, `autobuild`, and `analyze` actions also declare Node 20.
- **Change:** replace those actions with immutable full-commit pins to verified Node 24 releases: checkout v7.0.1 (`3d3c42e5aac5ba805825da76410c181273ba90b1`), setup-node v7.1.0 (`949feb2413d6458794dcd2491c4babbbce0c15c1`), upload-artifact v7.0.2 (`cf430e030ddbb5b0abf93d22962f4752f3646cd9`), and CodeQL action v4.39.3 (`33d7b85da1a04171e211befe2c739303b9a4c066`). The referenced action metadata was inspected and confirms `runs.using: node24`. The project toolchain remains on Node 20 in this change; changing the application's Node version is a separate compatibility decision.
- **Workflow path-filter behavior:** `paths-ignore: docs/**` is configured for push and pull-request triggers. GitHub evaluates pull-request path filters against the entire PR diff, not only the latest commit. Because PR #26 still contains non-documentation files, docs-only register commit `7ba047a` also triggered CI #864 and CodeQL #819; both passed. The filter skips PR runs only when the entire changed-file set is documentation-only (and skips docs-only pushes to `main`); scheduled and manual runs remain enabled.
- **Scope:** workflow maintenance only; no application runtime, SQL, migration, Supabase production data, RLS policy, production configuration, production deployment, merge, or branch-protection setting is changed.
- **Workflow-change validation:** QIMA CI #863 [run 42229141273](https://github.com/meridane/QimaTrade-MVP/actions/runs/42229141273) completed successfully with **282/282 Playwright tests**. npm ci, dependency audit, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded. CodeQL #818 [run 42229141171](https://github.com/meridane/QimaTrade-MVP/actions/runs/42229141171) succeeded. Vercel Preview was successful: [workflow commit Preview](https://vercel.com/bmk1/qimatrade-mvp/4Vyxt9gfUzDTqYYYVP5in1ASaCQR).
- **Latest-head validation:** docs-only commit `7ba047ac63881876f3d3d71ebfa0d04ffe31a67f` also completed CI #864 [run 42229487762](https://github.com/meridane/QimaTrade-MVP/actions/runs/42229487762) successfully with **282/282 Playwright tests**, and CodeQL #819 [run 42229487753](https://github.com/meridane/QimaTrade-MVP/actions/runs/42229487753) successfully. Its Vercel Preview was successful: [latest docs-head Preview](https://vercel.com/bmk1/qimatrade-mvp/9YacFkoWwirFQBSAFG5kZgsqmkjM).
- **Runtime-warning verification:** completed CI #863 and #864 browser job logs contain no `Node.js 20 is deprecated` warning. The pinned action metadata and successful CI/CodeQL runs confirm the Node 24 action migration works on the current GitHub-hosted runner.
- **Documentation follow-up:** commit `7ba047a` changed only the two registers. Because the overall PR still contains non-documentation changes, CI #864 and CodeQL #819 also ran on this docs-only head and both passed. No application code or workflow file changed after CI #863 / CodeQL #818; the #864/#819 results validate the same code/workflow tree at the latest PR head.
- **Conclusion:** QA234 is validated by CI #863 (282/282), CodeQL #818, and a successful Vercel Preview status. The prior Node 20 action-runtime deprecation warning is absent from the new CI job log.
- **Safety:** no application runtime, SQL, migration, Supabase production data, RLS policy, production configuration, production deployment, merge, or branch-protection setting is changed.
- **Separate business gate remains blocked:** MKT-1.1 and the live Supabase review document that the inspected `demands` schema has no `tenant_id`, the observed 23 demands were drafts/incomplete at inspection time, and tenant membership alone does not define supplier response eligibility. No eligibility rule or status predicate is invented; a product-owner decision and authoritative data model remain required before changing authorization behavior.


## QA235 — normalize unusable tenant membership rows — 6 November 2026 (23:39 KST)

- **Starting point:** PR #26 head `c922bce2900cdf911fb9122822db88aba3594707`, branch `fix/create-offer-status-contract`; open, draft, mergeable, 832 commits ahead of `main`, zero behind, 45 changed files, no submitted reviews or review threads.
- **Previous validation reconciled:** QIMA CI #864 [run 42229487762](https://github.com/meridane/QimaTrade-MVP/actions/runs/42229487762) completed successfully. Both jobs succeeded: npm ci, npm audit, TypeScript, Next.js build, Chromium, Playwright, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS. The browser job log was inspected; the workflow test step succeeded. CodeQL #819 [run 42229487753](https://github.com/meridane/QimaTrade-MVP/actions/runs/42229487753) succeeded. Vercel Preview status was success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/3FdtJZiZK27bnFxcTiLhqmiizzvX).
- **Prior review:** the CREATE_OFFER route already rejects an empty membership result and requires explicit selection when more than one distinct tenant is returned. It filters null tenant IDs, but if the query returns one or more rows whose tenant IDs are all null/blank, the filtered list has length zero and the existing `length !== 1` branch incorrectly returns `TENANT_SELECTION_REQUIRED` (409). Such rows do not identify a usable tenant and should follow the existing no-membership contract.
- **Change:** normalize membership tenant IDs to trimmed non-empty strings, deduplicate them, return `TENANT_MEMBERSHIP_REQUIRED` (403) when zero usable IDs remain, and retain `TENANT_SELECTION_REQUIRED` (409) only when more than one usable tenant remains. The authenticated-user scoping, one-tenant selection behavior, and all demand eligibility semantics are unchanged.
- **Regression test:** add one route test with three mocked membership result shapes: null-only, blank-only, and mixed null/blank. Each case expects 403 `TENANT_MEMBERSHIP_REQUIRED`, verifies the Auth/profile/membership request sequence, and verifies no RPC is called. These are deterministic mocked route tests; they do not establish a production authorization vulnerability or validate live Supabase membership data.
- **Business gate remains open:** this correction only normalizes unusable membership identifiers. It does not decide whether a supplier/tenant may answer a particular demand. MKT-1.1 remains blocked pending a product-owner-approved demand visibility/eligibility rule and authoritative schema relationship. The legacy draft-offer contract is also unchanged.
- **Validation:** QIMA CI #866 [run 42237587844](https://github.com/meridane/QimaTrade-MVP/actions/runs/42237587844) completed successfully on the QA235 code head. The browser job log confirms **283 Playwright tests passed**; npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded. CodeQL #821 [run 42237587826](https://github.com/meridane/QimaTrade-MVP/actions/runs/42237587826) succeeded. Vercel Preview status succeeded: [Preview](https://vercel.com/bmk1/qimatrade-mvp/Gv8JcKyhFXBqRx2ponWT12Lzvx6p).
- **Canonical register limitation:** the GitHub file-content connector returned the canonical register blob SHA but an empty body for `docs/QIMA_V1_FUNCTION_REGISTER.md` because of its size. The canonical file was not rewritten or truncated. This QA entry is recorded in this append-only supplement.
- **Safety:** no Supabase production data, production migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.
- **Build-log follow-up:** Next.js 15.5.28 completed the production build successfully but emitted an Edge Runtime warning: `@supabase/supabase-js` references `process.version` through the `@supabase/ssr` import trace. Webpack also reported large serialized cache strings (106 KiB and 250 KiB). These are build warnings, not a failed build or proof of a production runtime defect. Inspect the Edge entrypoint/import path in a separate follow-up before changing runtime boundaries.
- **Browser-log note:** the browser job logged `ECONNRESET: Auth network connection reset` from the mocked Auth transport-failure test; the test passed and the final Playwright count was 283/283. Do not classify this expected negative-test diagnostic as a test failure.

## QA236 — clarify the enforced npm audit gate — 7 November 2026 (00:33 KST)

- **Starting point:** PR #26 head `1645205a71cbc7c57a88c8f3ef6f0d5a5221e168`, branch `fix/create-offer-status-contract`; search confirms PR #26 is open and draft, comparison against `main` reports 836 commits ahead and zero behind. No submitted reviews or review threads were found.
- **Previous validation reconciled:** QIMA CI #867 [run 42238062821](https://github.com/meridane/QimaTrade-MVP/actions/runs/42238062821) completed successfully. The browser job log confirms **283/283 Playwright tests passed**. npm audit reported zero info, low, moderate, high, and critical findings; the dedicated enforcement step succeeded. TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS succeeded. CodeQL #822 [run 42238062822](https://github.com/meridane/QimaTrade-MVP/actions/runs/42238062822) succeeded.
- **Finding:** the workflow runs `npm audit --audit-level=high --json`, temporarily uses `continue-on-error: true` so the JSON report can still be uploaded, and then has a separate `if: always()` enforcement step that fails the job when `steps.audit.outcome` is not `success`. The report generator nevertheless said “L'audit npm reste informatif,” which contradicted the actual blocking gate.
- **Change:** update the automation summary to state that npm audit is blocking at the configured `high` threshold, that results below the threshold are reported without failing this gate, and that the JSON artifact remains available for review. Add a YAML comment explaining that `continue-on-error` only defers failure until after report upload; the dedicated enforcement step remains blocking. No audit threshold or command behavior is changed.
- **Validation:** QIMA CI #868 [run 42244589475](https://github.com/meridane/QimaTrade-MVP/actions/runs/42244589475) completed successfully on the QA236 workflow head. The browser job log confirms **283/283 Playwright tests passed**. npm audit reported zero info, low, moderate, high, and critical findings; the dedicated enforcement step succeeded. TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS all succeeded. CodeQL #823 [run 42244589409](https://github.com/meridane/QimaTrade-MVP/actions/runs/42244589409) completed successfully. The Vercel combined status for this docs-only validation head subsequently reported failure with target URL `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`. This is a Preview-provider quota status, not a GitHub CI/CodeQL failure or a production deployment.
- **Interpretation:** the previous live CI audit output reported zero findings at every severity. This is the actual npm audit result for that lockfile/run; it is not inferred from synthetic tests. The wording correction does not itself establish or remediate a dependency vulnerability.
- **Scope and safety:** workflow/report wording and this append-only register only. No application runtime, dependency, lockfile, SQL, migration, Supabase production data, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.
- **Canonical register limitation:** the GitHub file-content connector returned blob SHA `89a8f0c41a465dbf7814d8eeb050ef41ef8909a7` but an empty body for `docs/QIMA_V1_FUNCTION_REGISTER.md` because of the file's size. It was not rewritten or truncated; this entry is retained in the append-only supplement.

- **Latest-head documentation validation:** after the initial QA236 result was recorded, QIMA CI #869 [run 42244916090](https://github.com/meridane/QimaTrade-MVP/actions/runs/42244916090) also completed successfully on the register-update head. The browser log confirms **283/283 Playwright tests passed**; npm audit again reported zero findings at all severities, the high-threshold enforcement step succeeded, TypeScript/build/Chromium and isolated PostgreSQL/RLS jobs succeeded. The browser log includes `ECONNRESET: Auth network connection reset` from the existing mocked Auth transport-failure test; the workflow and all 283 tests passed. CodeQL #824 [run 42244916428](https://github.com/meridane/QimaTrade-MVP/actions/runs/42244916428) completed successfully.

- **Final QA236 head verification:** QIMA CI #870 [run 42245292199](https://github.com/meridane/QimaTrade-MVP/actions/runs/42245292199) completed successfully on the current register head. The browser job log confirms **283/283 Playwright tests passed**; npm audit reported zero findings at all severities and its high-threshold enforcement step succeeded. TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, and participant self-enrollment RLS succeeded. CodeQL #825 [run 42245292368](https://github.com/meridane/QimaTrade-MVP/actions/runs/42245292368) completed successfully. Vercel remains failed with the provider's `build-rate-limit` upgrade target; this is not a CI, CodeQL, or production-deployment result.


## QA237 — run Supabase SSR middleware on the supported Node.js runtime — 7 November 2026

- **Starting point:** PR #26 was open and draft on `fix/create-offer-status-contract`, with 841 commits ahead of `main`, zero behind, and no submitted reviews or review threads. The starting HEAD was `5055172c5226ff782ade837f41c40d3427909258`.
- **Prior build evidence:** QIMA CI #871 [run 42245613273](https://github.com/meridane/QimaTrade-MVP/actions/runs/42245613273) completed the Next.js production build successfully but emitted an Edge Runtime compatibility warning from `@supabase/supabase-js/dist/index.mjs` at `process.version`, imported through `@supabase/ssr`. The committed lockfile resolves `@supabase/ssr@0.7.0` and `@supabase/supabase-js@2.109.0`.
- **Root-cause inspection:** the upstream `v2.109.0` source in [supabase-js constants.ts](https://github.com/supabase/supabase-js/blob/v2.109.0/packages/core/supabase-js/src/lib/constants.ts) reads `process.version` only to populate optional runtime-version metadata in the `X-Client-Info` header, guarded by `typeof process !== 'undefined'`. This matches the build warning and does not by itself demonstrate a runtime failure or confirmed vulnerability. No dependency upgrade or package patch was made.
- **Framework support:** this repository resolves Next.js 15.5.28. Next.js 15.5 made Node.js Middleware runtime support stable; see the [Next.js 15.5 release notes](https://nextjs.org/blog/next-15-5#nodejs-middleware-stable) and [Middleware runtime reference](https://nextjs.org/docs/15/app/api-reference/file-conventions/middleware#runtime). Vercel also documents Node.js Middleware support in its [changelog](https://vercel.com/changelog/middleware-now-supports-node-js).
- **Change:** add `runtime: "nodejs"` to the existing root `middleware.ts` config. The matcher list, Supabase SSR client, cookie handling, auth checks, redirects, and application logic remain unchanged. The purpose is to execute the existing Supabase SSR middleware on the supported Node.js runtime rather than Edge, avoiding an Edge-only static compatibility warning for the SDK's guarded Node metadata access.
- **Code commit:** [`747ea26`](https://github.com/meridane/QimaTrade-MVP/commit/747ea26bf1ce948b3513af5a30188a49262cf471) changes only the single runtime config line in `middleware.ts`.
- **Validation snapshot:** QIMA CI #872 [run 42255611162](https://github.com/meridane/QimaTrade-MVP/actions/runs/42255611162) was in progress when this entry was prepared. npm ci, npm audit, TypeScript, and the Next.js production build had succeeded; the isolated CREATE_OFFER PostgreSQL integration/concurrency and both RLS regression jobs had succeeded. CodeQL #827 [run 42255611331](https://github.com/meridane/QimaTrade-MVP/actions/runs/42255611331) succeeded. Vercel Preview deployment status was success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/2cFSvMYg5yE689cPzMsfWowTF9aK). Chromium installation was still running and Playwright had not yet executed; no final browser count is claimed here.
- **Pending verification:** inspect the completed CI #872 build log for the exact `process.version` Edge Runtime warning and confirm Playwright. If the warning remains, do not patch third-party package files or assume the build warning proves a production defect; record the observed import trace and reassess separately.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA237 — final validation and warning reconciliation — 7 November 2026

- **Code change:** commit [`747ea26`](https://github.com/meridane/QimaTrade-MVP/commit/747ea26bf1ce948b3513af5a30188a49262cf471) adds `runtime: "nodejs"` to the existing Next.js 15.5.28 middleware configuration. No middleware authentication, cookie, redirect, matcher, or application behavior was otherwise changed.
- **Final CI:** QIMA CI #872 [run 42255611162](https://github.com/meridane/QimaTrade-MVP/actions/runs/42255611162) completed successfully. Its job steps confirm npm ci, npm audit, TypeScript, production build, Chromium installation, browser smoke tests, audit enforcement, and both artifact uploads succeeded. The Playwright log reports **283 passed (7.8s)**.
- **Dependency audit:** the actual npm audit JSON summary reported `info=0, low=0, moderate=0, high=0, critical=0, total=0`. This is the observed result for the committed lockfile in this CI run, not an inference from synthetic tests.
- **PostgreSQL and RLS:** the separate CREATE_OFFER PostgreSQL integration/concurrency job, legacy messages RLS regression, and participant self-enrollment RLS regression all completed successfully in CI #872.
- **CodeQL:** QIMA CodeQL #827 [run 42255611331](https://github.com/meridane/QimaTrade-MVP/actions/runs/42255611331) completed successfully.
- **Preview:** the Vercel Preview combined status for code commit `747ea26` is success: [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/2cFSvMYg5yE689cPzMsfWowTF9aK). This is a Preview status only; no production deployment was performed.
- **Build-log reconciliation:** the completed CI #872 job log contains the successful Next.js compilation line and no occurrence of the prior `process.version` / `Edge Runtime` compatibility warning. This confirms that the previously observed build warning is absent from this run's log; it is not a general proof that every runtime path is defect-free.
- **Browser-log note:** the browser job still prints `ECONNRESET: Auth network connection reset` from the existing mocked Auth transport-failure scenario, while the suite reports 283 passed and the job succeeds. This diagnostic is not classified as a failed test.
- **Earlier QA235/QA236 records:** their detailed changes and validation evidence remain in the append-only QA185 supplement; they are not reconstructed or silently rewritten here.
- **Conclusion:** QA237 code validation is complete for CI #872, CodeQL #827, and the Preview status above. The earlier pending Playwright/build-log checks are resolved by the observed results.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA238 — lock the Supabase SSR middleware runtime contract — 7 November 2026

- **Starting point:** PR #26 remains open and draft on `fix/create-offer-status-contract`. QA237 code commit `747ea26` is followed by the completed validation record `ba894ed`.
- **Reason:** the middleware's Node.js runtime selection is now an intentional compatibility decision for the repository's Next.js 15.5.28 + Supabase SSR setup. Existing browser tests exercise protected-route redirects, but they do not directly fail if the exported runtime setting is later removed or changed.
- **Change:** add a Playwright-level configuration regression that imports the root middleware config and asserts `runtime === "nodejs"` plus the exact existing matcher list (`/demands`, `/decision-tree`, `/offers`, `/request`). This is a static configuration contract test; it is not evidence of a security vulnerability or a substitute for a deployed runtime test.
- **Expected suite count:** 284 Playwright tests, one more than the previously validated 283. The count is provisional until the new CI run completes.
- **Validation:** QIMA CI #875 [run 42264099331](https://github.com/meridane/QimaTrade-MVP/actions/runs/42264099331) completed successfully. The browser job log reports **284 passed (8.8s)**; npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, browser tests, and artifact uploads succeeded. The isolated CREATE_OFFER PostgreSQL integration/concurrency job and both RLS regression jobs succeeded. CodeQL #829 [run 42264099335](https://github.com/meridane/QimaTrade-MVP/actions/runs/42264099335) completed successfully. The Vercel Preview status is success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/2qEPXv2JxBgEtUXnS45i6pz1zsoJ). The browser log includes the existing mocked Auth transport-failure diagnostic `ECONNRESET`, while all 284 tests and the job pass; it is not classified as a test failure.
- **Safety:** no middleware behavior, auth/cookie handling, application runtime, dependency, SQL, migration, Supabase production data, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.


## QA239 — preserve query strings in unauthenticated protected-route redirects — 7 November 2026

- **Starting point:** PR #26 is open and draft on `fix/create-offer-status-contract`, at QA238 HEAD `4ae1e6f67c1ee3f738083030b3101ada2303c5d1`; the branch is 845 commits ahead of `main`, zero behind, and has no submitted reviews or review threads.
- **Reason:** the middleware builds the login redirect's `next` parameter from the requested pathname and query string. Existing protected-route browser tests assert preservation of the bare pathname only, leaving deep links and query-driven filters without a direct regression assertion.
- **Change:** add one Playwright regression that visits `/demands?search=steel&sort=recent`, confirms the unauthenticated visitor is redirected to login, and asserts that decoding the `next` parameter yields the exact original path and query string.
- **Expected suite count:** 285 Playwright tests, one more than QA238's validated 284. This count is provisional until the new CI run completes.
- **Validation:** QIMA CI #876 [run 42271409382](https://github.com/meridane/QimaTrade-MVP/actions/runs/42271409382) completed successfully; the browser job reports **285 passed**. npm ci, dependency audit enforcement, TypeScript, the Next.js production build, Chromium installation, browser smoke tests, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy messages RLS regression, and participant self-enrollment RLS regression all succeeded. CodeQL #830 [run 42271409433](https://github.com/meridane/QimaTrade-MVP/actions/runs/42271409433) completed successfully. The final Vercel Preview combined status is success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/Em3NfVMfDs2EmmvAAX3Juoc5ZTSs).
- **Interpretation:** this is a regression test for redirect continuity. It does not establish an authorization defect or prove a production security vulnerability.
- **Safety:** no middleware logic, auth/session handling, cookie behavior, SQL, migration, Supabase production data, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.


## QA240 — preserve duplicate, empty, and encoded query values in login redirects — 7 November 2026

- **Starting point:** PR #26 is open and draft on `fix/create-offer-status-contract`, at QA239 HEAD `a99fe6b5325a6c92ae6ff082386e867186c81b18`; the branch is 849 commits ahead of `main`, zero behind. QA239 has been validated by QIMA CI #876 (285/285) and CodeQL #830; Vercel Preview is blocked by the account's build-rate quota.
- **Reason:** QA239 verifies a simple query string. Redirect continuity also needs coverage for repeated keys, empty values, percent-encoded reserved characters, and UTF-8 values, because a single decode/encode boundary can otherwise silently change filter semantics.
- **Change:** add one Playwright regression using `/demands?tag=steel&tag=aluminum&empty=&q=stainless%20steel%26pipe%3D1&unicode=%E9%9B%AA`. It asserts that the decoded `next` parameter exactly equals the original path/query, that both repeated `tag` values remain in order, that the empty value remains empty, and that the encoded ampersand/equal sign and Unicode value decode to their original semantic values.
- **Code commit:** [`a99fe6b`](https://github.com/meridane/QimaTrade-MVP/commit/a99fe6b5325a6c92ae6ff082386e867186c81b18) adds the test only; no middleware or login/callback logic is changed.
- **Expected suite count:** 286 Playwright tests, one more than QA239's validated 285. This is provisional until the QA240 CI run completes.
- **Initial validation:** QIMA CI #877 [run 42281018243](https://github.com/meridane/QimaTrade-MVP/actions/runs/42281018243) completed with **285 passed and 1 failed**. The only failure was the new byte-identical string assertion: `URLSearchParams` serialized a space as `+` instead of `%20`, while the decoded value remained semantically equivalent. TypeScript, npm audit enforcement, Next.js build, PostgreSQL CREATE_OFFER integration/concurrency, and both RLS regression jobs succeeded. CodeQL #831 [run 42281018221](https://github.com/meridane/QimaTrade-MVP/actions/runs/42281018221) succeeded. The final Vercel Preview status for the initial QA240 commit was success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/Em3NfVMfDs2EmmvAAX3Juoc5ZTSs).
- **Correction:** commit [\`77cfc2d\`](https://github.com/meridane/QimaTrade-MVP/commit/77cfc2d968d555463931054834d9e54628b24a2e) removes the byte-for-byte encoding assumption and verifies the parsed pathname, repeated values, empty value, reserved-character value, and Unicode value instead. Application middleware is unchanged.
- **Final validation:** corrected commit `77cfc2d` passed QIMA CI #878 [run 42281305008](https://github.com/meridane/QimaTrade-MVP/actions/runs/42281305008): the browser job reports **286 passed, 0 failed**. npm ci, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, browser smoke tests, the isolated CREATE_OFFER PostgreSQL integration/concurrency job, legacy messages RLS regression, and participant self-enrollment RLS regression all succeeded. QIMA CodeQL #832 [run 42281305016](https://github.com/meridane/QimaTrade-MVP/actions/runs/42281305016) succeeded. The Vercel status for this commit is failure with `upgradeToPro=build-rate-limit`; Preview deployment is blocked by the account quota, while GitHub CI and CodeQL are green. No production deployment was attempted.
- **Interpretation:** this is a redirect round-trip regression test. It does not establish an open redirect, authorization defect, or production security vulnerability.
- **Safety:** no middleware/auth logic, cookie/session behavior, SQL, migration, Supabase production data, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.


## QA241 — preserve same-origin OAuth callback redirects — 7 November 2026

- **Starting point:** PR #26 is open and draft on `fix/create-offer-status-contract`, at QA240 validated HEAD `35fe7d0781bdd3042bc13fc20979c6693df375ca`. The branch is 855 commits ahead of `main` and zero behind. QA240 was validated by QIMA CI #878 (286/286) and CodeQL #832. The subsequent documentation-only CI #879 and CodeQL #833 also completed successfully; the Vercel combined status remains a rate-limit failure (`upgradeToPro=build-rate-limit`).
- **Reason:** `app/auth/callback/route.ts` contains a same-origin redirect guard. It rejects absent/non-root-relative values, absolute external URLs, protocol-relative URLs, and any candidate whose parsed origin differs from the request origin. The backslash case is important because the WHATWG URL parser treats backslashes as path separators for special schemes and can normalize a relative-looking value into an external authority. This guard had no direct regression suite.
- **Change:** extract the existing pure `getSafeRedirectUrl(next, origin)` function into `lib/auth/safe-redirect.ts` without changing its conditions or fallback. The OAuth callback route imports and uses the extracted helper. Add five Playwright contract tests for a valid same-origin relative destination (including query/fragment), an absolute external URL, protocol-relative and triple-slash destinations, a backslash-normalized external authority, and missing/empty/non-root-relative destinations.
- **Important test scope:** the backslash test first confirms that `new URL(next, origin)` resolves the crafted value to `https://evil.example`, then verifies that the helper returns the local `/demands` fallback. These are deterministic tests of the helper used by the callback; they are not a live OAuth code-exchange test, do not establish a production open redirect, and do not prove a confirmed vulnerability.
- **Expected suite count:** 291 Playwright tests (286 previously validated + 5 new test cases). Provisional until GitHub Actions completes.
- **Final validation:** QIMA CI #880 [run 42293345623](https://github.com/meridane/QimaTrade-MVP/actions/runs/42293345623) completed successfully on PR HEAD `3ca3422d76e756ca38354f20d2f803fa823786bc`. The browser job confirms **291/291 Playwright tests passed (8.3 s)**; dependency installation, npm audit (0 info/low/moderate/high/critical findings in the JSON report), TypeScript, Next.js production build, Chromium installation, audit enforcement, and artifact uploads all succeeded. The isolated CREATE_OFFER PostgreSQL integration/concurrency job and both RLS regression scripts completed successfully. QIMA CodeQL #834 [run 42293346371](https://github.com/meridane/QimaTrade-MVP/actions/runs/42293346371) completed successfully. Vercel Preview combined status is success: [Preview](https://vercel.com/bmk1/qimatrade-mvp/34t14Y4TbS2gm35XGuqRBNZSUe5q). The browser log contains the existing mocked Auth transport-failure diagnostic `ECONNRESET`, while all 291 tests and the job pass; it is not classified as a test failure. PostgreSQL logs include expected negative-fixture diagnostics (`QA103_FORCED_FIRST_ATTEMPT_FAILURE`, `QA104_FORCED_FIRST_ATTEMPT_FAILURE`, and `IDEMPOTENCY_KEY_REUSE`) while the integration job succeeds.
- **Safety:** no Supabase production data, production migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.

## QA242 — OAuth callback failure and success paths — 7 November 2026

- **Starting point:** PR #26 was open and draft on `fix/create-offer-status-contract`, at QA241 HEAD `d89b7ad9ab0a549828fda5d491629f7414ccf592` (862 commits ahead of `main`, zero behind). QA241 was validated by QIMA CI #880 (291/291 Playwright) and CodeQL #834; the documentation-only follow-up CI #881 and CodeQL #835 also succeeded. The Vercel status on the starting HEAD reported a deployment rate limit.
- **Reason:** QA241 covered the pure same-origin destination validator but did not directly characterize the OAuth callback orchestration when the authorization code is missing, the code exchange returns an error, or the exchange throws. A successful exchange should be the only path that honors the already-validated `next` destination.
- **Change:** extract the callback orchestration into `lib/auth/oauth-callback.ts` as `handleOAuthCallback(request, createClient)`, with an injected Supabase-client factory. Keep `app/auth/callback/route.ts` as a thin adapter that passes `createSupabaseServerClient`. A missing code returns `/login?error=oauth_callback_missing_code` without creating a Supabase client. A returned exchange error or thrown client/exchange error returns `/login?error=oauth_callback_failed`; neither failure path honors `next`. A successful exchange redirects only to the same-origin URL returned by the existing `getSafeRedirectUrl` helper.
- **Tests:** add four deterministic callback-handler tests: missing code does not call the client factory and ignores `next`; returned exchange error returns to login; thrown exchange failure returns to login; successful exchange honors a safe same-origin path/query. These tests inject a fake client and do not contact Google OAuth or Supabase.
- **Code commit:** [`f7580ea`](https://github.com/meridane/QimaTrade-MVP/commit/f7580ea3de874a0b166e005b00f79eeeb3f89f30) — `test(auth): cover OAuth callback failure and success paths`. It modifies `app/auth/callback/route.ts`, adds `lib/auth/oauth-callback.ts`, and extends `tests/e2e/auth-callback-redirect.spec.ts`.
- **Validation:** QIMA CI #882 [run 42296238651](https://github.com/meridane/QimaTrade-MVP/actions/runs/42296238651) completed successfully on code HEAD `f7580ea3de874a0b166e005b00f79eeeb3f89f30`. The browser job reports **295 passed (6.4 s)**. Dependency installation, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, browser tests, audit report/lockfile artifact uploads, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy messages RLS regression, and participant self-enrollment RLS regression all succeeded. QIMA CodeQL #836 [run 42296238675](https://github.com/meridane/QimaTrade-MVP/actions/runs/42296238675) completed successfully. The browser log includes the existing simulated Auth transport diagnostic `ECONNRESET`, while all 295 tests and the job pass; it is not a test failure. PostgreSQL logs contain expected negative-fixture diagnostics (`QA103_FORCED_FIRST_ATTEMPT_FAILURE`, `QA104_FORCED_FIRST_ATTEMPT_FAILURE`, and `IDEMPOTENCY_KEY_REUSE`) while the integration job succeeds.
- **Vercel:** the commit status reports `Deployment rate limited — retry in 24 hours` with `upgradeToPro=build-rate-limit`. No Preview for this HEAD is claimed; the quota was not bypassed.
- **Interpretation:** this validates the callback handler's control flow using an injected fake Supabase client. It is not a live Google OAuth exchange, a production Supabase test, evidence of an open redirect, or proof of a confirmed vulnerability.
- **Safety:** no Supabase production data, production migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.

## QA242 — documentation HEAD validation (7 November 2026)

- **Documentation commit:** [`c343180`](https://github.com/meridane/QimaTrade-MVP/commit/c343180bb91de59313519c19a8553010da6bda02), which adds QA242 to both registers.
- **QIMA CI #883:** [run 42296537775](https://github.com/meridane/QimaTrade-MVP/actions/runs/42296537775) completed successfully on documentation HEAD `c343180bb91de59313519c19a8553010da6bda02`. The browser job reports **295 passed (5.9 s), 0 failed**. Dependency installation, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, browser tests, audit/lockfile artifact uploads, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, and both RLS regression jobs all succeeded.
- **QIMA CodeQL #837:** [run 42296537771](https://github.com/meridane/QimaTrade-MVP/actions/runs/42296537771) completed successfully on the same documentation HEAD.
- **Vercel:** commit status remains `failure` with description `Deployment rate limited — retry in 24 hours` and target `upgradeToPro=build-rate-limit`. This is a provider quota limitation; no Preview for this HEAD is claimed and no quota bypass was attempted.
- **Interpretation:** these checks validate the register-updated PR HEAD. QA242's functional code and four callback tests were independently validated by CI #882 (295/295) and CodeQL #836.
- **Safety:** no production Supabase data, production migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.


## QA243 — fail closed when the Supabase OAuth client factory cannot initialize — 7 November 2026

- **Starting point:** PR #26 is open and draft on `fix/create-offer-status-contract`, at QA242 validated HEAD `033dbee5e35a872208ed2b0c3c43fb4a5b716227`. The PR has 865 commits ahead of `main`, zero behind. QA242 was validated by QIMA CI #884 (295/295 Playwright) and CodeQL #838; the Vercel Preview status for that HEAD is rate-limited.
- **Reason:** `handleOAuthCallback` already wraps both the injected Supabase client factory and `exchangeCodeForSession` in a catch boundary. QA242 covered a thrown exchange call, but did not directly test a failure before a client object is returned. This leaves the initialization-failure branch without a focused regression assertion.
- **Change:** add one deterministic test to `tests/e2e/auth-callback-redirect.spec.ts`. The injected client factory throws an error containing a synthetic secret-like marker before returning a client. The test asserts HTTP 307 to the same-origin `/login`, the generic `oauth_callback_failed` code, absence of `next`, and absence of the marker from the redirect URL. No application runtime code is changed because the existing catch boundary already implements the expected fail-closed response.
- **Code commit:** [`b80bf55`](https://github.com/meridane/QimaTrade-MVP/commit/b80bf55748e9ce88b05ce0d247533501a005288d) — `test(auth): cover Supabase OAuth client initialization failure`. Only the callback regression test file is modified.
- **Expected suite count:** 296 Playwright tests (295 previously validated + one new initialization-failure case). This count is provisional until the GitHub Actions browser job completes.
- **Validation at documentation time:** the code commit is present on the PR branch. The Vercel commit status was pending and no GitHub Actions workflow run was yet returned by the commit-run lookup. No test result is claimed for QA243 until a run reports its conclusion.
- **Test scope:** the test injects a factory that throws before creating a Supabase client; it does not contact Google OAuth or Supabase, does not inspect production logs, and does not prove that a production vulnerability exists. The response assertion only establishes that the redirect URL contains the generic error and not the synthetic marker.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.


## QA243 — final validation update — 7 November 2026

- **Validated code HEAD:** `323cb6f27a4d91293d6873d27335b08328e4c210`.
- **QIMA CI #886:** [run 42304125481](https://github.com/meridane/QimaTrade-MVP/actions/runs/42304125481) completed successfully. The browser log reports **296 passed (8.0 s), 0 failed**. Dependency installation from the committed lockfile, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, Playwright, audit-report and lockfile artifact uploads, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy-messages RLS regression, and participant self-enrollment RLS regression all succeeded.
- **QIMA CodeQL #840:** [run 42304125873](https://github.com/meridane/QimaTrade-MVP/actions/runs/42304125873) completed successfully.
- **Vercel:** the combined commit status for this HEAD is `success`, with target [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/4A1LsYCwVVHyCDbaXyVpQusBD2UH). This supersedes the earlier provisional note that the Preview was pending/rate-limited.
- **Interpretation:** the initialization-failure test uses an injected factory that throws before a Supabase client is returned. It validates the handler's generic same-origin failure redirect and absence of the synthetic marker from the redirect URL. It is not a live Google OAuth/Supabase test and does not establish a production vulnerability or inspect server logs.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA244 — Supabase SSR cookie adapter regression coverage — 7 November 2026

- **Starting point:** QA243 code HEAD `323cb6f27a4d91293d6873d27335b08328e4c210` is validated by CI #886 (296/296), CodeQL #840, and a successful Vercel Preview status. PR #26 is open and draft on `fix/create-offer-status-contract`, 868 commits ahead of `main` and zero behind at the start of QA244.
- **Reason:** OAuth callback success depends on Supabase SSR persisting PKCE/session cookie mutations. The existing `lib/supabase/server.ts` correctly supplied `getAll` and `setAll`, but that adapter behavior had no isolated regression tests.
- **Source inspection:** Supabase SSR `v0.7.0` exports `CookieOptions` and documents that server clients must receive `getAll` and `setAll`; its `createServerClient` applies cookie mutations for the PKCE verifier and auth-state changes. Next.js `v15.5.28` App Route Handler source merges mutable cookies into the returned response headers via `appendMutableCookies(headers, requestStore.mutableCookies)`. References: [Supabase SSR types](https://github.com/supabase/ssr/blob/v0.7.0/src/types.ts), [Supabase SSR server client](https://github.com/supabase/ssr/blob/v0.7.0/src/createServerClient.ts), [Supabase SSR cookie storage](https://github.com/supabase/ssr/blob/v0.7.0/src/cookies.ts), [Next.js App Route Handler](https://github.com/vercel/next.js/blob/v15.5.28/packages/next/src/server/route-modules/app-route/module.ts).
- **Change:** extract the existing `getAll`/`setAll` adapter into `lib/supabase/cookie-methods.ts`; wire the unchanged adapter behavior into `lib/supabase/server.ts`; add three deterministic tests for reading all request cookies, forwarding multiple cookie mutations with their options (including a zero-age removal), and tolerating immutable cookie stores outside Route Handlers.
- **Code commit:** [`090c57f`](https://github.com/meridane/QimaTrade-MVP/commit/090c57f9d1df10fde0bd7ebef85b4b8f6bc789be) — `test(auth): cover Supabase SSR cookie adapter contract`.
- **Expected browser suite:** 299 tests (296 previously validated + 3 cookie-adapter tests). This is provisional until GitHub Actions completes on the final PR HEAD.
- **Test scope and limitation:** the three tests exercise the extracted adapter with an in-memory fake cookie store. They do not execute a live Supabase token exchange or prove browser cookie persistence end-to-end. The Next.js source inspection confirms the framework's Route Handler response-merging path for mutable cookies; a live provider-backed OAuth exchange is not performed.
- **Validation at documentation time:** CI and CodeQL runs for the new code commit had not yet appeared in the commit-run lookup. Do not treat the expected test count as a pass until the PR-triggered workflow result is available.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA245 — Next.js redirect Set-Cookie serialization regression — 7 November 2026

- **Starting point:** PR #26 branch `fix/create-offer-status-contract` was identical to validated QA244 HEAD `38f97461e3e5115ef2a45233bb60c978135eb06a`, 871 commits ahead of `main` and zero behind. QA244 was validated by QIMA CI #888 (**299 Playwright tests passed, 0 failed**), CodeQL #842, and a successful Vercel Preview status.
- **Reason:** QA244 verified that the Supabase SSR adapter forwards cookie mutations to a cookie-store interface, but it did not exercise Next.js's actual `NextResponse.cookies` serialization or assert the resulting `Set-Cookie` response header.
- **Change:** add one regression test to `tests/e2e/supabase-cookie-adapter.spec.ts`. It wires the existing adapter to a real `NextResponse.redirect()` cookie API and forwards two chunked auth-cookie names plus a zero-age base-cookie removal. It asserts the 307 redirect location, all three cookie names in the response cookie collection, serialized `Set-Cookie` values, and `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, and `Max-Age=0` attributes.
- **Code commits:** [`8c99428`](https://github.com/meridane/QimaTrade-MVP/commit/8c99428a6480c3ebbbd5c6f6b609cf465e1fd698) adds the response-serialization test; [`c64d8fc`](https://github.com/meridane/QimaTrade-MVP/commit/c64d8fc52b5e4ea908e224152a75729847577dd6) adds the explicit `NextResponse` import. The PR branch was advanced by a non-forced fast-forward from the verified QA244 HEAD.
- **Expected browser suite:** 300 tests (299 previously validated + 1 new response-serialization test). This count is provisional until GitHub Actions completes for code HEAD `c64d8fc52b5e4ea908e224152a75729847577dd6`.
- **Test scope and limitation:** the test uses the real Next.js `NextResponse` cookie serializer but supplies an in-memory cookie-store adapter. It verifies serialized response headers and chunk/removal forwarding; it does not execute Next.js request async-storage, prove that a live `cookies()` mutation is merged into an actual OAuth Route Handler response, contact Supabase/Google, or establish a production vulnerability.
- **Validation at documentation time:** QIMA CI and CodeQL runs for code HEAD `c64d8fc52b5e4ea908e224152a75729847577dd6` had not yet appeared in the commit-run lookup. Do not claim the expected 300 tests as passed until a matching workflow run completes. The existing CI #888 and CodeQL #842 validate QA244 HEAD `38f9746`, not the new QA245 code.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is changed.


## QA245 — final validation update — 7 November 2026

- **Validated code HEAD:** `c64d8fc52b5e4ea908e224152a75729847577dd6`.
- **Final PR/documentation HEAD before this validation note:** `a410d039e4eeec306c02bc3d5c3d2a8033093c34`; branch `fix/create-offer-status-contract` was identical to that commit, 875 commits ahead of `main`, zero behind, with 53 files in the PR diff.
- **QIMA CI #889:** [run 42322247075](https://github.com/meridane/QimaTrade-MVP/actions/runs/42322247075) was cancelled when the subsequent register update synchronized the PR and started the newer CI #890. It is superseded, not counted as a failed test run.
- **QIMA CI #890:** [run 42322317401](https://github.com/meridane/QimaTrade-MVP/actions/runs/42322317401) completed successfully. The browser log reports **300 passed (6.5 s), 0 failed**. Dependency installation, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, Playwright, audit-report and lockfile artifact uploads, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy-messages RLS regression, and participant self-enrollment RLS regression all succeeded.
- **npm audit:** the captured JSON summary reports `info=0, low=0, moderate=0, high=0, critical=0, total=0` for this run. This is the dependency-tree result at the time of CI #890, not a guarantee about future dependency states.
- **QIMA CodeQL #843:** [run 42322247064](https://github.com/meridane/QimaTrade-MVP/actions/runs/42322247064) completed successfully on code HEAD `c64d8fc`.
- **QIMA CodeQL #844:** [run 42322317294](https://github.com/meridane/QimaTrade-MVP/actions/runs/42322317294) completed successfully on the register-updated PR HEAD.
- **Vercel Preview:** the combined status for final PR HEAD `a410d03` is `success`, target [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/2xLsMgHXGnzFc4UYDuXifdN6qt8D). This is a Preview status only; no production deployment was performed.
- **Test interpretation:** the added regression exercises the real Next.js `NextResponse` cookie serializer via an in-memory cookie-store adapter. It verifies chunked cookie names, zero-age removal, serialized `Set-Cookie` headers and attributes. It does not execute Next.js request async-storage, prove the full `cookies()` to Route Handler merge in a live OAuth request, contact Google/Supabase, or establish a production vulnerability.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA246 — Supabase server-client cookie wiring contract — 7 November 2026

- **Starting point:** PR #26 branch `fix/create-offer-status-contract` was at QA245 final HEAD `24482e4174a01d3db1371ddc049af06dfb323155`, open and draft, 877 commits ahead of `main`, zero behind, with 53 changed files. QIMA CI #891 [run 42322531710](https://github.com/meridane/QimaTrade-MVP/actions/runs/42322531710) completed successfully with **300 Playwright tests passed, 0 failed**; CodeQL #845 [run 42322531689](https://github.com/meridane/QimaTrade-MVP/actions/runs/42322531689) succeeded. The Vercel status on that starting HEAD was rate-limited (`build-rate-limit`).
- **Reason:** QA245 exercised the actual Next.js `NextResponse` cookie serializer, but not the production server-client options function that binds Next.js's request cookie store to Supabase SSR. A full Route Handler request-context test was considered; the current test suite does not expose a supported public API for constructing Next.js request async storage when invoking the handler directly, and no isolated Google/Supabase auth environment is configured. Private Next.js internals or live provider credentials were not introduced merely to force that test.
- **Change:** extract `createSupabaseServerClientOptions(cookieStore)` in `lib/supabase/server.ts`. The production `createSupabaseServerClient()` continues to call Next.js `cookies()` and now passes the resulting store through this exact helper to `createServerClient`. Add one regression test in `tests/e2e/supabase-cookie-adapter.spec.ts` verifying that the helper's returned SSR options forward incoming cookies through `getAll` and forward a session-cookie mutation and its options through `setAll`.
- **Code commit:** [`ced082e`](https://github.com/meridane/QimaTrade-MVP/commit/ced082e8eb97f01326ff330f8881eb20413b9f21) — `test(auth): verify Supabase server client cookie wiring`.
- **Validation:** QIMA CI #892 [run 42324215593](https://github.com/meridane/QimaTrade-MVP/actions/runs/42324215593) completed successfully. The browser job reports **301 passed (6.0 s), 0 failed**. Dependency installation, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, Playwright, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy-messages RLS regression, and participant self-enrollment RLS regression all succeeded. Do not infer lower-severity audit counts beyond the recorded audit artifact; the enforced threshold was `high`.
- **CodeQL:** QIMA CodeQL #846 [run 42324215710](https://github.com/meridane/QimaTrade-MVP/actions/runs/42324215710) completed successfully on code HEAD `ced082e`.
- **Vercel Preview:** the combined status for code HEAD `ced082e` is `success`, target [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/5JEZFyBTz6SXUTP4bQ7UPXeSoei1). This is a Preview only; no production deployment was performed.
- **Test scope and limitation:** the new test exercises the exact options helper used by the production server-client factory with an in-memory cookie store. It verifies the production wiring seam, not Next.js request async-storage, a full live Route Handler response merge, Google OAuth, or a live Supabase token exchange. Full request-context integration remains deferred until a supported local harness or isolated auth environment is available. No production vulnerability is inferred from this synthetic test.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA247 — Supabase SSR cookie batch failure semantics — 7 November 2026

- **Starting point:** PR #26 branch `fix/create-offer-status-contract` was at QA246 HEAD `00e5a9823123b6739cdd391a7764f367a8e0df5a`, open and draft, **879 commits ahead of main and zero behind**, with 53 changed files. QIMA CI #893 [run 42324365700](https://github.com/meridane/QimaTrade-MVP/actions/runs/42324365700) and CodeQL #847 [run 42324365707](https://github.com/meridane/QimaTrade-MVP/actions/runs/42324365707) both completed successfully. Vercel on the starting HEAD was rate-limited.
- **Reason:** the existing immutable-cookie-store test proved that one rejected write is swallowed, but did not define what happens when a multi-cookie batch has already written one cookie and a later write fails. The adapter wraps the whole `forEach` in one `try/catch`; this means a failed mutation is swallowed, previously completed writes are not rolled back, and later mutations are not attempted. This is a non-atomic best-effort behavior, not evidence of a security vulnerability.
- **Change:** clarify this limitation in the `createSupabaseCookieMethods` doc comment. Add one regression in `tests/e2e/supabase-cookie-adapter.spec.ts`: the first mutation succeeds, the second throws, the adapter does not propagate the exception, and the third mutation is not attempted. No runtime behavior was changed.
- **Code commit:** [`a1b4c82`](https://github.com/meridane/QimaTrade-MVP/commit/a1b4c825d016cfe744fe4cbaba681a9f3b455dac) — `test(auth): document cookie batch failure semantics`.
- **Validation:** QIMA CI #894 [run 42331323206](https://github.com/meridane/QimaTrade-MVP/actions/runs/42331323206) completed successfully. Dependency installation, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, browser smoke tests, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy-messages RLS regression, and participant self-enrollment RLS regression all succeeded. The workflow-run job metadata confirms the Playwright step succeeded; it does not expose the exact test total, so no exact count is asserted here.
- **CodeQL:** QIMA CodeQL #848 [run 42331323176](https://github.com/meridane/QimaTrade-MVP/actions/runs/42331323176) completed successfully.
- **Vercel Preview:** combined status for code HEAD `a1b4c82` is `success`, target [Preview deployment](https://vercel.com/bmk1/qimatrade-mvp/6Virug43Cq39NdNQ2ja5tMuBuYh6). Preview only; no production deployment.
- **Test interpretation:** the test documents the current adapter's behavior with an in-memory cookie store. It does not exercise a live Next.js request context, Google OAuth, a live Supabase session, or establish a production vulnerability. Partial mutation is explicitly not transactional.
- **Canonical register limitation:** the canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` blob is larger than the content endpoint currently returns; GitHub's file-content read returned an empty body while providing its blob SHA, and raw-file retrieval was rejected as oversized. It was not replaced or rewritten from incomplete content. This QA247 record is appended to the companion register instead; the canonical file remains unchanged in this run.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA247 — final validation reconciliation — 7 November 2026

- QIMA CI #894 [run 42331323206](https://github.com/meridane/QimaTrade-MVP/actions/runs/42331323206) succeeded with **302 passed (6.3 s), 0 failed**; TypeScript, production build, npm audit gate at `high`, isolated CREATE_OFFER PostgreSQL/concurrency, and both RLS regression jobs succeeded.
- CodeQL #848 [run 42331323176](https://github.com/meridane/QimaTrade-MVP/actions/runs/42331323176) succeeded.
- Vercel Preview for code HEAD `a1b4c82` succeeded: [Preview](https://vercel.com/bmk1/qimatrade-mvp/6Virug43Cq39NdNQ2ja5tMuBuYh6).
- The exact Playwright count and Preview outcome are reconciled here; the earlier QA247 entry remains as the contemporaneous record.

## QA248 — Supabase SSR PKCE cookie persistence — 7 November 2026

- **Starting PR HEAD:** `ac6d8113769bc7ca24a0ccf405ea9987cc7d0988`; PR #26 open/draft, 881 commits ahead of `main`, zero behind, 53 changed files.
- **Change:** add one regression to `tests/e2e/supabase-cookie-adapter.spec.ts` using the actual `createServerClient` from `@supabase/ssr` and the production `createSupabaseServerClientOptions(cookieStore)` helper. The test invokes Google `signInWithOAuth` with `skipBrowserRedirect: true` and asserts the generated provider/S256 authorization URL plus a non-empty PKCE verifier cookie written through the helper.
- **Initial code commit:** `db11bc019c49400f9e3ca908fa892028a9f3c719`. QIMA CI #896 [run 42333559209](https://github.com/meridane/QimaTrade-MVP/actions/runs/42333559209) reported **302 passed, 1 failed** because the test-created Supabase client attempted WebSocket capability detection in Node.js 20. TypeScript, build, audit gate and PostgreSQL/RLS checks passed.
- **Correction commit:** `a3d266cb511389b8c718bdf57b128f2b67058cca` supplies a test-only no-op Realtime transport; no dependency or production runtime code was added.
- **Final validation:** QIMA CI #897 [run 42333735058](https://github.com/meridane/QimaTrade-MVP/actions/runs/42333735058) succeeded with **303 passed (8.8 s), 0 failed**. TypeScript, build, npm audit enforcement at `high`, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **CodeQL:** #850 [run 42333559208](https://github.com/meridane/QimaTrade-MVP/actions/runs/42333559208) and #851 [run 42333734968](https://github.com/meridane/QimaTrade-MVP/actions/runs/42333734968) succeeded.
- **Vercel:** corrected code HEAD status is `failure` with `upgradeToPro=build-rate-limit`; no Preview is claimed for this HEAD. This is a deployment quota, not a CI build failure.
- **Scope:** actual Supabase SSR client and PKCE generation are exercised, but with placeholder credentials and an in-memory cookie store. No Google/Supabase network exchange, real Next.js Route Handler request context, browser cookie persistence, or production vulnerability is established.
- **Safety:** no production Supabase data, migration, RLS policy, production configuration, production deployment, merge, or branch-protection setting was changed.


## QA248 — final documentation-head verification — 7 November 2026

- **Documentation commit:** [`8e36867`](https://github.com/meridane/QimaTrade-MVP/commit/8e3686798a250df5b00cfeb0cf64ac70ddd9471b) appended the QA247 reconciliation and QA248 results to both registers.
- **QIMA CI #898:** [run 42333926504](https://github.com/meridane/QimaTrade-MVP/actions/runs/42333926504) completed successfully on documentation HEAD `8e36867`. The browser log confirms **303 passed (6.2 s), 0 failed**. TypeScript, Next.js production build, Chromium, npm audit enforcement at the configured `high` threshold, isolated CREATE_OFFER PostgreSQL integration/concurrency tests, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #852:** [run 42333926398](https://github.com/meridane/QimaTrade-MVP/actions/runs/42333926398) completed successfully.
- **Vercel:** the status remains `failure` with `upgradeToPro=build-rate-limit`; this is a provider quota limitation, not a failed CI build. No Preview is claimed for documentation HEAD `8e36867`.
- This run verifies the documentation update; it does not change the QA248 code-test scope or establish live provider/session behavior.



## QA249 — Supabase SSR PKCE exchange and session-cookie persistence — 7 November 2026

- **Starting PR HEAD:** `ecc1db6f89e5035484d72ffa33473ae87c3aa21f`; PR #26 was open/draft, based on `main`, 885 commits ahead and zero behind, with 53 changed files. QIMA CI #899 [run 42334064007](https://github.com/meridane/QimaTrade-MVP/actions/runs/42334064007) and CodeQL #853 [run 42334064121](https://github.com/meridane/QimaTrade-MVP/actions/runs/42334064121) both completed successfully. Vercel Preview status on that HEAD was rate-limited (`build-rate-limit`).
- **Reason:** QA248 exercised real Supabase SSR PKCE initiation and verifier-cookie creation, but did not call `exchangeCodeForSession`. QA249 covers the token-exchange request, persistence of the returned session through the same cookie adapter, and verifier cleanup.
- **Change:** add two tests to `tests/e2e/supabase-cookie-adapter.spec.ts`. Both construct the actual `createServerClient` from the locked `@supabase/ssr` 0.7.0 / `@supabase/supabase-js` 2.109.0 stack, use the production `createSupabaseServerClientOptions(cookieStore)` helper, and use an in-memory cookie store plus a stubbed Auth fetch. The success case first runs Google PKCE initiation, then exchanges a synthetic code and checks the POST `/auth/v1/token?grant_type=pkce` request carries a non-empty verifier, a session with the synthetic access/refresh tokens is returned and persisted in auth-token cookies, and the verifier cookie is removed. The failure case returns a synthetic HTTP 400 `invalid_grant` and checks no session is returned or persisted. Supabase SSR 0.7.0 marks the verifier removed in request-local storage but defers flushing cookie mutations until an auth-state event; because a failed exchange emits no event, the external cookie store retains the old verifier cookie.
- **Code commit:** [`7572990`](https://github.com/meridane/QimaTrade-MVP/commit/7572990e6b1cda27a585753159d12b71e486cee3) — `test(auth): cover PKCE exchange session cookie persistence`.
- **First validation:** QIMA CI #900 [run 42337554535](https://github.com/meridane/QimaTrade-MVP/actions/runs/42337554535) on code commit `7572990` was cancelled when the subsequent register commit advanced the PR. QIMA CI #902 [run 42337595527](https://github.com/meridane/QimaTrade-MVP/actions/runs/42337595527) on documentation HEAD `16363d0` completed with **304 passed, 1 failed**. The failed assertion expected the external cookie store to lose the verifier immediately after a synthetic `invalid_grant`. TypeScript, production build, npm audit enforcement, isolated PostgreSQL CREATE_OFFER/RLS tests and CodeQL #856 succeeded.
- **SDK behavior confirmed:** the locked `@supabase/ssr` 0.7.0 `src/cookies.ts` `removeItem` records the key in `removedItems` without calling `setAll`; `src/createServerClient.ts` flushes pending storage changes only on selected auth-state events. An unsuccessful PKCE exchange emits no success event, so the request-local storage marks the verifier removed while the external cookie store is not flushed. This is documented SDK behavior, not evidence of an exploitable vulnerability.
- **Correction:** [`337c3a2`](https://github.com/meridane/QimaTrade-MVP/commit/337c3a2b3e70f0a3dd0d5f283334ceda78443cfe) changes the failure regression to assert no session is persisted, the external cookie jar remains unchanged, and a second exchange on the same client fails without a second Auth request.
- **Final validation:** QIMA CI #903 [run 42337757335](https://github.com/meridane/QimaTrade-MVP/actions/runs/42337757335) completed successfully with **305 passed (6.6 s), 0 failed**. npm install, npm audit enforcement at `high`, TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded. QIMA CodeQL #857 [run 42337757307](https://github.com/meridane/QimaTrade-MVP/actions/runs/42337757307) completed successfully.
- **Vercel:** the combined status for corrected code HEAD `337c3a2` is `failure` with `upgradeToPro=build-rate-limit`; this is a provider build-quota limitation, not a Next.js build failure. No Preview is claimed for this HEAD.
- **Test scope:** the real Supabase SSR/Auth client and PKCE exchange/storage code execute, but the Auth HTTP response is synthetic and no request is sent to Google or Supabase. The in-memory cookie store verifies the adapter contract, not browser persistence, Next.js request async-storage, or the complete live Route Handler response merge. No production vulnerability is inferred from the synthetic response.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.
