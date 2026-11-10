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
## QA250 — OAuth PKCE verifier-cookie cleanup on callback failure — 7 November 2026

- **Starting PR state:** PR #26 was open and draft, mergeable, based on `main`, with 891 commits ahead, zero behind and 53 changed files. Starting HEAD was `ac5db77cb6d392b9d334594b27de65c616d6201f`. QIMA CI #905 [run 42337905230](https://github.com/meridane/QimaTrade-MVP/actions/runs/42337905230) and CodeQL #859 [run 42337905234](https://github.com/meridane/QimaTrade-MVP/actions/runs/42337905234) had succeeded. Vercel was rate-limited on that starting revision.
- **Reason:** QA249 confirmed that Supabase SSR 0.7.0 marks a PKCE verifier as removed in request-local storage after `invalid_grant`, but does not flush that removal to the external cookie store without a subsequent auth-state event. QA250 makes the callback explicitly expire stale Supabase verifier cookies on an OAuth failure and verifies the deletion contract.
- **Implementation:** `lib/supabase/server.ts` now exposes `clearSupabasePkceVerifierCookiesFromStore` and `clearSupabasePkceVerifierCookies`. The helper matches only default Supabase auth verifier cookie names (`sb-…-auth-token-code-verifier`) and numeric chunks, deletes those cookies through the Next.js cookie store, and leaves session/unrelated cookies untouched. `lib/auth/oauth-callback.ts` accepts an optional cleanup callback and invokes it for an exchange error or thrown client/exchange failure. Cleanup is best-effort: its own exception cannot replace the generic `/login?error=oauth_callback_failed` response. Missing-code and successful-exchange paths do not invoke cleanup. `app/auth/callback/route.ts` wires the real Next.js cleanup helper into the callback.
- **Regression coverage:** `tests/e2e/auth-callback-redirect.spec.ts` now asserts cleanup on returned exchange errors, thrown exchange errors and client-factory failures; no cleanup on missing code or successful exchange; and a cleanup exception does not leak its message or change the fail-closed redirect. `tests/e2e/supabase-cookie-adapter.spec.ts` uses the real NextResponse cookie serializer to verify that both the verifier cookie and a numeric chunk receive expiration `Set-Cookie` headers while the session cookie and an unrelated cookie remain intact.
- **Code commits:** [`bc2aeeb`](https://github.com/meridane/QimaTrade-MVP/commit/bc2aeeb5e99fd48cc6bfdf8605fdb626aee0c721) introduced the cleanup implementation and tests. Review of its diff caught an over-escaped chunk-name regular expression before final validation. [`d071c9a`](https://github.com/meridane/QimaTrade-MVP/commit/d071c9adc8c1865c4d18c5a76527385709562a28) corrected the regex to match literal dot-plus-digits chunk suffixes.
- **Superseded validation:** QIMA CI #906 [run 42345584962](https://github.com/meridane/QimaTrade-MVP/actions/runs/42345584962) on the first code commit was cancelled as the branch advanced to the regex correction. CodeQL #860 [run 42345585024](https://github.com/meridane/QimaTrade-MVP/actions/runs/42345585024) succeeded on the first code commit.
- **Final CI:** QIMA CI #907 [run 42345604697](https://github.com/meridane/QimaTrade-MVP/actions/runs/42345604697) completed successfully on `d071c9a`. Playwright reported **307 passed (7.7 s), 0 failed**. npm installation, npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency tests, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **CodeQL:** QIMA CodeQL #861 [run 42345604709](https://github.com/meridane/QimaTrade-MVP/actions/runs/42345604709) completed successfully.
- **Vercel:** the commit status on `d071c9a` is `success` (deployment completed); this is a Preview status, not a production deployment.
- **Scope and limitations:** the cookie cleanup helper is tested against NextResponse's real response-cookie serializer, while callback tests inject the cleanup callback. This does not execute the complete Next.js Route Handler request async-storage in a live browser or contact Google/Supabase. The behavior characterized in QA249 is an SDK implementation detail; the synthetic tests do not establish a production vulnerability.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.
## QA250 — final documentation-head verification — 7 November 2026

- **Documentation commit:** [`06d2e35`](https://github.com/meridane/QimaTrade-MVP/commit/06d2e35e5e8f6102d614f618d046f401dfec8f7a) updated the canonical register and QA185 addendum with the QA250 implementation and code-validation results.
- **QIMA CI #908:** [run 42345771062](https://github.com/meridane/QimaTrade-MVP/actions/runs/42345771062) completed successfully on documentation HEAD `06d2e35`. Playwright reported **307 passed (8.2 s), 0 failed**. npm installation, npm audit enforcement at `high`, TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #862:** [run 42345771084](https://github.com/meridane/QimaTrade-MVP/actions/runs/42345771084) completed successfully.
- **Vercel:** the commit status on `06d2e35` is `success` (`Deployment has completed`). This is a Preview deployment status, not production.
- **Conclusion:** QA250 code and the first documentation update are validated. The helper/callback tests remain deterministic; no live Google/Supabase OAuth exchange or complete browser Route Handler request-context test is claimed.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA251 — OAuth PKCE cleanup through the real Next.js Route Handler — 7 November 2026

- **Starting state:** PR #26 was open and draft, mergeable, with 895 commits ahead of `main`, zero behind and 53 changed files. Starting HEAD was `7afa2977e0dd75eb00852c63279f506c172ba9ae`. The preceding QA250 checks had completed successfully: QIMA CI #909 was green, CodeQL #863 was green, while Vercel reported `upgradeToPro=build-rate-limit`.
- **Goal:** replace the remaining serializer-only assertion with an HTTP-level test that executes the built Next.js `/auth/callback` Route Handler and inspects the actual 307 response headers.
- **Isolated fixture:** added `tests/fixtures/mock-supabase-auth-server.mjs`, a local-only HTTP server on `127.0.0.1:54321`. It records PKCE token requests, returns a synthetic `invalid_grant` for the failure case, and returns a deterministic test session only for the success case with the expected fresh verifier. No Google or Supabase service is contacted.
- **Test harness:** `playwright.config.ts` now starts the mock Auth server and the production-built Next.js server as separate Playwright web servers. The CI build and browser-test steps point `NEXT_PUBLIC_SUPABASE_URL` at the local fixture only; no production environment or secret was changed. The two HTTP integration tests are skipped outside the isolated CI environment.
- **Failure-path regression:** a request to the real Route Handler with an encoded stale PKCE verifier receives HTTP 307 to `/login?error=oauth_callback_failed`; its response contains a deletion `Set-Cookie` for the verifier, does not create a session cookie, and the mock Auth server confirms the verifier was sent with the rejected code.
- **Retry/success regression:** a separate request with a fresh verifier is accepted by the mock Auth server. The real Route Handler redirects to the safe `/offers` destination, emits a session cookie, and expires the verifier cookie in the same 307 response. The mock server confirms the exact fresh verifier reached the PKCE token endpoint.
- **Initial failed validation:** QIMA CI #910 [run 42346647419](https://github.com/meridane/QimaTrade-MVP/actions/runs/42346647419) reported **307 passed, 2 failed**. The HTTP response assertions passed, but the mock Auth server received no token requests because the test fixture supplied a raw verifier cookie value. This was a fixture-format error, not evidence of a product defect.
- **Root cause and correction:** Supabase SSR 0.7.0 uses its default `base64url` cookie encoding and stores the Auth client's JSON-serialized PKCE verifier. The fixture now sends `base64-` plus base64url(JSON.stringify(verifier)), matching the SDK's storage contract. This correction is in commit [`091f43e`](https://github.com/meridane/QimaTrade-MVP/commit/091f43ee90cdb1983dffe51c3f52513165f9ba5e).
- **Code commits:** [`52d83da`](https://github.com/meridane/QimaTrade-MVP/commit/52d83da305d2e563d7d5196414aa85a7137dab44) added the local Auth fixture; [`3c338a4`](https://github.com/meridane/QimaTrade-MVP/commit/3c338a45d6f2c71b98f5037e3be2bc96abc1c689) configured the Playwright servers; [`12e8e8e`](https://github.com/meridane/QimaTrade-MVP/commit/12e8e8ed113e97293c0a38f3709122659d05c42b) pointed the CI build/test environment at the local fixture; [`36662e7`](https://github.com/meridane/QimaTrade-MVP/commit/36662e7270284603594b49eddaa19adafca217e7) added the two Route Handler tests; [`091f43e`](https://github.com/meridane/QimaTrade-MVP/commit/091f43ee90cdb1983dffe51c3f52513165f9ba5e) corrected the verifier cookie encoding.
- **Final CI:** QIMA CI #911 [run 42346867125](https://github.com/meridane/QimaTrade-MVP/actions/runs/42346867125) completed successfully. Playwright reported **309 passed (6.8 s), 0 failed**. npm installation, npm audit (0 findings reported at info/low/moderate/high/critical in this run), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **CodeQL:** QIMA CodeQL #864 [run 42346647455](https://github.com/meridane/QimaTrade-MVP/actions/runs/42346647455) and #865 [run 42346867100](https://github.com/meridane/QimaTrade-MVP/actions/runs/42346867100) both completed successfully.
- **Vercel:** the commit status on code HEAD `091f43e` remains failure with `upgradeToPro=build-rate-limit`. This is a provider build-quota limitation, not a failed Next.js build: the GitHub Actions production build passed. No Preview is claimed for this HEAD.
- **Scope and limitations:** this test executes the actual Next.js Route Handler over HTTP and verifies its real 307 `Set-Cookie` headers, but the Auth token endpoint is a local synthetic fixture. It does not contact Google or Supabase, and it does not establish a production vulnerability.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA251 — documentation-head verification — 7 November 2026

- **Documentation commit:** [`f8b2fe8`](https://github.com/meridane/QimaTrade-MVP/commit/f8b2fe82b9f83383028ab9603efc43c6554dae6b) updated both registers with the QA251 implementation, the initial fixture-format failure, and the successful code-head validation.
- **QIMA CI #912:** [run 42347024564](https://github.com/meridane/QimaTrade-MVP/actions/runs/42347024564) completed successfully on documentation HEAD `f8b2fe8`. Playwright reported **309 passed (10.1 s), 0 failed**. npm installation, npm audit (0 findings at info/low/moderate/high/critical in this run), TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #866:** [run 42347024610](https://github.com/meridane/QimaTrade-MVP/actions/runs/42347024610) completed successfully.
- **Vercel:** the combined commit status on documentation HEAD `f8b2fe8` is `success`; the Preview deployment completed. This is not a production deployment. The earlier code HEAD `091f43e` had been rate-limited, but the final documentation HEAD received a successful Preview status.
- **Register integrity:** both complete Git blobs were re-read after publication and the QA251 sections were confirmed present. The canonical register is 1,286,867 characters and the QA185 addendum is 286,173 characters.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA252 — OAuth callback redirect allowlist over real HTTP — 7 November 2026

- **Baseline:** QA251 HEAD `5ea7d342b894a526a5b80d93d318a6409d899920`; QIMA CI #913 (run 42347196128) and QIMA CodeQL #867 (run 42347196223) completed successfully. The combined commit status reported Vercel `failure` with `upgradeToPro=build-rate-limit`; this is a provider quota result, not a GitHub Actions build failure.
- **Implementation:** added three Playwright HTTP regressions to `tests/e2e/auth-smoke.spec.ts`. Each invokes the real Next.js `/auth/callback` Route Handler with the isolated local Supabase Auth fixture and a correctly encoded PKCE verifier.
- **Absolute external destination:** `next=https://evil.example/phish` must complete the simulated exchange but redirect to the same-origin `/demands` fallback; the response Location must not contain the external host.
- **Protocol-relative destination:** `next=//evil.example/phish` must likewise resolve to the same-origin `/demands` fallback.
- **Safe local destination:** `next=/offers?search=steel&sort=recent#results` must preserve the same-origin path, query semantics and fragment after a successful simulated exchange.
- **Validation:** implementation committed; GitHub Actions and CodeQL results are pending for the QA252 head. No test outcome is claimed yet.
- **Scope limitation:** the browser-to-Next.js HTTP path is real, but Supabase Auth remains the local synthetic fixture. These tests verify redirect handling, not the behaviour of Google's OAuth service or a production vulnerability.
- **Safety:** no production secrets, Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting is touched.


## QA252 — same-origin assertion correction and final verification — 7 November 2026

- **Starting QA252 test head:** `50152f6f7fba73061928fc80149d92e826001491`. PR #26 remained open/draft, based on `main`, with 905 commits ahead, zero behind and 55 changed files.
- **Initial validation:** QIMA CI #914 [run 42351934706](https://github.com/meridane/QimaTrade-MVP/actions/runs/42351934706) failed in the browser job with **309 passed, 3 failed**. All three new real-HTTP OAuth redirect cases received a local Next.js Location origin of `http://localhost:3000`, while the assertions expected `http://127.0.0.1:3000`. npm installation/audit, TypeScript, Next.js build and isolated PostgreSQL integration/RLS job succeeded. QIMA CodeQL #868 [run 42351934699](https://github.com/meridane/QimaTrade-MVP/actions/runs/42351934699) completed successfully. This was a test-environment origin-alias mismatch, not evidence of an open-redirect vulnerability.
- **First assertion correction:** commit [`a00b0ad`](https://github.com/meridane/QimaTrade-MVP/commit/a00b0adf1351d849228d17f083dac20469cfaa9c) compared the Location origin to `response.url()`. QIMA CI #915 [run 42358728356](https://github.com/meridane/QimaTrade-MVP/actions/runs/42358728356) still failed the same three assertions: Playwright's request URL used the 127.0.0.1 loopback alias while the Route Handler generated an absolute Location using its canonical `localhost` origin. The TypeScript, audit, build and PostgreSQL/RLS checks succeeded; QIMA CodeQL #869 [run 42358728478](https://github.com/meridane/QimaTrade-MVP/actions/runs/42358728478) succeeded.
- **Final correction:** commit [`3017c11`](https://github.com/meridane/QimaTrade-MVP/commit/3017c11f2a739e4e0011f468374308bb451ce6c0) defines the test environment's canonical Next.js origin as `http://localhost:3000` and checks all three Location origins against it. No application code changed. The external absolute and protocol-relative destinations must still fall back to same-origin `/demands`; the safe local `/offers` path, query and fragment remain preserved. The assertion is deliberately tied to the local CI Route Handler origin; it is not a claim about arbitrary production host configuration.
- **Final CI:** QIMA CI #916 [run 42358898406](https://github.com/meridane/QimaTrade-MVP/actions/runs/42358898406) completed successfully on code HEAD `3017c11`: **312 passed (8.0 s), 0 failed**. npm installation, npm audit (0 total findings in this run), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **CodeQL:** QIMA CodeQL #870 [run 42358898436](https://github.com/meridane/QimaTrade-MVP/actions/runs/42358898436) completed successfully.
- **Vercel:** the combined status on code HEAD `3017c11` is `success`; the Preview deployment completed at [the QA252 Preview](https://vercel.com/bmk1/qimatrade-mvp/79YLvnjCm9y49nvr9grbb1bLSKwb). This is not a production deployment.
- **Scope:** QA252 covers the real Next.js Route Handler over HTTP with a local synthetic Supabase Auth fixture. It rejects external redirect destinations in this isolated test environment, but does not contact Google or production Supabase and does not establish a production vulnerability.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA253 — OAuth redirect URL normalization over real HTTP — 7 November 2026

- **Baseline:** PR #26 was open and draft on fix/create-offer-status-contract, based on main, at HEAD b4d91bde2ea60366be487e71d70a2ed594bbb859 (909 commits ahead, zero behind, 55 changed files). QIMA CI #917 [run 42359029194](https://github.com/meridane/QimaTrade-MVP/actions/runs/42359029194) and QIMA CodeQL #871 [run 42359029219](https://github.com/meridane/QimaTrade-MVP/actions/runs/42359029219) both completed successfully; the baseline Vercel Preview status was successful.
- **Implementation:** added four Playwright HTTP regressions to tests/e2e/auth-smoke.spec.ts, using the real Next.js /auth/callback Route Handler and the isolated local Supabase Auth fixture. No application code was changed because the existing getSafeRedirectUrl() origin check already rejects candidates whose WHATWG URL parsing changes the origin.
- **Raw backslash normalization:** next=/\evil.example/phish is interpreted by the WHATWG URL parser as an external authority; the callback must return the same-origin /demands fallback.
- **Control-character normalization:** a CR/LF-prefixed network-path destination is stripped/normalized by URL parsing; the callback must also return same-origin /demands.
- **Percent-encoded backslashes:** /%5C%5Cevil.example/phish remains an encoded path on the application origin. The test explicitly verifies same-origin path preservation rather than classifying this encoding as an external redirect.
- **Unicode and query semantics:** a local /offers/雪 destination preserves its Unicode path, duplicate tag values, an empty query value, an encoded ampersand within q, and a Unicode fragment after URL serialization.
- **Code commit:** [48bd8ed](https://github.com/meridane/QimaTrade-MVP/commit/48bd8ed7f53ebb099482ee7354da6f14308398bf) added the four tests. A local Node WHATWG URL check confirmed the expected parsing cases before CI.
- **QIMA CI #918:** [run 42359402650](https://github.com/meridane/QimaTrade-MVP/actions/runs/42359402650) completed successfully on code HEAD 48bd8ed: **316 Playwright tests passed, 0 failed**. npm installation, npm audit at the configured high threshold, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS, and participant self-enrollment RLS all succeeded. PostgreSQL emitted expected fixture errors for forced-failure/idempotency regression cases; the integration job completed successfully.
- **CodeQL:** QIMA CodeQL #872 [run 42359402624](https://github.com/meridane/QimaTrade-MVP/actions/runs/42359402624) completed successfully.
- **Vercel:** combined status on code HEAD 48bd8ed reported failure with upgradeToPro=build-rate-limit. This is the provider's Preview build quota, not a failed Next.js CI build. No attempt was made to bypass the quota.
- **Scope limitation:** these are real HTTP tests of the local Next.js Route Handler with a synthetic local Supabase Auth server. They verify WHATWG URL normalization and redirect-origin behaviour in CI; they do not contact Google or production Supabase and do not establish a production vulnerability.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA253 — final documentation-head verification — 7 November 2026

- **Documentation HEAD:** both registers contain the QA253 implementation and its code-head results; the documentation commit is 7fb2e498be1c722209546ef9881b33eab930fb42.
- **QIMA CI #919:** [run 42359553350](https://github.com/meridane/QimaTrade-MVP/actions/runs/42359553350) completed successfully on documentation HEAD 7fb2e49: **316 Playwright tests passed, 0 failed**. npm installation, npm audit at the configured high threshold, TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #873:** [run 42359553356](https://github.com/meridane/QimaTrade-MVP/actions/runs/42359553356) completed successfully.
- **PostgreSQL log interpretation:** the job log contains expected test-fixture errors for forced failure recovery and IDEMPOTENCY_KEY_REUSE cases; the SQL regression job and overall workflow concluded successfully. These are asserted negative paths, not workflow failures.
- **Vercel:** combined status on documentation HEAD 7fb2e49 reports failure with upgradeToPro=build-rate-limit. This is a Preview-provider quota response; the GitHub Actions Next.js build and browser suite succeeded. No quota bypass or production deployment was attempted.
- **Register integrity:** the full canonical Git blob and the complete QA185 addendum were re-read after publication; the QA253 sections and final verification entries were present.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA254 — OAuth callback origin under forged authority headers — 7 November 2026

- **Starting PR state:** PR #26 open/draft; branch `fix/create-offer-status-contract`; head `14065a8`; base `main`; 914 commits ahead, 0 behind, 55 changed files; no reviews or inline threads. Baseline CI #920 and CodeQL #874 succeeded; Vercel was rate-limited on the baseline.
- **Work branch:** `work/qa254-oauth-origin-forwarded-host-20261107-1918`, created from the exact baseline head.
- **Files:** only `tests/e2e/auth-smoke.spec.ts` changed in the code commit. Added a helper to issue the real callback request with selected authority headers, then two tests: forged `Host: evil.example` and forged `X-Forwarded-Host: evil.example`. Both use the existing valid PKCE fixture and expect HTTP 307, origin `http://localhost:3000`, path `/offers`, and no external host in Location. No application implementation changed.
- **Framework basis:** lockfile resolves Next.js 15.5.28. The Playwright webServer command starts `next start --hostname 127.0.0.1`. Inspection of Next.js v15.5.28 `attachRequestMeta()` shows that the configured fetch hostname/port determines the initial URL when available; Host is only consulted in the alternate trustHostHeader branch. X-Forwarded-Host is not used to construct the initial URL in this configured-host path. Source: [next-server.ts v15.5.28](https://github.com/vercel/next.js/blob/v15.5.28/packages/next/src/server/next-server.ts), [base-server.ts v15.5.28](https://github.com/vercel/next.js/blob/v15.5.28/packages/next/src/server/base-server.ts).
- **QIMA CI #921:** [run 42363577714](https://github.com/meridane/QimaTrade-MVP/actions/runs/42363577714) SUCCESS. **318/318 Playwright tests passed (7.0 s), zero failures.** npm ci, npm audit (critical 0, high 0, moderate 0, low 0, info 0), TypeScript, Next.js build, Chromium, PostgreSQL CREATE_OFFER integration/concurrency/idempotency, legacy messages RLS and participant self-enrollment RLS all passed.
- **QIMA CodeQL #875:** [run 42363577711](https://github.com/meridane/QimaTrade-MVP/actions/runs/42363577711) SUCCESS; no new alerts in code changed by this PR.
- **Vercel Preview:** SUCCESS on code head `3f80ba9`, deployment [EDyZD2mL6xj5qBRLLN71d5pBoXPv](https://vercel.com/bmk1/qimatrade-mvp/EDyZD2mL6xj5qBRLLN71d5pBoXPv). Preview only; no production deploy.
- **Limitations:** test covers the self-hosted Next.js server configured with explicit hostname/port and a synthetic local Supabase Auth server. It does not prove how Vercel's edge sanitizes Host/X-Forwarded-Host, does not cover X-Forwarded-Proto, and does not contact Google or production Supabase. No production vulnerability is inferred. The trusted proxy/origin configuration remains to be checked independently.
- **Workflow filtering:** although `.github/workflows/ci.yml` and `.github/workflows/codeql.yml` declare `paths-ignore: docs/**`, the cumulative PR diff still contains `tests/e2e/auth-smoke.spec.ts`; therefore the docs commit also triggered CI #922 and CodeQL #876, both of which succeeded.
- **Safety:** no Supabase production data, migrations, RLS policies, production settings, production deployment, PR merge or branch-protection change.

## QA254 — final documentation-head verification — 7 November 2026

- **Documentation HEAD:** QA254 tests and both complete register updates are present; this verification is recorded in the following commit.
- **QIMA CI #922:** [run 42363769870](https://github.com/meridane/QimaTrade-MVP/actions/runs/42363769870) completed successfully on documentation head `f0bf1d6`: **318 Playwright tests passed in 7.2 seconds, 0 failed**. npm installation, npm audit (0 info/low/moderate/high/critical findings), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #876:** [run 42363769889](https://github.com/meridane/QimaTrade-MVP/actions/runs/42363769889) completed successfully; CodeQL reported no new alerts in code changed by the PR.
- **Vercel:** Vercel Preview on documentation head `f0bf1d6` completed successfully at [deployment 8EZmJ4JvbHAr4rNP7VvFgyNn17wu](https://vercel.com/bmk1/qimatrade-mvp/8EZmJ4JvbHAr4rNP7VvFgyNn17wu). This is a Preview only, not a production deployment.
- **Vercel Preview Comments:** success; zero unresolved feedback.
- **Workflow filtering clarification:** the QIMA CI and CodeQL workflows declare `paths-ignore: docs/**`, but GitHub evaluates the cumulative PR diff. Because PR #26 still contains the QA254 test change in `tests/e2e/auth-smoke.spec.ts`, the documentation commit also triggered CI #922 and CodeQL #876. The earlier wording that implied these workflows would be skipped for this docs commit has been corrected.
- **Register integrity:** both complete register blobs were fetched before the update, updated without truncation, and re-read after publication; QA254 and this final verification entry are present.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.


## QA255 — X-Forwarded-Proto handling in OAuth callback — 7 November 2026

- **Baseline:** PR #26 was open/draft and mergeable on `fix/create-offer-status-contract`, based on `main` at `0d35c13db81019867fe9929420b0a6916285fbf6`, head `23144fe4a3cee0fdb7d0c8e5732485a42e20908a`, 917 commits ahead, zero behind and 55 changed files. No submitted reviews or inline threads were present. Baseline QIMA CI #923 [run 42363915817](https://github.com/meridane/QimaTrade-MVP/actions/runs/42363915817) and CodeQL #877 [run 42363915814](https://github.com/meridane/QimaTrade-MVP/actions/runs/42363915814) succeeded. The baseline Vercel status was rate-limited with `upgradeToPro=build-rate-limit`.
- **Work branch:** `work/qa255-x-forwarded-proto-contract-20261107-2039`, created from the exact baseline head. The test commit was fast-forwarded to the PR branch with an expected-SHA check; no force push was used.
- **Framework inspection:** the committed lockfile resolves Next.js `15.5.28` and Playwright `1.64.1`. `playwright.config.ts` starts the self-hosted server using `next start --hostname 127.0.0.1`. `next.config.ts` only sets `reactStrictMode: true`; it does not enable `experimental.trustHostHeader`. In the matching Next.js source, `NextNodeServer.attachRequestMeta()` selects the protocol using `req.headers['x-forwarded-proto']?.includes('https')` and builds the initial URL from the configured fetch hostname and port when present. Source: [Next.js v15.5.28 next-server.ts, lines 1921–1935](https://github.com/vercel/next.js/blob/v15.5.28/packages/next/src/server/next-server.ts).
- **Implementation:** added three HTTP regressions to `tests/e2e/auth-smoke.spec.ts`, exercising the real local Next.js `/auth/callback` Route Handler and the isolated local Supabase Auth fixture. No application code, dependency, workflow, SQL or migration changed.
- **Observed contract:** `X-Forwarded-Proto: https` produces an HTTPS absolute Location; `http` produces HTTP; `http, https` also produces HTTPS because the framework checks substring inclusion rather than parsing a single canonical token. All cases preserve the configured local host and the safe `/offers` path.
- **Code commit:** [`40953c8`](https://github.com/meridane/QimaTrade-MVP/commit/40953c826e15d9a07851a2428ce030b145c3e5a1) (`test(auth): characterize forwarded protocol in OAuth callback`). It changes only `tests/e2e/auth-smoke.spec.ts`.
- **QIMA CI #924:** [run 42369263269](https://github.com/meridane/QimaTrade-MVP/actions/runs/42369263269) completed successfully on code head `40953c8`: **321 Playwright tests passed in 7.5 seconds, 0 failed**. npm installation, npm audit (0 info/low/moderate/high/critical findings), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #878:** [run 42369263116](https://github.com/meridane/QimaTrade-MVP/actions/runs/42369263116) completed successfully.
- **Vercel Preview:** combined status on code head `40953c8` is successful; Preview deployment [3FBxK7zcyTqY2k5f2kBDnmLcGxuR](https://vercel.com/bmk1/qimatrade-mvp/3FBxK7zcyTqY2k5f2kBDnmLcGxuR) is not a production deployment.
- **Security interpretation and limitation:** the test demonstrates that this self-hosted Next.js 15.5.28 process uses the incoming forwarded-protocol header to select the scheme of its request URL. It does not exercise Vercel's edge, a custom production domain, or the deployed trusted-proxy chain; it does not contact Google or production Supabase. This is a framework/configuration characterization, not evidence of a confirmed production vulnerability. Before any application-level origin policy is changed, the deployed proxy must be shown to overwrite or strip client-supplied `X-Forwarded-Proto`; that deployment evidence is not available from this repository inspection, so no origin env var or trust rule was invented.
- **PR state after code commit:** compare reports 918 commits ahead of `main`, zero behind; 55 changed files. PR remains open and draft.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed. No real OAuth secret was used.


## QA255 — final documentation-head verification — 7 November 2026

- **Documentation commit:** [`d3be709`](https://github.com/meridane/QimaTrade-MVP/commit/d3be7094a8896dd5264ac1d184a54ab66387f499) updated both complete registers with the QA255 test contract and the code-head validation.
- **QIMA CI #925:** [run 42369439461](https://github.com/meridane/QimaTrade-MVP/actions/runs/42369439461) completed successfully on documentation head `d3be709`: **321 Playwright tests passed in 6.6 seconds, 0 failed**. npm ci, npm audit (0 info/low/moderate/high/critical findings), TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #879:** [run 42369439409](https://github.com/meridane/QimaTrade-MVP/actions/runs/42369439409) completed successfully.
- **Vercel Preview:** combined status on documentation head `d3be709` is successful at [Preview deployment 6vjrsZkNNoQgAhYjMJCVMmC6WqJP](https://vercel.com/bmk1/qimatrade-mvp/6vjrsZkNNoQgAhYjMJCVMmC6WqJP). Preview only; no production deployment.
- **Register integrity:** both complete Git blobs were re-read after publication; the QA255 implementation and final CI/CodeQL/Preview verification entries are present.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed.



## QA256 — malformed X-Forwarded-Proto characterization and Vercel trust-chain limitation — 7 November 2026

- **Baseline:** PR #26 was open, draft and mergeable on `fix/create-offer-status-contract`, based on `main` at `0d35c13db81019867fe9929420b0a6916285fbf6`, with HEAD `f922105852e994ed89839fad0cee5410f0d72dfc`, 920 commits ahead, zero behind and 55 changed files. No submitted reviews or inline review threads were present. Baseline QIMA CI #926 [run 42369565247](https://github.com/meridane/QimaTrade-MVP/actions/runs/42369565247) and CodeQL #880 [run 42369565248](https://github.com/meridane/QimaTrade-MVP/actions/runs/42369565248) completed successfully. The baseline Vercel Preview was READY.
- **Vercel read-only inspection:** project `qimatrade-mvp` is a Next.js project. Project metadata reports `live=false`; the attached-domain listing returned only the verified default domain `qimatrade-mvp.vercel.app`, with no custom domain in that response. The project routing-rule listing returned zero rules. Environment metadata lists `NEXT_PUBLIC_SITE_URL` for Preview and Production as a sensitive variable; its value was deliberately not decrypted or read. Supabase URL and anon-key values were likewise not read.
- **Preview deployment:** commit `dcf88cd85e5a319f5432b6b3fb303a99588572a7` produced a READY Git Preview from the work branch at [deployment DVFttZnV6LN2QcNCZUKexfSucGBZ](https://vercel.com/bmk1/qimatrade-mvp/DVFttZnV6LN2QcNCZUKexfSucGBZ). Its deployment metadata has `target=null` and a branch-specific Preview alias; no Production target or promotion was requested.
- **Vercel documentation review:** [Vercel request headers](https://vercel.com/docs/headers/request-headers) describes `x-forwarded-proto` as the forwarded server protocol. The same documentation explicitly states that Vercel overwrites `x-forwarded-for`, but does not make the equivalent overwrite guarantee for `x-forwarded-proto`. The overwrite behaviour of `x-forwarded-proto` therefore must not be inferred from the `x-forwarded-for` statement.
- **Access limitation:** the available Vercel deployment fetch accepts a URL but no arbitrary request headers. No connected HTTP action can send a caller-supplied `X-Forwarded-Proto` header to the protected Preview. Project/deployment metadata and standard Preview status cannot establish how the Vercel edge handles a forged forwarded-protocol header. A header-capable authenticated Preview request path or explicit Vercel proxy evidence is still required. No project setting, route rule, environment value, bypass secret, or deployment protection was changed to work around this limitation.
- **Supplementary regression:** added one Playwright test in `tests/e2e/auth-smoke.spec.ts` for `X-Forwarded-Proto: nothttps`. On the self-hosted Next.js `15.5.28` server, the pinned framework source uses `req.headers['x-forwarded-proto']?.includes('https')`; therefore the malformed token containing the substring `https` selects an HTTPS absolute Location. The test preserves the configured host and safe `/offers` path. Matching source: [Next.js v15.5.28 next-server.ts](https://github.com/vercel/next.js/blob/v15.5.28/packages/next/src/server/next-server.ts#L1915-L1935).
- **Code commit:** [`dcf88cd`](https://github.com/meridane/QimaTrade-MVP/commit/dcf88cd85e5a319f5432b6b3fb303a99588572a7) (`test(auth): characterize malformed forwarded protocol value`) adds 15 lines to `tests/e2e/auth-smoke.spec.ts`; no application code, dependency, workflow, SQL or migration changed.
- **QIMA CI #927:** [run 42372749186](https://github.com/meridane/QimaTrade-MVP/actions/runs/42372749186) completed successfully on code HEAD `dcf88cd`: **322 Playwright tests passed in 9.0 seconds, 0 failed**. npm installation, npm audit (0 info/low/moderate/high/critical findings in this run), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded. The SQL job log explicitly reports both synthetic RLS regression suites passed.
- **QIMA CodeQL #881:** [run 42372749192](https://github.com/meridane/QimaTrade-MVP/actions/runs/42372749192) completed successfully.
- **Vercel Preview:** the combined status for the same commit is success and the work-branch Preview is READY. This is a Preview only; no Production deployment occurred.
- **Security interpretation:** the `nothttps` result characterizes the self-hosted Next.js framework and does not demonstrate that a client can control the header through Vercel's deployed proxy. No production vulnerability is confirmed or inferred. No application-level origin policy was changed.
- **PR after code commit:** PR #26 remains open, draft and mergeable at `dcf88cd`, 921 commits ahead of `main`, zero behind and 55 changed files.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed. No real OAuth secret was used; no Vercel sensitive value was decrypted.



## QA256 — final documentation-head verification — 7 November 2026

- **Documentation HEAD:** both complete registers contain the QA256 local malformed-header characterization, the Vercel proxy trust-chain limitation, and the QA256 code-head validation recorded above.
- **QIMA CI #928:** [run 42372965527](https://github.com/meridane/QimaTrade-MVP/actions/runs/42372965527) completed successfully on documentation HEAD `4f0cbca`: **322 Playwright tests passed in 7.5 seconds, 0 failed**. npm installation, npm audit (0 info/low/moderate/high/critical findings in this run), TypeScript, Next.js production build, Chromium installation, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded.
- **QIMA CodeQL #882:** [run 42372965498](https://github.com/meridane/QimaTrade-MVP/actions/runs/42372965498) completed successfully.
- **Vercel Preview:** the documentation HEAD `4f0cbca` reached READY at [deployment 3KoifHZqcvBTUt78CpjeP2iRjdpL](https://vercel.com/bmk1/qimatrade-mvp/3KoifHZqcvBTUt78CpjeP2iRjdpL). This is a branch Preview only, with no Production target or promotion.
- **Register integrity:** the complete canonical register and QA185 addendum were fetched from their Git blobs after publication; QA256 and this final verification entry are present in both. No truncation or replacement of historical sections occurred.
- **Safety:** no Supabase production data, migration, RLS policy, production configuration, production deployment, PR merge, or branch-protection setting was changed. No Vercel sensitive environment value was decrypted.



## QA257 — branch migration inventory discrepancy and read-only remote-history limitation — 7 November 2026

- **Baseline:** PR #26 was open/draft and mergeable on `fix/create-offer-status-contract`, HEAD `58ec231cab47b0604b3d220d032b7d29701fd7c7`, based on `main`, 923 commits ahead, zero behind and 55 changed files. No submitted reviews or inline review threads were present. QIMA CI #929 [run 42373156727](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373156727) and CodeQL #883 [run 42373156648](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373156648) completed successfully before this documentation update.
- **Static Git inventory:** the GitHub contents listing for `supabase/migrations/` on the PR branch returned 18 SQL files. The dated 2026-10-27 migration reconciliation table contains 17 rows. The only branch file absent from that historical table is `20261028180000_fix_message_participant_authorization.sql`.
- **Migration inspection:** the missing row's file header explicitly labels it branch-only pending review and application to a non-production environment. The SQL replaces `public.is_message_participant`, revokes EXECUTE from `PUBLIC`, and grants EXECUTE to `authenticated`. This run did not execute or apply the SQL.
- **Documentation correction:** `docs/SUPABASE_MIGRATION_RECONCILIATION_REGISTER.md` now labels the 17-file table as the 2026-10-27 snapshot and adds the 18th branch file in a dated read-only refresh section. The historical 161-row remote migration count/latest version is explicitly marked as stale snapshot evidence, not a current count.
- **Remote-history blocker:** a read-only Supabase `list_migrations` request for project `QIMA` (`yyulzlnrfcbaxovzjbnh`) failed with PostgreSQL `28P01: password authentication failed for user "postgres"`. No password or other secret was requested or decrypted. Remote migration parity and current applied status of the new file remain unverified; no assumption is made that the migration is or is not applied remotely.
- **QIMA CI #929:** [run 42373156727](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373156727) completed successfully on baseline documentation HEAD `58ec231`: **322 Playwright tests passed in 5.1 seconds, 0 failed**. npm installation, npm audit (0 info/low/moderate/high/critical findings), TypeScript, Next.js production build, Chromium, isolated CREATE_OFFER PostgreSQL integration/concurrency/idempotency, legacy-messages RLS and participant self-enrollment RLS all succeeded. Both synthetic RLS regression scripts reported passed.
- **QIMA CodeQL #883:** [run 42373156648](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373156648) completed successfully.
- **Vercel:** the combined status for baseline docs HEAD `58ec231` returned `upgradeToPro=build-rate-limit`; no deployment for that final docs SHA was available in the deployment listing. The earlier code/first-doc HEADs had READY Preview deployments. This provider quota result is not a failed GitHub Actions Next.js build.
- **Scope and safety:** this is a repository inventory correction, not production migration reconciliation. No Supabase production data, migration, RLS policy, grant, project configuration, or secret was changed. No production deployment, PR merge, or branch-protection change occurred.



## QA258 — exercise the actual message-participant migration in disposable PostgreSQL — 7 November 2026

- **Baseline:** PR #26 was open, draft and mergeable at code HEAD `0775cd7dac16263238f2b8acfb076c3059ac53eb`, 925 commits ahead of `main`, zero behind and 57 changed files. No production files or migrations were changed by this test harness.
- **Test gap identified:** the existing `tests/sql/legacy-messages-rls-regression.sql` is a useful predicate-level synthetic regression, but it recreates the safe predicate in a test schema rather than executing the actual branch migration file. The branch inventory now has 18 SQL migration files; `20261028180000_fix_message_participant_authorization.sql` was the one missing from the historical 17-row inventory.
- **New disposable integration path:** `tests/sql/run-legacy-messages-rls-regression.sh` continues to run the existing synthetic suite, then creates a separate `qima_message_migration_test` database in the isolated GitHub Actions PostgreSQL 16 service, applies `supabase/migrations/20261028180000_fix_message_participant_authorization.sql` unchanged, runs assertions, and drops the temporary database with `DROP DATABASE ... WITH (FORCE)` on exit. The main `qima_test` database and Supabase projects are not used for this actual-migration test.
- **Fixture scope:** `tests/sql/legacy-messages-migration-fixture.sql` creates minimal `auth.uid()`, profiles, demands, offers and messages objects plus test roles in the fresh CI database. `tests/sql/legacy-messages-migration-assertions.sql` installs minimal synthetic INSERT/SELECT RLS policies after the migration is applied. These policies model the expected contract; they are not a copy of, or proof of parity with, the live Supabase policies.
- **Assertions against the actual migration function:** `authenticated` retains EXECUTE and `anon` does not inherit EXECUTE; unrelated user B cannot insert/read demand A; requester A cannot pair demand A with offer B or spoof sender B; provider C cannot cross from its offer on demand B into demand A; legitimate requester and provider paths remain available; requester messages without an offer remain allowed; provider visibility is limited to messages attached to its own offer.
- **QIMA CI #931:** [run 42373665792](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373665792) completed successfully. Browser suite: **322 passed in 10.1 seconds, 0 failed**. npm audit: **0 info, 0 low, 0 moderate, 0 high, 0 critical**. Installation, TypeScript, Next.js production build, Chromium and audit enforcement all succeeded.
- **PostgreSQL integration job:** the CREATE_OFFER base assertions, same-tenant concurrency and inter-tenant concurrency passed; the existing synthetic legacy-messages RLS suite passed; the new **actual migration disposable-db regression passed**; participant self-enrollment synthetic RLS regression passed. The temporary migration database was created and cleaned up by the runner.
- **QIMA CodeQL #885:** [run 42373665927](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373665927) completed successfully.
- **Vercel:** the current code HEAD's combined Vercel status returned `upgradeToPro=build-rate-limit`; no Preview deployment was created for this SHA. This is a provider quota result, not a GitHub Actions build failure.
- **Remote migration status remains unresolved:** the read-only Supabase `list_migrations` call failed with PostgreSQL `28P01` password authentication failure. The historical 161-version remote snapshot from 2026-10-27 is not current evidence. No claim is made that the new branch migration is applied remotely or that production migration parity is complete.
- **Safety:** the actual migration was executed only in the disposable GitHub Actions PostgreSQL service. No Supabase production data, migration, RLS policy, grant, schema, secret, production configuration or production deployment was changed. No PR merge or branch-protection change occurred.



## QA259 — fail-closed safety guard for the disposable migration runner — 7 November 2026

- **Baseline:** PR #26 remained open and draft. Before this work, branch HEAD was `d10572dc5387ac963bdb20517b2d93a789d12e3d`, 926 commits ahead of `main`, zero behind, with 57 changed files. The code-only update is `5d00940b056b2e01d46156ce5dfc629bbd65e6b1` (929 ahead, zero behind, 58 files).
- **Risk addressed:** `tests/sql/run-legacy-messages-rls-regression.sh` drops and recreates the fixed database `qima_message_migration_test`. Previously it required a `DATABASE_URL` but did not enforce that the URL referred to the dedicated local CI database before invoking `psql`.
- **Guard added:** before the first `psql` call, the runner now accepts only a PostgreSQL URI targeting `qima_test` on port 5432 with host `localhost`, `127.0.0.1`, or `[::1]`. Remote hosts, other database names, and query-bearing URIs are rejected with exit code 2. The connection string is never echoed, so credentials are not exposed.
- **Regression test:** new `tests/sql/test-legacy-messages-runner-guard.sh` runs the actual runner with a `psql` stub and verifies rejection of (1) a remote host, (2) a non-test database name, and (3) a query-bearing URL. The stub asserts that no `psql` process is invoked for rejected URLs. The script passed locally in the isolated shell check and in CI.
- **CI integration:** `.github/workflows/ci.yml` runs the guard test immediately before the destructive disposable migration runner. The real CI URL remains `postgresql://postgres:postgres@localhost:5432/qima_test`; the existing actual-migration test still runs in the isolated PostgreSQL 16 service.
- **QIMA CI #933:** [run 42378012790](https://github.com/meridane/QimaTrade-MVP/actions/runs/42378012790) completed successfully. Playwright: **322 passed in 5.7 seconds, 0 failed**. npm audit, TypeScript, Next.js production build, Chromium, CREATE_OFFER PostgreSQL integration/concurrency, unsafe-URL guard, actual message-participant migration disposable-db regression, and participant self-enrollment RLS checks all succeeded.
- **QIMA CodeQL #887:** [run 42378012776](https://github.com/meridane/QimaTrade-MVP/actions/runs/42378012776) completed successfully.
- **Vercel:** the combined status was `pending` when checked for the code HEAD; no Vercel deployment was initiated by this work. A Preview status is separate from the GitHub Actions build.
- **Scope:** this guard is intentionally specific to the destructive CI migration runner; it is not a global database connection policy. The read-only Supabase remote migration-history refresh remains blocked by the previously documented PostgreSQL `28P01` authentication failure. The historical 161-version snapshot remains stale; remote migration parity is still **UNRESOLVED**.
- **Safety:** rejected test URLs are stopped before any database connection. The positive migration path uses only the GitHub Actions PostgreSQL 16 service. No Supabase production connection, data, migration, RLS policy, grant, schema, secret, production configuration, deployment, PR merge, or branch-protection change was used or modified.



## QA260 — verify disposable migration database cleanup after a failed migration — 7 November 2026

- **Baseline:** PR #26 remains open, draft and mergeable on fix/create-offer-status-contract. The code change is in commits 0c696cdfc124558ff2f796d6793a6a57f76cea1c and 6ec40fd9eea2f4a7eb4648f8aca86452e16adb83. The documentation HEAD validated by CI #937 is 04a97f53b7f16912eafe763942bafc6e6e366e59.
- **Gap addressed:** QA259 verified that destructive operations are rejected before psql for unsafe database URLs, but did not exercise the EXIT trap when the disposable migration sequence fails after creating its temporary database.
- **Regression added:** tests/sql/test-legacy-messages-runner-guard.sh now injects a deterministic psql stub for a valid loopback qima_test URL. The stub allows the legacy regression script, pre-clean DROP, temporary database CREATE and migration fixture to proceed, then returns exit 42 for the actual branch migration command.
- **Assertions:** the expected command sequence is legacy regression → pre-clean DROP → CREATE → fixture → migration failure (42) → EXIT-trap DROP. The test requires the cleanup command to contain DROP DATABASE IF EXISTS qima_message_migration_test WITH (FORCE), and verifies that the runner preserves the original migration failure exit code 42.
- **Local validation:** bash tests/sql/test-legacy-messages-runner-guard.sh passed in an isolated temporary directory with a mocked runner/psql path. No PostgreSQL server was contacted by this local failure-path test.
- **QIMA CI #937:** [run 42384014441](https://github.com/meridane/QimaTrade-MVP/actions/runs/42384014441) completed successfully on documentation HEAD 04a97f5. Playwright: **322 passed in 6.8 seconds, 0 failed**. npm installation, npm audit, TypeScript, Next.js production build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, the unsafe-URL guard, the actual branch migration in a disposable PostgreSQL 16 database, and participant self-enrollment regression all passed.
- **QIMA CodeQL #891:** [run 42384014427](https://github.com/meridane/QimaTrade-MVP/actions/runs/42384014427) completed successfully.
- **Superseded runs:** QIMA CI #935 on the first test commit and #936 on the intermediate code commit were cancelled when later commits updated the PR head. They are not reported as test failures. CodeQL #889, #890 and #891 completed successfully.
- **Vercel:** the combined status for documentation HEAD 04a97f5 reports the provider build-rate-limit failure. This is separate from the successful GitHub Actions build; no deployment was forced or promoted.
- **Scope and safety:** the failure is simulated by a local stub. This validates that the shell EXIT trap issues the cleanup command and preserves the original exit code; it does not prove recovery from a real PostgreSQL server crash or guarantee cleanup after a network outage. The actual migration integration test remains confined to the ephemeral GitHub Actions PostgreSQL service. No Supabase production connection, data, migration, RLS policy, grant, schema, secret, production deployment, PR merge, or branch-protection setting was used or modified.


## QA261 — cleanup failure reporting without masking the primary test result — 2026-11-08

- Updated the disposable migration runner to capture and report a failed EXIT-trap DROP attempt while preserving the original runner status.
- Added two mocked regression cases: migration failure 42 + cleanup failure 91 returns 42; successful migration + cleanup failure 91 returns 0. Both require the warning and exact command sequence.
- Shell syntax checks and a focused local shell harness passed. The full CI guard script passed in QIMA CI #939.
- QIMA CI #939 [run 42388526274](https://github.com/meridane/QimaTrade-MVP/actions/runs/42388526274): **322 Playwright tests passed, 0 failed**; typecheck, npm audit threshold, Next.js build, CREATE_OFFER PostgreSQL integration/concurrency, unsafe-URL guard, actual message-participant migration in disposable PostgreSQL, updated cleanup-failure guard, and participant self-enrollment regression all passed.
- QIMA CodeQL #893 [run 42388526180](https://github.com/meridane/QimaTrade-MVP/actions/runs/42388526180) completed successfully.
- Cleanup remains best-effort: the test proves warning/reporting and status preservation, not successful deletion during a real PostgreSQL outage. No production Supabase object or data was accessed or changed.


## QA262 — verify actual PostgreSQL removal of the disposable migration database — 8 November 2026

- **Baseline:** PR #26 was open and draft on `fix/create-offer-status-contract`, with HEAD `f4d2aaadda2ff539d71c7a7bcab52a2d7101ec9d`, 946 commits ahead of `main`, 0 behind, and 58 changed files. The PR had no submitted reviews or inline review threads. The previous CI #940 and CodeQL #894 were both successful; the Vercel status was a provider `build-rate-limit` failure.
- **Gap addressed:** QA260/QA261 covered EXIT-trap command sequencing and cleanup-failure reporting with a deterministic `psql` stub. They did not query a real PostgreSQL server after a successful runner execution to prove that the disposable migration database was actually absent.
- **Read-only assertion added:** `tests/sql/assert-legacy-migration-database-absent.sh` accepts only the dedicated loopback `qima_test` URI (localhost, 127.0.0.1 or [::1], port 5432; no URI query parameters), then queries `pg_database` for the exact name `qima_message_migration_test`. It exits 0 only when the count is 0, exits 1 when the database remains, propagates a `psql` inspection error, and exits 2 before connecting for an unsafe URL. It never prints `DATABASE_URL`.
- **Regression coverage:** `tests/sql/test-legacy-messages-runner-guard.sh` now tests the assertion script with a stub for (1) database absent → exit 0, (2) database still present → exit 1, (3) PostgreSQL query error → original exit 91, and (4) remote URL → exit 2 without invoking `psql`. The test also checks that the exact `pg_database` query is issued and that credentials are not printed.
- **Real-service integration:** `.github/workflows/ci.yml` now runs the read-only assertion immediately after `run-legacy-messages-rls-regression.sh` completes. This checks the PostgreSQL 16 GitHub Actions service after the runner's EXIT trap, rather than inferring cleanup from a mocked command sequence.
- **Local focused check:** an isolated shell harness for the assertion script passed: absent → 0, present → 1, `psql` error → 91, remote URL → 2. The mock was used only for assertion semantics; it did not substitute for the real CI database check.
- **QIMA CI #942:** [run 42390456541](https://github.com/meridane/QimaTrade-MVP/actions/runs/42390456541) completed successfully. Playwright: **322 passed in 6.9 seconds, 0 failed**. npm installation, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, unsafe-URL guard, actual message-participant migration in the disposable PostgreSQL 16 service, QA262 post-run assertion, and participant self-enrollment regression all passed.
- **Direct database evidence:** the PostgreSQL job log contains both `QA262 assertion regression passed: absent/present database, psql failure propagation, and remote URL rejection.` and `Verified against the live PostgreSQL service: qima_message_migration_test is absent after the migration runner EXIT trap.` The post-run verification step itself completed successfully.
- **QIMA CodeQL #895:** [run 42390456540](https://github.com/meridane/QimaTrade-MVP/actions/runs/42390456540) completed successfully. This is an analysis result only; no synthetic test is treated as proof of a production vulnerability or its absence.
- **Vercel:** the combined status for code HEAD `72beaf97e5b7e21032781d8b4b281ddb9cc08d7d` remains `failure` with `upgradeToPro=build-rate-limit`. This is separate from the successful GitHub Actions build. No Preview was forced and no deployment was promoted.
- **Scope and limit:** the real deletion assertion ran only against the ephemeral GitHub Actions PostgreSQL 16 service, using the dedicated `qima_test` database and a read-only query of `pg_database`. It proves the temporary database was absent after the successful runner path in this CI execution; it does not prove deletion during a real server outage or persistent permission failure. QA261's mocked failure-path status-preservation coverage remains complementary.
- **Outstanding blockers:** the read-only Supabase migration-history refresh remains blocked by PostgreSQL `28P01`; the historical remote count is not current evidence and migration parity remains unresolved. The CREATE_OFFER business ownership model linking a demand to the tenant allowed to respond remains a decision gate documented in `MKT-1.1_CREATE_OFFER_AUTHORIZATION_AUDIT.md`.
- **Safety:** no Supabase production connection, data, migration, schema, RLS policy, grant, secret, production configuration, or production deployment was used or modified. No PR merge or branch-protection change occurred.


## QA263 — verify disposable migration cleanup after a real PostgreSQL SQL failure — 8 November 2026

- **Baseline:** PR #26 remained open and draft on `fix/create-offer-status-contract`. QA262 had proved successful-path cleanup against the PostgreSQL 16 GitHub Actions service, while QA260/QA261 exercised migration and cleanup failures only with deterministic `psql` stubs.
- **Gap addressed:** the EXIT trap had not yet been exercised after PostgreSQL itself returned a real SQL execution error in the disposable migration database.
- **Regression added:** `tests/sql/test-legacy-messages-real-failure-cleanup.sh` invokes the existing destructive runner only after enforcing the same strict loopback `qima_test` URL guard. A temporary `psql` shim delegates every command to the real PostgreSQL client and replaces only the exact branch migration `-f` argument with a temporary SQL file containing `SELECT * FROM qa263_relation_that_must_not_exist;`. The shim records that the migration invocation was intercepted exactly once.
- **Failure assertions:** the real PostgreSQL service reports the expected missing-relation error and `psql` exit status 3. The runner's existing EXIT trap then executes its normal `DROP DATABASE ... WITH (FORCE)` cleanup. The regression invokes `assert-legacy-migration-database-absent.sh` afterward using the unmodified PATH/real `psql` client; its read-only `pg_database` query must confirm `qima_message_migration_test` is absent. The test fails if the injected migration is not reached exactly once, the expected SQL error is missing, exit 3 is not preserved, credentials appear in runner output, or the database remains.
- **CI integration:** `.github/workflows/ci.yml` runs the real SQL failure-path regression after the existing successful-path cleanup assertion and before participant self-enrollment checks.
- **Local validation:** `bash -n` passed for the new shell script. The local runtime had no PostgreSQL client/server, so no local real-database result is claimed; the real SQL failure-path execution was performed by the GitHub Actions PostgreSQL 16 service.
- **QIMA CI #944:** [run 42395947118](https://github.com/meridane/QimaTrade-MVP/actions/runs/42395947118) completed successfully. Playwright: **322 passed in 7.0 seconds, 0 failed**. npm install, dependency audit enforcement at the configured high threshold, TypeScript, Next.js build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, unsafe-URL guard, actual branch migration disposable-db regression, QA262 successful-path absence assertion, **QA263 real SQL failure and cleanup regression**, and participant self-enrollment regression all passed.
- **Direct PostgreSQL evidence:** the PostgreSQL job log contains `QA263 passed: PostgreSQL executed the injected SQL error (psql exit 3), the runner EXIT trap cleaned up the temporary database, and pg_database confirmed its absence.` The server log independently records the expected `relation "qa263_relation_that_must_not_exist" does not exist` error. The test then completed successfully.
- **QIMA CodeQL #897:** [run 42395947097](https://github.com/meridane/QimaTrade-MVP/actions/runs/42395947097) completed successfully. This is a static analysis result only; it is not evidence that a production vulnerability exists or is absent.
- **Vercel:** at the code-commit check, the combined Vercel status was still pending for Preview deployment `7Grsi4zie1ACrwGospbYwBgRcevv`; no Preview-ready result is claimed here and no production deployment was performed.
- **Scope and limit:** only the new CI regression script, its CI invocation, and documentation were added. The branch migration file itself was not changed or executed as the injected failing SQL; only its runner invocation was replaced in this isolated test. This proves the real PostgreSQL SQL-error path and EXIT-trap cleanup in the ephemeral GitHub Actions service, not behavior during a PostgreSQL server crash, network partition, or persistent DROP permission failure.
- **Safety:** the runner and assertion accept only the dedicated loopback `qima_test` URI. No Supabase production connection, data, migration, schema, RLS policy, grant, secret, production configuration, deployment, PR merge, or branch-protection setting was used or modified.


## QA264 — active PostgreSQL session termination by disposable database cleanup — 8 November 2026

- Added `tests/sql/test-legacy-messages-active-session-cleanup.sh`. It runs the existing guarded runner against the isolated PostgreSQL 16 CI service. After the migration assertions succeed, a temporary `psql` shim starts a second real client with `PGAPPNAME=qa264-held-session` and `SELECT pg_sleep(60)`, then confirms through `pg_stat_activity` that the backend is active before the runner exits.
- The runner's actual `DROP DATABASE ... WITH (FORCE)` EXIT trap must terminate the held backend. The test requires a non-zero client exit, PostgreSQL's administrator-termination FATAL message, and a subsequent read-only `pg_database` result proving `qima_message_migration_test` is absent. The test accepts only the loopback `qima_test` URL and checks output for credential leakage.
- QIMA CI #946 [run 42401850431](https://github.com/meridane/QimaTrade-MVP/actions/runs/42401850431) succeeded. Playwright: **322 passed in 7.9 seconds, 0 failed**. TypeScript, Next.js build, npm audit (0 findings at every severity), CREATE_OFFER PostgreSQL integration/concurrency, unsafe URL guard, actual branch migration, QA262, QA263, QA264, and participant self-enrollment all passed. The PostgreSQL job log confirms the active session was terminated and the temporary database was absent. CodeQL #899 [run 42401850439](https://github.com/meridane/QimaTrade-MVP/actions/runs/42401850439) succeeded.
- Vercel's combined status check reported success for code HEAD `f23e57d`; the deployment detail endpoint still reported `BUILDING` with `target=null` at final inspection. No Preview-READY or Production deployment is claimed.
- **Limit:** this verifies `DROP DATABASE WITH (FORCE)` against an active session on the ephemeral CI PostgreSQL 16 service. It does not prove behavior during server/network failure or persistent DROP permission denial, and it does not establish Supabase production migration parity.
- No Supabase production data, migration, schema, RLS policy, grant, secret, production deployment, PR merge, or branch-protection setting was touched.


- **Final documentation-head verification:** QIMA CI #947 [run 42402085380](https://github.com/meridane/QimaTrade-MVP/actions/runs/42402085380) and CodeQL #900 [run 42402085468](https://github.com/meridane/QimaTrade-MVP/actions/runs/42402085468) both succeeded on HEAD `2d17d868182c44e7bd02d23c80f17c29828359dd`. Playwright: **322/322**; npm audit: zero findings; PostgreSQL QA264 active-session termination and database-absence assertion passed. Vercel's combined check was rate-limited on this documentation HEAD; no Production deployment occurred.


## QA265 — forced cleanup with multiple PostgreSQL sessions

- **Implementation:** added `tests/sql/test-legacy-messages-multiple-sessions-cleanup.sh` and a dedicated CI step in `.github/workflows/ci.yml`.
- **Real PostgreSQL setup:** after the existing migration assertions, the psql wrapper starts two independent clients (`qa265-active-one` and `qa265-active-two`) running `SELECT pg_sleep(60)`, plus a third client (`qa265-idle-in-transaction`) that executes `BEGIN; SELECT 1;` from a FIFO and remains open in `idle in transaction`.
- **Precondition:** the test polls `pg_stat_activity` and requires exactly one backend in each expected state before the migration runner exits and its `DROP DATABASE ... WITH (FORCE)` trap runs.
- **Termination evidence:** both active clients receive PostgreSQL's administrative-termination error. The idle client is deliberately sent a follow-up `SELECT 2` after a short delay because a psql process blocked on FIFO stdin does not necessarily observe an asynchronous socket close until it next interacts with the connection. The client then exits non-zero after detecting the closed connection.
- **Postcondition:** all three clients exit non-zero, the real read-only `pg_database` assertion confirms `qima_message_migration_test` is absent, and the output is checked for credential leakage.
- **Final validation:** QIMA CI #952 [run 42407664094](https://github.com/meridane/QimaTrade-MVP/actions/runs/42407664094) completed successfully. Playwright: **322 passed in 9.7 seconds, zero failed**; npm audit at the configured `high` threshold passed; TypeScript and Next.js build passed; the PostgreSQL job, including QA262, QA263, QA264 and QA265, passed. QIMA CodeQL #905 [run 42407664041](https://github.com/meridane/QimaTrade-MVP/actions/runs/42407664041) completed successfully.
- **Harness corrections recorded:** CI #949 failed because the initial test wrote a literal escaped `${DATABASE_URL-}` instead of reading the environment; fixed in `2741cea`. CI #950 then exposed a mismatched idle-writer readiness variable; fixed in `cd02484`. CI #951 showed that the idle psql process remained blocked on FIFO input after the server closed its socket; the post-cleanup wake-up query was added in `6428350`. These were test-harness failures, not application or production database findings. CodeQL #902, #903 and #904 completed successfully on the intermediate commits.
- **Limit:** this proves termination of two active and one idle-in-transaction session on the disposable PostgreSQL 16.15 GitHub Actions service. It does not prove behavior during server crash, network partition, prepared transactions, persistent permission failure, or on Supabase production.
- **Safety:** only a regression test, its CI invocation and documentation were changed. No Supabase production connection, data, migration, schema, RLS policy, grant, secret, production configuration, production deployment, PR merge, or branch-protection setting was used or modified.


## QA266 — prepared transaction blocks forced disposable-database cleanup — 8 November 2026

- **PostgreSQL rule under test:** PostgreSQL 16 documents that DROP DATABASE ... WITH (FORCE) attempts to terminate connections but does not terminate prepared transactions; the command fails while prepared transactions remain in the target database. See [PostgreSQL 16 DROP DATABASE](https://www.postgresql.org/docs/16/sql-dropdatabase.html).
- **CI-only configuration:** immediately before QA266, the GitHub Actions PostgreSQL 16 service container is configured with ALTER SYSTEM SET max_prepared_transactions = '10' and restarted. The step verifies the setting through the dedicated loopback qima_test connection. This change exists only in the ephemeral CI service; no Supabase project or persistent environment is configured.
- **Regression added:** tests/sql/test-legacy-messages-prepared-transaction-cleanup.sh delegates normal runner operations to the real psql client. After the actual branch migration and its assertions succeed in qima_message_migration_test, the wrapper creates a marker table, inserts a row in a transaction, and executes PREPARE TRANSACTION 'qa266_prepared_cleanup_blocker'.
- **Runner behavior:** the existing EXIT trap attempts DROP DATABASE IF EXISTS qima_message_migration_test WITH (FORCE). PostgreSQL refuses the drop. The runner emits its best-effort cleanup warning and preserves the successful migration/test exit status; it does not claim that the database was removed.
- **Blocker assertions:** the test requires exactly one matching row in pg_prepared_xacts, confirms the database remains present in pg_database, and verifies that the read-only database-absence assertion fails closed. A direct DROP attempt captures PostgreSQL's error: database "qima_message_migration_test" is being used by prepared transactions, with one prepared transaction in the database.
- **Explicit disposable cleanup:** a separate psql session executes ROLLBACK PREPARED 'qa266_prepared_cleanup_blocker'; the test then drops only the disposable database, requires zero matching prepared transactions, and reruns the read-only pg_database assertion to confirm absence. PostgreSQL documents that ROLLBACK PREPARED can be issued from any session and that prepared transactions are visible in pg_prepared_xacts; see [PostgreSQL 16 PREPARE TRANSACTION](https://www.postgresql.org/docs/16/sql-prepare-transaction.html).
- **CI integration:** .github/workflows/ci.yml adds an isolated setup step for the ephemeral service and runs QA266 after QA265. QIMA CI #954 [run 42410428830](https://github.com/meridane/QimaTrade-MVP/actions/runs/42410428830) completed successfully. The PostgreSQL job log records the prepared-transaction blocker, the expected failed DROP attempts, ROLLBACK PREPARED, the explicit DROP, and the final QA266 success message. The browser suite passed **322/322 in 9.4 seconds**; npm installation, the configured high-severity audit gate, TypeScript, Next.js build, Chromium, CREATE_OFFER PostgreSQL integration/concurrency, QA259–QA266 cleanup regressions, and participant self-enrollment regression all passed. QIMA CodeQL #907 [run 42410428833](https://github.com/meridane/QimaTrade-MVP/actions/runs/42410428833) completed successfully. The Vercel status check on this code HEAD reported success; no Production deployment was performed.
- **Limits:** this verifies the documented prepared-transaction blocker and the runner's honest best-effort behavior on the ephemeral PostgreSQL 16.15 GitHub Actions service. It does not establish production database behavior, remote Supabase migration parity, server-crash recovery, network-partition recovery, or persistent permission recovery. Prepared transactions should not be left unresolved; PostgreSQL warns that they retain locks and can interfere with vacuum, and recommends leaving the feature disabled when no transaction manager is configured.
- **Safety:** only the new regression script, its CI invocation/configuration, and documentation were changed. The actual branch migration file was executed only in the disposable CI database and was not modified. No Supabase production connection, data, migration history, schema, RLS policy, grant, secret, production configuration, Production deployment, PR merge, or branch-protection setting was used or modified.

## QA267 — restore the prepared-transaction setting after QA266 — 8 November 2026

- **Gap addressed:** QA266 temporarily enables PostgreSQL prepared transactions with `ALTER SYSTEM SET max_prepared_transactions = '10'` in the ephemeral GitHub Actions PostgreSQL 16 service. Before QA267, the workflow did not explicitly remove that CI-only override or verify that the service returned to its initial setting.
- **Baseline and setup:** the workflow now reads `SHOW max_prepared_transactions` before changing anything and requires the pristine CI-service baseline to be `0`. It writes `baseline=0` and `restore_required=true` to the setup step outputs before issuing the ALTER SYSTEM change, so the later cleanup step knows whether a change may have been made even if setup/restart subsequently fails.
- **Always-run restoration:** immediately after QA266, a step with `if: always()` invokes `tests/sql/restore-prepared-transactions-config.sh`. If setup did not record a change, the script is a no-op. Otherwise it validates the dedicated loopback `qima_test` URL and captured baseline, requires exactly one PostgreSQL 16 service container, waits for the service to be reachable, executes `ALTER SYSTEM RESET max_prepared_transactions`, restarts the disposable container, and waits for readiness again.
- **Postconditions:** the script requires `SHOW max_prepared_transactions` to equal the captured baseline (`0`), the QA266 GID `qa266_prepared_cleanup_blocker` to be absent from `pg_prepared_xacts`, and `qima_message_migration_test` to be absent from `pg_database`. A remaining prepared transaction/database, ambiguous container selection, unexpected baseline, unavailable service, or reset/restart failure fails the CI step rather than being reported as restored.
- **Mocked guard regression:** `tests/sql/test-prepared-transactions-config-restore.sh` verifies reset/restart/verification ordering, the no-op path when no change was recorded, rejection of remote URLs and unapproved baselines before external commands, rejection of ambiguous container selection, and failure when QA266 resources remain. These stubs test shell control flow only; the actual restoration is separately executed against the live ephemeral PostgreSQL service in CI.
- **Real CI evidence:** QIMA CI #959 [run 42416615766](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416615766) completed successfully on code HEAD `97e20a66e9cbba884c408c1698c948b1e9321195`. Both jobs passed: TypeScript, npm audit at the configured `high` threshold, Next.js build, Chromium, **322/322 Playwright tests (5.4 seconds)**, CREATE_OFFER PostgreSQL integration/concurrency, QA259–QA267 cleanup regressions, and participant self-enrollment RLS. The PostgreSQL job log explicitly records `ALTER SYSTEM` followed by: `QA267 passed: ALTER SYSTEM RESET was followed by a PostgreSQL restart; max_prepared_transactions returned to baseline 0, and no QA266 prepared transaction or disposable database remained.`
- **Static analysis and superseded run:** QIMA CodeQL #912 [run 42416614249](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416614249) completed successfully. Earlier CI #958 [run 42416545077](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416545077) was cancelled when the final harness correction produced a newer HEAD; it is superseded, not a failed test run. CodeQL #911 [run 42416545083](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416545083) also completed successfully on the preceding code HEAD.
- **Vercel:** the combined status on QA267 code HEAD reports the existing `upgradeToPro=build-rate-limit` failure. GitHub Actions build/tests are successful, but no fresh Preview-READY result is asserted and no deployment was forced.
- **Limits:** this verifies restoration of the setting and cleanup of QA266 resources on the disposable GitHub Actions PostgreSQL 16 service only. It does not establish behavior on Supabase or any persistent/production database, and it does not test recovery from Docker daemon failure or a PostgreSQL process that cannot be restarted.
- **Safety:** no Supabase production connection, data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection change was used or modified. The ALTER SYSTEM SET/RESET operations and both PostgreSQL restarts were confined to the ephemeral CI service.


## QA268 — explicit failure handling for prepared-configuration restoration — 8 November 2026

- **Gap addressed:** the QA267 restoration script used `set -e` to stop when `ALTER SYSTEM RESET max_prepared_transactions` or `docker restart` failed, but it did not emit a step-specific diagnostic or make the unconfirmed restoration state explicit. QA268 adds explicit failure branches for both commands.
- **RESET failure path:** when the `docker exec ... ALTER SYSTEM RESET` command fails, the script captures and preserves its exit status, emits an Actions error stating that configuration restoration is not confirmed, and exits before attempting a container restart or any postcondition query.
- **Restart failure path:** when `docker restart` fails, the script captures and preserves its exit status, emits an Actions error stating that restored configuration is not confirmed, and exits before readiness polling or querying `SHOW max_prepared_transactions`. The script never prints the QA267 success message on either failure path.
- **Regression coverage:** `tests/sql/test-prepared-transactions-config-restore.sh` injects a RESET failure with exit 42 and a restart failure with exit 43. It asserts the exact diagnostics, the original exit codes, and the command sequences: RESET failure must not restart; restart failure must not proceed to readiness or verification. Existing no-op, loopback URL, single-container, baseline, and residual-resource tests remain active.
- **Scope of evidence:** the two failure paths use deterministic command stubs to validate shell control flow; they do not simulate or prove a real Docker daemon or PostgreSQL failure. The successful restoration path is separately exercised against the disposable PostgreSQL 16 service in GitHub Actions.
- **CI evidence:** QIMA CI #962 [run 42422099481](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422099481) completed successfully on code HEAD `fd291dd9c88a890d4e82fa52bf0450f68dbc0a70`. Both jobs passed: dependency installation, npm audit at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, **322/322 Playwright tests (8.1 seconds)**, CREATE_OFFER PostgreSQL integration/concurrency, legacy RLS migration regression, QA259–QA267 cleanup regressions, QA268 restoration-failure guard tests, and participant self-enrollment regression. The PostgreSQL job log records the QA268 regression success message and the live QA267 restoration success message; no job step failed.
- **Static analysis and Preview:** QIMA CodeQL #915 [run 42422099457](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422099457) completed successfully. The combined Vercel status on the code HEAD was `success`; the Vercel Preview Comments check also completed successfully. This is not a Production deployment.
- **Limits:** this confirms explicit shell handling for simulated RESET/restart command failures and a successful restoration on the ephemeral CI PostgreSQL service. It does not prove recovery from a Docker daemon outage, a PostgreSQL process that cannot restart, a network partition, or any persistent/production database condition. No vulnerability is inferred from these synthetic failure tests.
- **Safety:** only the two CI restoration scripts and documentation were changed. No Supabase production connection, data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was used or modified. All real `ALTER SYSTEM` and restart operations remained confined to the ephemeral GitHub Actions PostgreSQL service.

- **Documentation-only HEAD status:** the QA268 register-only follow-up commit `d737850886dee7885b718c782d31409f6e34253b` changed only `docs/**`. Both `.github/workflows/ci.yml` and `.github/workflows/codeql.yml` declare `paths-ignore: docs/**`, and no new QIMA CI or CodeQL run was created for that docs-only commit. The combined Vercel status on that docs-only HEAD returned `failure` with `upgradeToPro=build-rate-limit`; this is the deployment quota status, not a failed GitHub Actions build. The QA268 code HEAD remains validated by CI #962 and CodeQL #915 above.

- **Superseded initial CI attempt:** QIMA CI #961 [run 42422067759](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422067759) on initial commit `38ae4cf5388daa1a205a7bce6c3fbe2b2d8611bf` was cancelled after review found the newly added shell test's `printf` newline escapes needed correction. The assertion was fixed in `fd291dd9c88a890d4e82fa52bf0450f68dbc0a70`; CI #961 is superseded/cancelled, not a failed test result. CodeQL #914 [run 42422067732](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422067732) completed successfully on the initial commit; final corrected code was validated by CI #962 and CodeQL #915 above.


## QA269 — post-restart readiness and effective-configuration rejection (8 November 2026, 08:33 KST)

- **Validated PR:** [#26](https://github.com/meridane/QimaTrade-MVP/pull/26), base `main`, head branch `fix/create-offer-status-contract`.
- **Validated code HEAD:** `9bcfa4319ec737351add4d80d870def604ddc083` (`test(postgres): cover QA269 restoration verification failures`).
- **Scope:** regression coverage added only to `tests/sql/test-prepared-transactions-config-restore.sh`. The restoration runner and CI workflow were not changed.
- **QA269-A — PostgreSQL unavailable after restart:** the deterministic `pg_isready` stub succeeds for the pre-reset probe and fails for all 60 post-restart probes. A no-op `sleep` stub keeps the bounded retry test fast. The script exits nonzero, emits the existing “did not return to max_prepared_transactions=0” error, and performs neither configuration nor residual-resource success checks.
- **QA269-B — effective value remains wrong:** the readiness stub stays successful, but the `SHOW max_prepared_transactions` stub returns `10` for all 60 verification attempts instead of the captured baseline `0`. The script exits nonzero, reports that the baseline was not restored, and does not inspect residual resources or print the QA267 success message.
- **Deterministic assertions:** each case confirms 61 readiness probes (one pre-reset plus 60 post-restart), 60 bounded retry sleeps, and the expected number of configuration queries. These are mocked failure-path tests; they do not simulate an actual PostgreSQL outage or prove a production configuration defect.
- **QIMA CI #966:** [run 42425895151](https://github.com/meridane/QimaTrade-MVP/actions/runs/42425895151) — **SUCCESS**. TypeScript, dependency audit, Next.js build, Chromium and **322/322 Playwright tests** passed. The npm audit report recorded 0 info, 0 low, 0 moderate, 0 high and 0 critical findings. The PostgreSQL integration job also succeeded, including the existing QA259–QA268 checks, the QA269 restoration guard suite, and the real QA267 restoration on the ephemeral PostgreSQL 16 service.
- **PostgreSQL log evidence:** the QA269 regression summary was emitted; the real restoration step then confirmed `ALTER SYSTEM RESET`, PostgreSQL restart, `max_prepared_transactions=0`, no remaining QA266 prepared transaction and no remaining disposable database.
- **QIMA CodeQL #919:** [run 42425895131](https://github.com/meridane/QimaTrade-MVP/actions/runs/42425895131) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this tested code HEAD. This is a Preview/check status only; no Production deployment was made.
- **Limits and interpretation:** QA269 proves fail-closed behavior for two deterministic mocked post-restart failure modes and bounded retries. QA267 separately proves successful restoration on the ephemeral CI PostgreSQL service. Neither synthetic negative case establishes a production outage, a confirmed vulnerability, or a production configuration problem.
- **Safety:** no Supabase production connection, data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was used or modified. The only code change was a CI regression test; real PostgreSQL configuration changes remained confined to the disposable GitHub Actions service.


## QA269 — final documentation-head status (8 November 2026, 08:36 KST)

- **Documentation HEAD:** `9b2dc7be78b4896893f9f26acf7e1149a24d9599`; the three QA269 register updates are documentation-only.
- **GitHub Actions:** no new QIMA CI or CodeQL run was created for this docs-only HEAD because both workflows ignore `docs/**`. The unchanged tested code parent `9bcfa4319ec737351add4d80d870def604ddc083` remains validated by QIMA CI #966 (**SUCCESS**) and CodeQL #919 (**SUCCESS**).
- **Vercel combined status on the documentation HEAD:** **FAILURE**, target `upgradeToPro=build-rate-limit`. This is a deployment quota status, not a GitHub Actions build failure. No Preview READY is claimed for this documentation HEAD and no Production deployment occurred.


## QA269 — correction: pull_request path-filter behavior and validation (8 November 2026, 08:40 KST)

- **Correction to the preceding QA269 final documentation-head status:** the statement that no new QIMA CI or CodeQL run was created because the workflows declare `paths-ignore: docs/**` was inaccurate. For `pull_request` events, GitHub evaluates the aggregate PR changed-file set. PR #26 still contains application, test and workflow changes outside `docs/**`, so documentation-only follow-up commits also triggered both workflows.
- **QIMA CI #968:** [run 42426113135](https://github.com/meridane/QimaTrade-MVP/actions/runs/42426113135) — **SUCCESS** on documentation HEAD `c87c9212fc281b6667367b4a1e29944cb3ff50e3`. Both jobs completed: TypeScript, npm audit, Next.js build, Chromium, **322/322 Playwright tests**, CREATE_OFFER PostgreSQL integration/concurrency, QA259–QA269 regression guards, real QA267 restoration and participant self-enrollment RLS. The npm audit JSON reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings.
- **QIMA CodeQL #921:** [run 42426113105](https://github.com/meridane/QimaTrade-MVP/actions/runs/42426113105) — **SUCCESS** on the same documentation HEAD.
- **Code unchanged:** the only difference between validated code HEAD `9bcfa4319ec737351add4d80d870def604ddc083` and `c87c9212fc281b6667367b4a1e29944cb3ff50e3` was the QA269 register documentation. The successful #968/#921 checks therefore cover the same code.
- **Follow-up behavior:** this correction is also documentation-only, but because the PR's aggregate diff still includes non-documentation paths, GitHub may start another pull-request CI and CodeQL run for the corrected documentation HEAD. The correction commit itself does not alter application or SQL code.
- **Vercel:** the combined status on `c87c9212fc281b6667367b4a1e29944cb3ff50e3` was **FAILURE** with `upgradeToPro=build-rate-limit`. This is the deployment quota status, not a GitHub Actions failure; no Preview READY is claimed for that HEAD and no Production deployment occurred.
- **Safety and interpretation:** QA269-A and QA269-B remain deterministic mocked failure-path tests, not proof of a real PostgreSQL outage or a confirmed vulnerability. QA267 separately verifies successful restoration on the ephemeral PostgreSQL 16 CI service. No Supabase production data, migration, schema, policy, grant, secret, persistent configuration, Production deployment, merge, or branch-protection setting was changed.


## QA270 — post-restart SHOW query failure propagation (8 November 2026)

- **Starting state:** the PR branch already contained QA270 when this run began. Compared with previously recorded HEAD `bd8aa29bad28f97ed17156979678121025b77fae`, the branch was three commits ahead; the QA270 commits were `ec597eadf9f92ea196d91fc598752fe6602c1b52` (test), `f053712cfac205b03ce9696122460eb47a334682` (test summary), and `24c8a67fabe1da553c70048f346bd63c5bc63c1b` (explicit runner error handling).
- **Scenario:** PostgreSQL readiness succeeds after restart, but the `SHOW max_prepared_transactions` query returns controlled psql exit 44.
- **Expected behavior:** the runner reports that the configuration read failed, preserves exit 44, stops before residual-resource queries, and never prints the QA267 restoration-success message.
- **Validation:** QIMA CI #971 [run 42431842941](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842941) — **SUCCESS**, both browser and PostgreSQL jobs completed. The PostgreSQL job log includes the prepared-transaction restoration regression summary with post-restart SHOW failure propagation and the real QA267 restoration confirmation. QIMA CodeQL #924 [run 42431842966](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842966) — **SUCCESS**.
- **Combined status on QA270 HEAD:** Vercel **SUCCESS**. This is a Preview/check status, not a Production deployment.
- **Interpretation:** the SHOW failure is injected by a deterministic psql stub. It validates shell error propagation only; it does not establish a real PostgreSQL outage or a vulnerability.
- **Safety:** no production Supabase connection, data, migration, schema, RLS policy, grant, secret, persistent configuration, Production deployment, merge, or branch-protection setting was used or modified.

## QA271 — explicit failure handling for postcondition queries (8 November 2026)

- **Gap addressed:** after the configuration is restored, the runner queries `pg_prepared_xacts` and `pg_database`. Previously, `set -e` stopped the script if either psql command failed, but there was no query-specific diagnostic or explicit preservation of the failing psql status.
- **Runner change:** `tests/sql/restore-prepared-transactions-config.sh` now handles each postcondition query in an explicit `if assignment; then / else` branch. It reports which verification failed, preserves the original psql exit status, and exits before the success message.
- **Regression coverage:** `tests/sql/test-prepared-transactions-config-restore.sh` now injects exit 45 for the prepared-transaction query and exit 46 for the disposable-database query. QA271-A asserts the database query is not attempted after the first failure. QA271-B asserts the second failure is reported. Both assert that the QA267 success message is absent.
- **Code commits:** `24c8a67fabe1da553c70048f346bd63c5bc63c1b` (runner) and `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e` (regression tests). Work branch: `work/qa271-postcondition-query-failure-guards-20261108-1000`; changes were fast-forwarded to PR #26.
- **Local focused check:** a standalone shell harness for the two guarded psql failure branches passed: prepared-query exit 45 and database-query exit 46 were preserved with their respective diagnostics. This focused check is not a substitute for repository CI.
- **GitHub Actions status at documentation time:** no pull-request workflow run was yet returned for code HEAD `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e`; QIMA CI and CodeQL results remain **pending/unavailable**, not assumed successful. The combined Vercel status on that HEAD was **FAILURE** with `upgradeToPro=build-rate-limit`, separate from GitHub Actions.
- **Safety and interpretation:** the new negative cases use command stubs and do not prove a production database failure or a confirmed vulnerability. No production Supabase data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, merge, or branch-protection setting was changed.



## QA271 — final validation status and current PR head (8 November 2026)

- **Final documentation candidate HEAD:** `237943d2d5e2efbfdba8364d718cb574a19c18dc`; validated code candidate immediately before the two documentation commits: `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e`.
- **Current PR branch:** `fix/create-offer-status-contract`; comparison with `main` reports 996 commits ahead and 0 behind. PR #26 remains open and draft, with 65 changed files, no reviews and no review threads.
- **QA270 last validated ancestor:** code HEAD `f053712cfac205b03ce9696122460eb47a334682`; QIMA CI #971 [run 42431842941](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842941) — **SUCCESS**, including **322/322 Playwright tests**, successful PostgreSQL integration job, the QA270 SHOW-query failure regression summary, and the real QA267 restoration confirmation. CodeQL #924 [run 42431842966](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842966) — **SUCCESS**.
- **QA271 validation:** a focused local shell harness passed for both guarded psql postcondition failures (exit 45 for `pg_prepared_xacts`, exit 46 for `pg_database`). However, GitHub returned no QIMA CI or CodeQL workflow runs for QA271 code HEAD `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e` or the subsequent documentation HEAD. Therefore QA271 is **not yet CI-validated**; the successful QA270 runs must not be presented as covering QA271.
- **Combined status on QA271 documentation HEAD:** Vercel **FAILURE**, target `upgradeToPro=build-rate-limit`. This is separate from GitHub Actions and does not establish a Next.js build failure. No Preview READY is claimed for QA271 HEAD.
- **Canonical register retrieval limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` remains over the GitHub file-content connector's supported retrieval size; the connector returns its blob metadata but no body, including for line-range requests. It was not replaced or truncated. QA270/QA271 are recorded in this append-only companion register and in the migration reconciliation register.
- **Safety:** no production Supabase data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was changed.



## QA270–QA272 — prepared-transaction restoration verification and bounded retries (8 November 2026)

### QA270/QA271 validation correction

- The PR branch already contained QA270 and QA271 when this run began. The current PR HEAD at inspection was `d7dc90e03e0b05c4223a494903098bd84d0b90d6`; the QA271 code commit was `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e`.
- **QIMA CI #974:** [run 42432503677](https://github.com/meridane/QimaTrade-MVP/actions/runs/42432503677) — **SUCCESS** on the PR documentation HEAD. Both CI jobs completed; the browser job reported **322/322 Playwright tests**, and the PostgreSQL job reported the prepared-transaction restoration regression and real QA267 restoration as successful.
- **QIMA CodeQL #927:** [run 42432503657](https://github.com/meridane/QimaTrade-MVP/actions/runs/42432503657) — **SUCCESS**.
- This later validation supersedes the earlier QA271 note that said CI/CodeQL were unavailable. QA271 is now validated by the runs above; no application or SQL migration code changed between its code commit and the validated documentation HEAD.

### QA272 — transient readiness and configuration convergence

- **Scope:** extended `tests/sql/test-prepared-transactions-config-restore.sh`; the existing CI workflow already invokes this test, so no workflow file change was needed.
- **QA272-A:** the mocked `pg_isready` fails on the first two pre-reset probes, then succeeds. The runner must retry and continue through RESET, restart, configuration verification and resource postconditions.
- **QA272-B:** the initial pre-reset readiness probe succeeds; the first two post-restart readiness probes fail, then a later probe succeeds. The runner must recover within its bounded retry loop.
- **QA272-C:** the post-restart `SHOW max_prepared_transactions` mock returns the temporary value `10` for two polls, then the captured baseline `0`. The runner must retry and only verify residual resources after observing the baseline.
- The tests assert exact event ordering, readiness/show call counts, retry sleeps, and the QA267 success message after convergence.
- **Interpretation:** QA272's transient failure/recovery cases use deterministic command stubs. They validate retry behavior; they are not evidence of a real PostgreSQL outage or a confirmed vulnerability. The separate QA267 step continues to exercise `ALTER SYSTEM RESET`, PostgreSQL restart, and baseline/resource verification against the ephemeral PostgreSQL 16 service.

### QA272 implementation and validation

- Work branch: `work/qa272-transient-postgres-readiness-recovery-20261108-1044`.
- Commits: `94c4283a2e6d757498a66b095e0a0171030d4943` (retry cases), `4b3543717062e0805c6e57df4d8fb10de567aecc` (correct event-format escape sequences), and `e56da2f80b2d4a37182b500c68b020ebae0cbcb9` (default the optional mock counter under Bash `set -u`).
- **Intermediate QIMA CI #975:** [run 42435627687](https://github.com/meridane/QimaTrade-MVP/actions/runs/42435627687) — **FAILURE** in the restoration guard. The new SHOW mock referenced `MOCK_SHOW_WRONG_FIRST_CALLS` without a default inside an arithmetic expression while the script uses `set -u`; the runner reported the unset-variable error and did not claim restoration. This was a test-harness defect, not a production finding.
- **Correction:** `e56da2f` assigns `MOCK_SHOW_WRONG_FIRST_CALLS` a default before numeric comparison, retaining strict nounset behavior.
- **Final QIMA CI #976:** [run 42435736103](https://github.com/meridane/QimaTrade-MVP/actions/runs/42435736103) — **SUCCESS** on code HEAD `e56da2f80b2d4a37182b500c68b020ebae0cbcb9`. Both jobs completed successfully: TypeScript, npm audit, Next.js build, Chromium, **322/322 Playwright tests**, CREATE_OFFER PostgreSQL integration/concurrency, legacy RLS, QA262–QA272 regression guards, real QA267 restoration, and participant self-enrollment RLS.
- The PostgreSQL job log contains the QA272 regression summary and the real QA267 message confirming `max_prepared_transactions` returned to baseline `0`, with no QA266 prepared transaction or disposable database remaining.
- **QIMA CodeQL #929:** [run 42435736264](https://github.com/meridane/QimaTrade-MVP/actions/runs/42435736264) — **SUCCESS**.
- The npm audit JSON reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings for CI #976. This is the result of that audit run, not a general guarantee of absence of vulnerabilities.
- The combined Vercel status on QA272 code HEAD was **FAILURE**, target `upgradeToPro=build-rate-limit`. This is a deployment quota status, separate from GitHub Actions; no Preview READY is claimed for this HEAD and no Production deployment occurred.
- **PR state at code validation:** PR #26 remained open and draft, mergeable, with 1001 commits ahead of `main`, 0 behind, 65 changed files, no reviews and no review threads.

### Safety boundary

- QA272 modified only the disposable CI restoration regression test. No application code, SQL migration, dependency, Supabase production data/schema/RLS/grant, secret, or persistent database configuration was changed.
- PostgreSQL configuration changes remain confined to the ephemeral GitHub Actions PostgreSQL 16 service.
- No Production deployment, PR merge, or branch-protection change occurred.


## QA273 — PostgreSQL setup cleanup marker (8 November 2026)

- Extracted the prepared-transaction setup into `tests/sql/enable-prepared-transactions-config.sh`.
- The setup validates the loopback `qima_test` URL, one PostgreSQL 16 container and baseline `0`; it writes `baseline=0` and `restore_required=true` to `GITHUB_OUTPUT` before `ALTER SYSTEM SET`.
- New setup regression tests assert marker-before-mutation ordering and preservation after SET exit 47, restart exit 48, post-restart SHOW exit 49, and bounded readiness exhaustion. The workflow invokes this test and retains the existing `if: always()` restoration step.
- QIMA CI #978 [run 42438738454](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738454) — **SUCCESS**; **322/322 Playwright tests**, PostgreSQL integration and QA273 setup regression passed. The PostgreSQL log also confirms real QA266 blocker handling and QA267 restoration to baseline `0`, with no residual prepared transaction or disposable database.
- QIMA CodeQL #931 [run 42438738450](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738450) — **SUCCESS**. npm audit reported zero findings in all five severity categories for this run only.
- Vercel combined status on the code HEAD was **SUCCESS** (Preview/check only; no Production deployment).
- The negative setup paths use command stubs; they verify shell control flow and output persistence, not an actual Docker/production outage or a confirmed vulnerability. Successful PostgreSQL configuration and restoration are separately tested against the ephemeral CI service.
- No production Supabase data, migration, schema, RLS policy, grant, secret, persistent configuration, Production deployment, merge or branch-protection setting was changed.


## QA273 — final documentation-head validation (8 November 2026, 11:26 KST)

- **Code HEAD:** `a2e35e7d1caa9800ce1def55463b3c8beab8c173`. QIMA CI #978 [run 42438738454](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738454) — **SUCCESS**; both jobs completed, including the QA273 setup regression, **322/322 Playwright tests**, CREATE_OFFER PostgreSQL integration, QA266 real prepared-transaction blocker handling and QA267 real PostgreSQL restoration. QIMA CodeQL #931 [run 42438738450](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738450) — **SUCCESS**.
- **Documentation HEAD:** `2bff0eb58ca4366e13f870229b1bec34b3fed20e`, after the three QA273 register updates. QIMA CI #979 [run 42438904011](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438904011) — **SUCCESS**; both jobs completed. The PostgreSQL job log contains the QA273 marker-before-mutation regression success line, confirms the live QA266 blocker case and confirms QA267 restored `max_prepared_transactions=0` with no residual prepared transaction or disposable database. The browser job reported **322 passed**; TypeScript, npm audit, Next.js build and Chromium steps all succeeded. QIMA CodeQL #932 [run 42438904032](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438904032) — **SUCCESS**.
- **npm audit:** CI #979 reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings. This is scoped to that run and is not a general guarantee of absence of vulnerabilities.
- **Vercel distinction:** the combined Vercel status on code HEAD `a2e35e7` was **SUCCESS** (Preview/check only). On final documentation HEAD `2bff0eb58ca4366e13f870229b1bec34b3fed20e`, the combined status returned **FAILURE** with target `upgradeToPro=build-rate-limit`. This is a deployment quota limitation, not a GitHub Actions or Next.js build failure. No Preview READY is claimed for the documentation HEAD and no Production deployment occurred.
- **PR comparison:** branch `fix/create-offer-status-contract` is 1008 commits ahead of `main`, 0 behind, with 67 changed files; no reviews or review threads were recorded. PR #26 remains open and draft.
- **Safety:** the final follow-up changed only documentation. No application code, Supabase production data/schema/migration/RLS/grant, secret, persistent database configuration, Production deployment, merge, or branch-protection setting was changed.


## QA273 — final-head check follow-up (8 November 2026, 12:51 KST)

- The final QA273 documentation-head checks were subsequently observed as **QIMA CI #980** [run 42439080004](https://github.com/meridane/QimaTrade-MVP/actions/runs/42439080004) — **SUCCESS** (both verification and PostgreSQL jobs completed), and **QIMA CodeQL #933** [run 42439080099](https://github.com/meridane/QimaTrade-MVP/actions/runs/42439080099) — **SUCCESS**. These checks were inspected after the earlier QA273 register snapshot and are recorded here to close that evidence gap.
- The combined status on the same documentation HEAD reported Vercel **FAILURE**, target upgradeToPro=build-rate-limit. This is a Preview build quota limitation; it is not a GitHub Actions or Next.js build failure. No Preview READY is claimed for that HEAD.

## QA274 — fail-closed Docker service-container discovery (8 November 2026, 12:51 KST)

- **Code HEAD:** d509e23a1cd10cefedaa06bd1881a7795976d931, on fix/create-offer-status-contract / PR #26.
- **Change:** both tests/sql/enable-prepared-transactions-config.sh and tests/sql/restore-prepared-transactions-config.sh now capture docker ps output and exit status in an explicit conditional. A non-zero docker ps status is preserved even if partial stdout was emitted; the partial output is never parsed or used. Only after successful discovery are non-empty lines parsed, and exactly one PostgreSQL 16 container is required before baseline queries, readiness probes, docker exec, RESET, or restart.
- **Regression coverage:** setup tests cover partial stdout plus exit 55, zero containers, and multiple containers, proving no baseline query or restoration marker is written. Restoration tests cover partial stdout plus exit 54, zero containers, and multiple containers, proving no readiness probe or RESET is attempted. Existing one-container success paths remain covered.
- **QIMA CI #981:** [run 42444679702](https://github.com/meridane/QimaTrade-MVP/actions/runs/42444679702) — **SUCCESS**; both jobs completed. The browser job reported **322 passed**; npm audit reported 0 info, 0 low, 0 moderate, 0 high, 0 critical; TypeScript, Next.js build and Chromium installation succeeded. The PostgreSQL job log contains both new QA274 regression success summaries and the real QA267 restoration confirmation (max_prepared_transactions returned to baseline 0, with no residual QA266 prepared transaction or disposable database).
- **QIMA CodeQL #934:** [run 42444679701](https://github.com/meridane/QimaTrade-MVP/actions/runs/42444679701) — **SUCCESS**.
- **Vercel:** combined status on code HEAD d509e23 reported **FAILURE** with target upgradeToPro=build-rate-limit. This is a Preview quota limitation; no Preview READY is claimed for this code HEAD and no Production deployment occurred.
- **PR comparison at code validation:** fix/create-offer-status-contract was 1017 commits ahead of main, 0 behind, with 67 changed files. No PR reviews or review threads were recorded. PR #26 remains open; its description continues to identify it as a draft.
- **Interpretation and limits:** the partial-output Docker failures are deterministic command-stub regressions; they do not prove that the Docker daemon failed or that a production vulnerability exists. The actual PostgreSQL setup, prepared-transaction blocker, cleanup and configuration restoration remain separately exercised on the ephemeral GitHub Actions PostgreSQL 16 service.
- **Safety:** no Supabase production connection, data, schema, migration, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was changed. All PostgreSQL mutations and restarts remain confined to the disposable GitHub Actions service.


## QA275 — initial PostgreSQL baseline read failure before mutation (2026-11-08)

- **Scope:** regression coverage for the setup path in `tests/sql/enable-prepared-transactions-config.sh`; no application/runtime business code changed.
- **Scenario:** after one unambiguous disposable PostgreSQL 16 container is discovered, the initial `SHOW max_prepared_transactions` command fails with controlled `psql` exit status 50.
- **Expected behavior verified:** the setup script preserves exit 50, emits the explicit baseline-capture diagnostic, leaves the GitHub Actions output file empty (no `baseline` or `restore_required=true`), and does not invoke `ALTER SYSTEM SET` or restart the container.
- **Always-cleanup behavior:** with the marker absent, the workflow's `if: always()` restoration script exits successfully as a no-op and issues no Docker or PostgreSQL command.
- **Test implementation:** `tests/sql/test-prepared-transactions-config-setup.sh` adds a first-call-only `MOCK_INITIAL_SHOW_STATUS` path and verifies the event order `docker-ps → psql-show-1`, empty step outputs, preserved exit code, and no-op restoration.
- **Harness correction:** the first QA275 test commit `b6a7b0b` had malformed shell escaping and omitted the restore-script path variable; commit `1190862` corrected the ANSI-C expected string, declared `RESTORE_SCRIPT`, and simplified the no-op invocation before CI validation. The earlier commit is not treated as a passing result.
- **GitHub Actions evidence on exact code HEAD `1190862cdf5d38f9da7096453f978d09b805e3dd`:** QIMA CI run **#985** completed successfully; both jobs succeeded. The PostgreSQL integration log contains the setup-regression success line, then confirms the real QA266 prepared-transaction blocker and QA267 cleanup/restoration on the ephemeral PostgreSQL 16 service. QIMA CodeQL run **#938** completed successfully on the same SHA.
- **Other CI evidence:** TypeScript, Next.js production build, Chromium installation and Playwright all succeeded; Playwright reported **322 passed (6.9s)**. npm audit reported **0 total findings** in that run. These results describe this run only and do not establish the absence of all vulnerabilities.
- **Vercel:** the combined Vercel status for this exact SHA was `success`; no production deployment was performed.
- **Limits:** the initial `psql` failure and absent-marker no-op are deterministic command-stub regressions, not evidence of a production PostgreSQL outage or vulnerability. Actual PostgreSQL mutations remain confined to the disposable GitHub Actions service.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, production deployment, PR merge, or branch-protection setting was changed.

## QA276 — reject a readable but non-pristine disposable PostgreSQL baseline (2026-11-08)

- **Scope:** regression coverage for tests/sql/enable-prepared-transactions-config.sh; no application/runtime business code or migration changed.
- **Scenario:** after exactly one disposable PostgreSQL 16 container is discovered, the setup test's psql mock returns a readable initial SHOW max_prepared_transactions value of 5 instead of the required pristine baseline 0.
- **Expected behavior:** the setup script exits with status 1, emits the explicit baseline-mismatch diagnostic, leaves the GitHub Actions output file empty (no baseline and no restore_required=true), and does not execute ALTER SYSTEM SET or restart PostgreSQL.
- **Cleanup behavior:** the test invokes the existing restoration script with empty marker/baseline outputs and verifies a successful no-op with no Docker or PostgreSQL command.
- **Implementation:** tests/sql/test-prepared-transactions-config-setup.sh now allows the first SHOW mock value to be set with MOCK_INITIAL_CONFIGURED_VALUE; the QA276 case uses 5 and asserts the exact event order docker-ps then psql-show-1, empty step outputs, the mismatch diagnostic, and absence of mutation events.
- **Initial harness failure:** first code commit 0d8ff956b0e352cce627d75064b8d9d943c629bd had a malformed inserted test block. QIMA CI #987 (run 42452623131) failed with a Bash syntax error near unexpected token ( at the setup regression file. The PostgreSQL job's IDEMPOTENCY_KEY_REUSE messages were expected negative-path integration cases; they were not the cause of the job failure.
- **Correction:** commit 68e4dc7493badca409b9309eeddbcecdba6c5529 repaired the test block and preserved the expected-output comparison without Bash replacement-string ambiguity.
- **QIMA CI #988:** run 42452799606 — SUCCESS on corrected code HEAD 68e4dc7493badca409b9309eeddbcecdba6c5529; both jobs completed successfully. The browser job reported 322 passed (7.3s); npm audit reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings; TypeScript, Next.js build, Chromium and audit enforcement succeeded. The PostgreSQL job completed CREATE_OFFER integration/concurrency, all migration/RLS/cleanup regressions, the prepared-transaction setup regression, and the real QA267 reset/restart/restoration to max_prepared_transactions=0 with no residual QA266 prepared transaction or disposable database.
- **QIMA CodeQL #940:** run 42452623123 — SUCCESS on initial QA276 code HEAD 0d8ff956b0e352cce627d75064b8d9d943c629bd. No separate CodeQL run was returned for corrected SHA 68e4dc7493badca409b9309eeddbcecdba6c5529; the correction changed only the shell regression test, not application JavaScript/TypeScript.
- **Vercel:** combined status on corrected HEAD was PENDING at the last check; no Preview READY is claimed.
- **Interpretation:** the initial value 5 is supplied by a deterministic test stub to verify fail-closed handling. It is not evidence that a real production database had this value or that a vulnerability exists. Actual PostgreSQL configuration changes and restoration remain confined to the ephemeral GitHub Actions PostgreSQL 16 service.
- **PR state:** PR #26 remains open and draft; at the code validation point it compared 1025 commits ahead of main, 0 behind, with 67 changed files and no reviews/review threads.
- **Safety:** no Supabase production connection, data, schema, migration, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was changed.
### QA276 — final documentation-head validation (8 November 2026)

- **Code HEAD:** 68e4dc7493badca409b9309eeddbcecdba6c5529. QIMA CI #988 (run 42452799606) — **SUCCESS**; both jobs completed, including PostgreSQL integration and cleanup, setup/restore regression suites, **322/322 Playwright tests**, npm audit (0 total findings), TypeScript, Next.js build and Chromium.
- **Documentation HEAD:** 50b53d6e7ade13e4bddef8adcc332408a534d600. QIMA CI #989 (run 42453014569) — **SUCCESS**; both jobs completed. The PostgreSQL log contains the setup regression summary and real QA267 restoration confirmation; the browser job reported **322 passed (7.0s)** and npm audit reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings.
- **QIMA CodeQL #942:** run 42453014597 — **SUCCESS** on documentation HEAD 50b53d6e7ade13e4bddef8adcc332408a534d600.
- **Vercel:** combined status on the documentation HEAD was **FAILURE**, target upgradeToPro=build-rate-limit. This is a Preview quota limitation, not a GitHub Actions or Next.js build failure; no Preview READY or Production deployment is claimed.
- **PR comparison:** 1028 commits ahead of main, 0 behind, 67 changed files. PR #26 remains open and draft; no reviews or review threads were recorded.
- **Scope:** the documentation-only follow-up records validation evidence; no application, SQL migration, production database, or persistent configuration changed.
## QA277 — fail closed when GitHub Actions cannot persist the PostgreSQL restoration marker (2026-11-08)

- **Scope:** regression coverage for `tests/sql/enable-prepared-transactions-config.sh` and its `if: always()` cleanup contract. No application/runtime business code, workflow definition, SQL migration, or production database was changed.
- **Scenario:** after one disposable PostgreSQL 16 container is discovered and the initial `SHOW max_prepared_transactions` returns the expected baseline `0`, the test injects a controlled failure at the `printf` boundary used to append `baseline=0` and `restore_required=true` to `GITHUB_OUTPUT`.
- **Injection detail and limitation:** a temporary `BASH_ENV` hook shadows `printf` only for the exact restoration-marker format, records `marker-write-failed`, and returns exit 52 without writing the marker. This deterministically exercises the setup script's non-zero marker-write branch. It is not an operating-system permission test, disk-full test, or proof of a real GitHub runner filesystem failure.
- **Expected behavior:** setup exits non-zero, emits `Could not persist PostgreSQL restoration intent; no configuration change was attempted.`, leaves the output file empty, and never executes `ALTER SYSTEM SET` or `docker restart`. The expected event sequence is `docker-ps`, `psql-show-1`, `marker-write-failed`.
- **Cleanup behavior:** the test invokes `restore-prepared-transactions-config.sh` with empty `RESTORE_REQUIRED` and baseline values; the `if: always()` cleanup path must exit successfully as a no-op without invoking Docker, readiness checks, or PostgreSQL.
- **Implementation history:** first test commit `e33ca3a6da08a979a4bfaac0f01a56273797c0fb` contained an incorrectly escaped Bash hook and was superseded before CI. Corrective commit `6e3751ca76eeeb7eabe1363df8415c9e78120631` uses a `case "$1"` match against the literal printf format. CI status for the corrected code is pending at this documentation revision.
- **Interpretation:** this is a deterministic shell regression for failure handling; it does not establish a production vulnerability, a real filesystem fault, or a PostgreSQL outage.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, production deployment, PR merge, or branch-protection setting was changed. PostgreSQL mutations remain confined to the disposable GitHub Actions service.

### QA277 — final CI and CodeQL validation (8 November 2026)

- **Corrected test commit:** `6e3751ca76eeeb7eabe1363df8415c9e78120631`. The QA277 marker-write failure assertions are included in the setup regression script. The initial malformed hook commit `e33ca3a6da08a979a4bfaac0f01a56273797c0fb` was superseded before validation.
- **Validated documentation HEAD:** `40ba0a446af8ab72d0f96d4c0510b63dd7bc638f`.
- **QIMA CI #991:** [run 42455954675](https://github.com/meridane/QimaTrade-MVP/actions/runs/42455954675) — **SUCCESS**, both jobs completed. The setup regression step containing QA277 completed successfully; the PostgreSQL integration job also passed the restoration guard, real prepared-transaction blocker, real `ALTER SYSTEM RESET` / restart, and QA267 postconditions on the ephemeral PostgreSQL 16 service.
- **Browser/build job:** npm install, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and Playwright all succeeded; **322/322 Playwright tests passed (6.0s)**. npm audit reported 0 info, 0 low, 0 moderate, 0 high, 0 critical, and 0 total findings in this run.
- **QIMA CodeQL #944:** [run 42455954673](https://github.com/meridane/QimaTrade-MVP/actions/runs/42455954673) — **SUCCESS**; check output states no new alerts in code changed by this pull request. This is a code-scanning result for this run, not a general proof that the repository has no vulnerabilities.
- **Vercel:** combined status on documentation HEAD `40ba0a446af8ab72d0f96d4c0510b63dd7bc638f` is **FAILURE** with `Deployment rate limited — retry in 24 hours` (`upgradeToPro=build-rate-limit`). No Preview READY or Production deployment is claimed.
- **Local harness check:** an isolated shell probe confirmed that the `BASH_ENV` `printf` hook matches the literal marker format, returns 52, leaves the output file empty, and reaches the expected failure branch. This supplements but does not replace CI.
- **Interpretation:** QA277 injects a deterministic `printf` failure at the marker-write boundary; it is not an OS permission/disk-full test and is not evidence of a production filesystem fault or vulnerability.
- **PR state at validation:** PR #26 is open and draft, mergeable, with no reviews or review threads. The work branch was fast-forwarded to the PR branch; no force-push was used.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, or branch-protection setting was changed.

### QA277 — final PR-head validation after register synchronization (8 November 2026)

- **PR documentation HEAD:** `c70aa47601d98c50027dfada75e9444500cd6fdf`.
- **QIMA CI #992:** [run 42456100382](https://github.com/meridane/QimaTrade-MVP/actions/runs/42456100382) — **SUCCESS**; both jobs completed. The PostgreSQL job completed the prepared-transaction setup regression containing QA277, the real QA266 prepared-transaction cleanup blocker, and QA267 restoration to `max_prepared_transactions=0` with no residual prepared transaction or disposable database.
- **Browser/build job:** npm installation and audit enforcement, TypeScript, Next.js build, Chromium, and browser tests all succeeded; **322/322 Playwright tests passed (7.7s)**. npm audit reported 0 info, 0 low, 0 moderate, 0 high, 0 critical, and 0 total findings for this run.
- **QIMA CodeQL #945:** [run 42456100379](https://github.com/meridane/QimaTrade-MVP/actions/runs/42456100379) — **SUCCESS**; the CodeQL check output states no new alerts in code changed by this pull request.
- **Vercel:** combined status for this PR HEAD remains **FAILURE** because the Preview deployment is rate limited (`upgradeToPro=build-rate-limit`). This is separate from the successful GitHub Actions build; no Preview READY or Production deployment is claimed.
- **Interpretation:** QA277 remains a deterministic `BASH_ENV`-injected `printf` failure (exit 52), not an OS-level filesystem fault or confirmed vulnerability. The final CI run proves the regression script completed successfully; it does not convert the stub into evidence of a production incident.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, or branch-protection setting was changed.

## QA278 — real filesystem permission denial for GITHUB_OUTPUT (2026-11-08)

- **Scope:** regression coverage for the PostgreSQL setup script's pre-mutation restoration-marker write. The test uses the existing disposable CI service and mocked Docker/psql commands; no application runtime or production database is involved.
- **Real filesystem condition:** create a regular GITHUB_OUTPUT file, make it mode 0444, and execute the setup script as an unprivileged account. GitHub-hosted Ubuntu runners normally execute steps unprivileged; if the test itself is invoked as root, it uses runuser -u nobody so the permission check cannot be bypassed by root privileges.
- **Assertions:** the actual shell append receives an operating-system Permission denied; the script exits non-zero; the output file remains empty; the only recorded setup events are docker container discovery and the initial SHOW; no ALTER SYSTEM SET or container restart occurs.
- **Cleanup:** the test invokes the if: always() restoration script with empty outputs and confirms it exits as a no-op without Docker, readiness, or PostgreSQL calls.
- **Local OS-level probe:** the isolated permission probe executed as nobody returned exit 1, preserved a zero-byte output file, and emitted Permission denied. This validates the runner's permission mechanism only; the complete repository regression remains subject to GitHub Actions.
- **Implementation history:** first QA278 commit 2814d6be9eede293bc4c4a14314c2940014221ef had a malformed test insertion; QIMA CI run 42461613424 failed in the setup regression with a Bash syntax error at line 418. The corrected test is commit 813bd1601e043e422e494bb890505dbf963bafba; its QIMA CI and CodeQL runs were still in progress when this note was prepared. CodeQL for the first commit completed successfully. The failed first CI run is retained as history and is not presented as a pass.
- **Interpretation:** QA278 is an OS-level permission regression in the disposable CI test environment, not evidence of a production filesystem fault or vulnerability.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### QA278 — final validation and correction history (8 November 2026)

- **Final code HEAD:** b2c5d41006391ee92e88118825919eda68cd86ab. The test now initializes the pre-created mock SHOW counter with 0 before switching the output file to mode 0444; this allows the unprivileged psql mock to complete the initial baseline read and reach the actual filesystem append.
- **First attempt:** commit 2814d6be9eede293bc4c4a14314c2940014221ef; QIMA CI #994 ([run 42461613424](https://github.com/meridane/QimaTrade-MVP/actions/runs/42461613424)) failed because the inserted QA278 test block was malformed (Bash syntax error at line 418). QIMA CodeQL #947 ([run 42461613425](https://github.com/meridane/QimaTrade-MVP/actions/runs/42461613425)) succeeded.
- **Second attempt:** commit 813bd1601e043e422e494bb890505dbf963bafba; QIMA CI #995 ([run 42462045065](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462045065)) failed in the setup regression because the QA278 mock SHOW-counter file was created empty. Under set -e, read returned non-zero before the psql event was recorded, so the test did not reach the intended GITHUB_OUTPUT permission check. No PostgreSQL configuration mutation was reached. QIMA CodeQL #948 ([run 42462045067](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462045067)) succeeded.
- **Corrected validation:** QIMA CI #996 ([run 42462176743](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462176743)) — **SUCCESS**, both jobs completed. The PostgreSQL job passed the prepared-transaction setup regression containing QA278, the real QA266 prepared-transaction blocker, and QA267 restoration on the ephemeral PostgreSQL 16 service. QA267 confirmed RESET, restart, baseline 0, and no residual prepared transaction or disposable database.
- **Browser/build job:** npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and Playwright all succeeded; **322/322 Playwright tests passed (8.3s)**. npm audit reported 0 info, 0 low, 0 moderate, 0 high, 0 critical, and 0 total findings in this run.
- **QIMA CodeQL #949** ([run 42462176783](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462176783)) — **SUCCESS**; the check output states “No new alerts in code changed by this pull request.” This is a run-specific code-scanning result, not a general proof that the repository has no vulnerabilities.
- **Local OS-level probe:** run as nobody, the append to a mode-0444 output file returned exit 1, the file remained zero bytes, and the shell reported Permission denied. This supports the filesystem test design; the repository regression itself is validated by CI #996.
- **Vercel:** combined status on final HEAD b2c5d41006391ee92e88118825919eda68cd86ab is **FAILURE** with upgradeToPro=build-rate-limit. The GitHub Actions build succeeded; no Preview READY or Production deployment is claimed.
- **PR state:** PR #26 remains open, draft, and mergeable; no review submissions or review threads were recorded.
- **Interpretation:** QA278 is a real OS permission-denial regression in disposable CI, not evidence of a production filesystem fault or vulnerability.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.



### QA279 — partial GITHUB_OUTPUT marker write (2026-11-08)

- **Code commit:** `f424bf2652daa1ae6e25744cf518d406b4123756` adds a deterministic partial-write regression to `tests/sql/test-prepared-transactions-config-setup.sh`.
- **Injected behavior:** a temporary `BASH_ENV` hook writes only `baseline=0\n` to the real temporary output file, records `marker-write-partial`, then returns exit 53 before `restore_required=true` can be persisted.
- **Assertions:** setup exits non-zero, the output contains exactly the partial baseline line, the restoration marker is absent, and the event sequence is exactly `docker-ps`, `psql-show-1`, `marker-write-partial`. No `ALTER SYSTEM SET` or PostgreSQL restart is allowed.
- **Cleanup:** the test passes `RESTORE_REQUIRED=""` and `BASELINE_MAX_PREPARED_TRANSACTIONS="0"` to the restoration script, confirming that a partial baseline output without the intent marker produces a no-op and makes no Docker/PostgreSQL calls.
- **Interpretation:** this is a deterministic shell-hook regression that exercises a real partial write to a temporary file followed by an injected command failure. It does not simulate disk-full/ENOSPC or establish a production filesystem fault or vulnerability.
- **Code commit validation:** QIMA CI #1000 ([run 42462932529](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462932529)) — **SUCCESS**, both jobs completed on code commit `f424bf2652daa1ae6e25744cf518d406b4123756`. The PostgreSQL job's prepared-transaction setup regression passed with QA279; the job also completed the real QA267 RESET/restart/restoration to baseline `0` with no residual QA266 prepared transaction or disposable database. The browser/build job passed npm installation, npm audit enforcement at the high threshold, TypeScript, Next.js production build, Chromium installation, and **322/322 Playwright tests (6.9s)**. QIMA CodeQL #953 ([run 42462932693](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462932693)) — **SUCCESS**.
- **Intermediate documentation-head checks:** QIMA CI #1001 (run 42463036361) on `f15b1e5d2b3b36775a8098d280f1ac4a1722d87f` was **CANCELLED** after a newer documentation commit advanced the PR head; its PostgreSQL job did not complete and is not counted as validation. QIMA CodeQL #954 (run 42463036548) on that intermediate HEAD completed **SUCCESS**.
- **Vercel:** the combined status on the code HEAD remains **FAILURE** due to the Preview build rate limit (`upgradeToPro=build-rate-limit`); this is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### QA279 — final register-head validation (2026-11-08)

- **Validated HEAD:** `e4897a4d5d0ea6647a65ef1c6cea7873cca5c18c`, containing the QA279 regression and all three register updates.
- **QIMA CI #1002** ([run 42463101344](https://github.com/meridane/QimaTrade-MVP/actions/runs/42463101344)) — **SUCCESS**, both jobs completed. The PostgreSQL job's setup regression passed and logged the QA279 partial-`GITHUB_OUTPUT` write case, followed by real QA267 `ALTER SYSTEM RESET`, PostgreSQL restart, return to baseline `0`, and absence of the QA266 prepared transaction and disposable database. The browser/build job passed npm installation, npm audit enforcement at the high threshold, TypeScript, Next.js production build, Chromium, and **322/322 Playwright tests (6.8s)**.
- **QIMA CodeQL #955** ([run 42463101442](https://github.com/meridane/QimaTrade-MVP/actions/runs/42463101442)) — **SUCCESS**.
- The combined Vercel status remains **FAILURE** due to the Preview build rate limit (`upgradeToPro=build-rate-limit`); this is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- This is a deterministic partial-write regression in disposable CI, not evidence of a production filesystem fault or vulnerability. No Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


## QA280 — Reject restoration when the captured baseline is missing (2026-11-08)

- **Scope:** regression coverage only in `tests/sql/test-prepared-transactions-config-restore.sh`. The existing restoration script already rejects every baseline other than the explicitly approved value `0`; no production or restoration-script logic change was needed.
- **Scenario:** invoke the cleanup script with `RESTORE_REQUIRED=true`, a valid loopback-only disposable `qima_test` URL, and `BASELINE_MAX_PREPARED_TRANSACTIONS` explicitly removed from the environment using `env -u`.
- **Expected and observed behavior in the PostgreSQL integration job:** exit code `2`; the existing “Expected the captured disposable-service baseline to be 0” diagnostic; an empty event log (no Docker discovery, `pg_isready`, `psql`, `ALTER SYSTEM RESET`, or restart); and no QA267 success message. This proves the guard runs before external operations when the marker says restoration is required but its baseline is absent.
- **First attempt:** commit `6866584fe09c6af53f3553ca98deeb8bea29267a`, QIMA CI #1004 (run [42470202372](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470202372)) had a PostgreSQL-job failure in the test harness: the generated continuation lines contained two literal backslashes, so `env` attempted to execute `\\` and Bash reported “command not found”. The browser job was cancelled when the corrected commit superseded it. This was a test-invocation error, not a product vulnerability or PostgreSQL failure. CodeQL #957 ([run 42470202445](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470202445)) succeeded on that first commit.
- **Correction:** commit `f44f7006d0e737c4d6a64192f984c22b68e320c5` uses one shell line-continuation backslash per line. The exact QA280 block was re-read from the PR branch before validation.
- **Final validation:** QIMA CI #1005 ([run 42470336296](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470336296)) — SUCCESS; both PostgreSQL integration and browser/build jobs succeeded. The PostgreSQL log explicitly reports the restoration regression suite passed with the missing-baseline guard included, the setup regression passed, and the real disposable PostgreSQL 16 QA267 RESET/restart returned `max_prepared_transactions` to `0` with no residual QA266 transaction or disposable database. Browser/build checks: `npm ci`, npm audit at the high threshold (**0 total findings**), TypeScript, Next.js production build, Chromium installation, and **322/322 Playwright tests (6.7s)** all succeeded. CodeQL #958 ([run 42470336308](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470336308)) — SUCCESS. The Vercel status for this code HEAD was SUCCESS; no Production deployment is claimed.
- **Classification:** a deterministic regression for a missing environment value. It is not evidence of a production incident or vulnerability. No Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### QA280 register-head verification — CI #1006 / CodeQL #959

- The two QA280 register updates were included in PR HEAD `abd955099715a051259cd8ffc7ced2292da76cd4` and revalidated.
- **QIMA CI #1006** ([run 42470593151](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470593151)) — **SUCCESS**; PostgreSQL integration job and browser/build job both completed successfully. The restoration regression log includes the missing-baseline guard; the setup regression passed; the real QA267 PostgreSQL 16 RESET/restart returned to baseline `0` with no QA266 residue. npm audit reported **0 total findings**; TypeScript and Next.js production build passed; Playwright reported **322 passed (10.1s)**.
- **QIMA CodeQL #959** ([run 42470593109](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470593109)) — **SUCCESS**.
- The Vercel status for this documentation HEAD was **SUCCESS**. No Preview READY or Production deployment is inferred from the status check.

### QA281 — noncanonical restoration baseline matrix (2026-11-08)

- **Test:** `tests/sql/test-prepared-transactions-config-restore.sh`; the existing cleanup guard accepts only the exact captured baseline `0`.
- **Matrix:** empty string, `10`, `00`, `-1`, ` 0`, and `0 ` are each supplied as `BASELINE_MAX_PREPARED_TRANSACTIONS`. Each case returns exit `2`, emits the exact-baseline diagnostic, leaves the external-command event log empty, and does not claim QA267 success. The normal exact-`0` restoration path remains successful.
- **Code commit:** `9ca4c7641245afdff99ab3cf919eee44ef3ef4c9`.
- **QIMA CI #1008** ([42473664227](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473664227)) — **SUCCESS**; PostgreSQL and browser/build jobs passed. The PostgreSQL log includes the QA281 matrix and real PostgreSQL 16 QA267 restoration to baseline `0`, with no QA266 residue. Browser/build checks passed npm audit at the high threshold, TypeScript, Next.js build, and **322/322 Playwright tests (7.8s)**.
- **QIMA CodeQL #961** ([42473664222](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473664222)) — **SUCCESS**. Vercel combined status for the code HEAD — **SUCCESS**; no Production deployment is inferred.
- **Safety:** test-only regression; no Supabase production data or migrations, schema, RLS, grants, secrets, or persistent database configuration were touched.

### QA281 documentation-head verification — CI #1009 / CodeQL #962 (2026-11-08)

- Final QA281 register contents were present on PR HEAD `9e45637dbc8df5ac2202baf8cd0e1dfc437e8e7c` and revalidated.
- QIMA CI #1009 ([42473845549](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473845549)) — **SUCCESS**: PostgreSQL integration and browser/build jobs passed; PostgreSQL logs confirm the QA281 matrix and real QA267 PostgreSQL 16 RESET/restart to baseline `0` with no QA266 residue. npm audit enforcement at the high threshold, TypeScript, Next.js build, and **322/322 Playwright tests (9.4s)** passed.
- QIMA CodeQL #962 ([42473845560](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473845560)) — **SUCCESS**.
- Vercel combined status on this documentation HEAD — **FAILURE** due to `upgradeToPro=build-rate-limit`; no Preview READY or Production deployment is claimed.
- No production Supabase object or migration was changed.


## QA282 — Exact RESTORE_REQUIRED marker contract (8 November 2026)

- **Scope:** regression-only addition to `tests/sql/test-prepared-transactions-config-restore.sh`; no restoration script, application code, migration, or CI workflow changed.
- **Matrix:** `RESTORE_REQUIRED` unset, empty, `false`, `1`, and uppercase `TRUE`. Every case exits 0 as a no-op, emits the existing “configuration was not changed; restoration is not required” message, leaves the external-command event log empty, and does not emit the QA267 success message. Each case deliberately supplies a remote URL and invalid baseline, proving the exact-marker gate runs before those validations and before Docker, readiness, or database commands. The existing successful exact-`true` plus baseline-`0` case remains the positive path.
- **Code commit:** `41eae5e0104bb4935011233e91a4e3f42d54c0c6`.
- **QIMA CI #1011** ([run 42475182013](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475182013)) — **SUCCESS**. PostgreSQL integration job and browser/build job both completed successfully, including the restoration guard suite, CREATE_OFFER integration/concurrency checks, RLS regressions, dependency audit enforcement, TypeScript, Next.js production build, Chromium, and Playwright smoke tests.
- **QIMA CodeQL #964** ([run 42475182036](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475182036)) — **SUCCESS**.
- **Vercel commit status:** **SUCCESS** (“Deployment has completed”) for the code commit. This is a Preview/check status only; no Production deployment is claimed.
- **Classification and safety:** deterministic environment-marker regression coverage, not evidence of a production incident or vulnerability. No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was touched; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA282 documentation-head verification — CI #1012 / CodeQL #965 (8 November 2026)

- **Validated PR HEAD:** `17e3596bad28482392b083bf46a070bf9671f3c9`, containing the QA282 regression and all three register updates.
- **QIMA CI #1012** ([run 42475382591](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475382591)) — **SUCCESS**. Both jobs completed: the PostgreSQL integration job passed CREATE_OFFER/concurrency, legacy messages RLS and cleanup regressions, prepared-transaction setup/restoration guards, and participant self-enrollment RLS; the browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation, and browser smoke tests.
- **QIMA CodeQL #965** ([run 42475382387](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475382387)) — **SUCCESS**; no new alerts in code changed by this pull request.
- **Vercel status on this documentation HEAD:** **FAILURE** because the Preview deployment quota returned `upgradeToPro=build-rate-limit`. This is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- **Safety:** documentation-head verification only; the code tested by CI #1011 is unchanged. No Supabase production data, migrations, schema, RLS policy, grants, secrets, or persistent PostgreSQL configuration were modified; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA283 — exact RESTORE_REQUIRED marker rejects whitespace, case, and newline variants

- **Date:** 8 November 2026 (KST).
- **Test file:** `tests/sql/test-prepared-transactions-config-restore.sh`.
- **Code commit:** `882f8adea7d4c9fda0dfdc942e55382b4caf7af0`.
- **Scenario:** the restoration guard receives leading/trailing spaces, mixed-case `True`, leading/trailing line feeds, and leading/trailing tabs in `RESTORE_REQUIRED`.
- **Expected/observed:** all seven noncanonical values exit successfully as no-ops, before validating the deliberately remote `DATABASE_URL` or invalid baseline. The mock external-command event log remains empty; Docker, `pg_isready`, and `psql` are not invoked; no `QA267 passed` success message is emitted.
- **Positive control:** the existing exact `RESTORE_REQUIRED=true` path with loopback `qima_test` and captured baseline `0` still executes the full restoration regression.
- **QIMA CI #1014** ([run 42480565945](https://github.com/meridane/QimaTrade-MVP/actions/runs/42480565945)) — **SUCCESS**. Both jobs completed: PostgreSQL integration/cleanup tests and browser/build tests. Playwright reported **322 passed**; TypeScript, Next.js build, Chromium, dependency-audit enforcement, and the prepared-transaction restoration suite passed.
- **QIMA CodeQL #967** ([run 42480565990](https://github.com/meridane/QimaTrade-MVP/actions/runs/42480565990)) — **SUCCESS**.
- **PostgreSQL evidence:** the CI log explicitly reports the QA283 marker matrix passing, then QA266's real prepared-transaction cleanup test and QA267's real `ALTER SYSTEM RESET`/restart restoration to baseline `0` with no residual QA266 transaction or disposable database.
- **Vercel:** Preview status was **PENDING** at the latest check for this code commit. No Preview READY or Production deployment is claimed.
- **Classification:** deterministic environment-variable contract regression coverage, not evidence of a production incident or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA284 — CREATE_OFFER optional business fields are preserved through the route-to-RPC contract

- Date: 8 November 2026 (KST).
- Test: `tests/e2e/create-offer-route-contract.spec.ts`; code commit `b7e2e62e2f82fa5b57c8911fd41091f4517ab82c`.
- Mapping verified: `conditions` → `p_conditions`; `market` → `p_market`; `geography` → `p_geography`; `documentationStatus` → `p_documentation_status`. Explicit strings are asserted in both `p_input` and the matching top-level RPC argument.
- Null/omitted behavior: explicit JSON null and omitted values both produce present null properties in `p_input` and the corresponding RPC arguments; normalized optional-field payloads are asserted equal.
- QIMA CI #1016 ([run 42486166041](https://github.com/meridane/QimaTrade-MVP/actions/runs/42486166041)) — **SUCCESS**, including **323/323 Playwright tests** and successful browser/build and PostgreSQL integration jobs. The new test is explicitly present in the browser log. TypeScript, Next.js build, Chromium, dependency-audit enforcement, CREATE_OFFER integration/concurrency, RLS, cleanup, QA266 and QA267 passed.
- QIMA CodeQL #969 ([run 42486166033](https://github.com/meridane/QimaTrade-MVP/actions/runs/42486166033)) — **SUCCESS**.
- PostgreSQL evidence: QA266 confirmed real prepared-transaction blocking and explicit rollback; QA267 confirmed RESET/restart to baseline 0 with no residual prepared transaction or disposable database.
- Vercel combined status on the code commit: **SUCCESS** (Preview status only; no Production deployment).
- Classification: regression coverage of the existing route-to-RPC contract, not evidence of a production incident or vulnerability. No production Supabase data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment or PR merge occurred.


### QA285 — empty optional CREATE_OFFER strings remain distinct from null

- Added a route test proving empty `conditions`, `market`, `geography`, and `documentationStatus` values remain `""` in both the action input and matching SQL RPC arguments; explicit null remains null and produces a different normalized payload.
- Added PostgreSQL runtime assertions that empty `p_market`, `p_conditions`, and `p_geography` do not replay a completed request whose original values were SQL NULL. Each changed same-key retry must raise `IDEMPOTENCY_KEY_REUSE`. Existing coverage already checks empty `p_documentation_status` against NULL.
- Code commits: `682ef4d43616416c863c653ebe88e95d38aedd8d` (route) and `91cc390cf3dd129f683f9db1cfef3fd6e503f0f5` (SQL runtime).
- QIMA CI #1018 ([run 42490794951](https://github.com/meridane/QimaTrade-MVP/actions/runs/42490794951)) — **SUCCESS**, with **324/324 Playwright tests**. The log explicitly names the new QA285 route test. TypeScript, Next.js build, Chromium, npm audit enforcement at the high threshold, CREATE_OFFER PostgreSQL integration/concurrency, RLS, cleanup, QA266 and QA267 passed.
- QIMA CodeQL #971 ([run 42490795034](https://github.com/meridane/QimaTrade-MVP/actions/runs/42490795034)) — **SUCCESS**.
- PostgreSQL 16 evidence: the isolated integration job passed with no residual prepared transaction or disposable database; QA267 restored `max_prepared_transactions` to baseline 0 after RESET/restart.
- Vercel combined status on the code commit: **SUCCESS** (Preview only; no Production deployment).
- Classification: regression coverage only; no production incident or vulnerability is inferred. No production Supabase data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment or PR merge occurred.


### QA285 — final PR HEAD validation

- Documentation HEAD: `ad66b98c6a56a667977873e8944d57027d05f43d`; QA285 application/SQL test commits remained `682ef4d` and `91cc390`.
- QIMA CI #1019 ([run 42491022728](https://github.com/meridane/QimaTrade-MVP/actions/runs/42491022728)) — **SUCCESS**, **324/324 Playwright tests**; TypeScript, build, npm audit enforcement, CREATE_OFFER PostgreSQL integration/concurrency, RLS, cleanup, QA266 and QA267 passed.
- QIMA CodeQL #972 ([run 42491022811](https://github.com/meridane/QimaTrade-MVP/actions/runs/42491022811)) — **SUCCESS**.
- Vercel: code commit Preview status **SUCCESS**; documentation HEAD **rate-limited** (`upgradeToPro=build-rate-limit`). No Production deployment.


### QA286 — exact empty-string replay and NULL mismatch

- Code commit: 485d69454a802b3e71804c841fdc294f76b81ba1; SQL regression: tests/sql/create-offer-runtime.sql.
- Four optional fields (conditions, market, geography, documentationStatus) are created with empty text. The fixture verifies the complete request hash, persisted values, exactly one completed idempotency row/execution/offer/success event, and an identical replay returning the stored result without duplicates.
- Changing conditions from empty text to JSONB null and SQL NULL under the same key must raise IDEMPOTENCY_KEY_REUSE; all row counts remain unchanged.
- QIMA CI #1021 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42493888884) — **SUCCESS**; PostgreSQL log explicitly records QA286; **324/324 Playwright tests** and the build/typecheck/audit/RLS/cleanup jobs passed.
- QIMA CodeQL #974 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42493888899) — **SUCCESS**. Vercel code-commit Preview status — **SUCCESS**.
- Classification: regression coverage only; no production incident or vulnerability is inferred. No production Supabase data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment or PR merge occurred.


### QA286 — final PR HEAD validation

- Final documentation HEAD: 08403ed26d70f327f7985db8bc6fe19cb262e7df; QA286 SQL test remains in code commit 485d694.
- QIMA CI #1022 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42494130242) — **SUCCESS**. PostgreSQL log explicitly records QA286; **324/324 Playwright tests** passed, with TypeScript, Next.js build, audit enforcement, CREATE_OFFER PostgreSQL integration/concurrency, RLS, cleanup, QA266 and QA267 successful.
- QIMA CodeQL #975 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42494130392) — **SUCCESS**.
- Vercel code-commit Preview — **SUCCESS**; final documentation HEAD rate-limited (upgradeToPro=build-rate-limit). No Production deployment.



### QA287 — concurrent first-time CREATE_OFFER requests with four empty optional strings (9 November 2026)

- Test location: `tests/sql/run-create-offer-integration.sh`; code commit: `1c1b40c82b41844e060de5bd529124f4381806a5`.
- Two independent PostgreSQL sessions submit the same first-time CREATE_OFFER request for the same tenant and idempotency key. Both `p_input` and RPC parameters preserve `conditions`, `market`, `geography`, and `documentationStatus` as empty strings.
- The integration runner observes the expected advisory-lock state `2|1|1|1`: two sessions on one tenant/key lock, one granted while inside the fixture delay and one waiting on that same lock.
- Both concurrent calls succeed and return byte-for-byte identical JSONB output. The output also matches the single persisted idempotency result.
- The PostgreSQL assertions verify the exact effective-request hash, exactly one completed idempotency row, one completed action execution preserving the four empty strings, one offer preserving all four empty columns, and one `ACTION_SUCCEEDED` event matching the execution result.
- QIMA CI #1025 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42500395727) — **SUCCESS**. The PostgreSQL job log explicitly records QA287 passing; the browser job passed **324/324 Playwright tests**. Dependency installation/audit enforcement, TypeScript, Next.js production build, CREATE_OFFER PostgreSQL integration/concurrency, RLS, cleanup, and QA266/QA267 passed.
- QIMA CodeQL #977 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42500395719) — **SUCCESS**.
- Vercel status on the QA287 code commit: **SUCCESS** (Preview only). No Production deployment.
- Classification: regression coverage of the existing same-tenant idempotency/advisory-lock contract; this synthetic fixture is not evidence of a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA288 — concurrent same-key CREATE_OFFER requests with different effective payloads (9 November 2026)

- Test location: \`tests/sql/run-create-offer-integration.sh\`; code commit: \`f567d500fb89935f03cc5c9a91d32d81dd74281c\`.
- On the disposable PostgreSQL 16 integration database, session A starts the first-time request with \`conditions = ''\` and the other three optional fields (\`market\`, \`geography\`, \`documentationStatus\`) also empty. The test waits until A is observed holding the tenant/key transaction-scoped exclusive advisory lock during the fixture's \`pg_sleep\` before it starts session B.
- Session B uses the same tenant, idempotency key, actor, demand, product, name, quantity, price, currency, and remaining optional values. Its only effective change is \`conditions = NULL\` in the RPC and JSONB \`p_input\` (instead of empty text).
- The observer records \`2|1|1|1\`: two named active sessions, A granted and sleeping, B waiting on the same advisory lock. This establishes the intended concurrent ordering rather than relying on simultaneous process launch alone.
- Session A exits successfully. Session B exits nonzero and its PostgreSQL error log contains exactly the expected domain code \`IDEMPOTENCY_KEY_REUSE\`.
- The successful A response matches the single persisted idempotency result. SQL assertions verify one completed idempotency row with the first request's effective-parameter hash, one completed action execution preserving the original empty-string input, one offer preserving the original empty optional columns, and one \`ACTION_SUCCEEDED\` event matching the stored execution result. The rejected waiter creates no second offer, execution, idempotency row, or event.
- QIMA CI #1027 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42505426391): **SUCCESS**. The PostgreSQL integration/concurrency job passed, including the explicit QA288 log line; the browser job passed **324/324 Playwright tests**. npm installation and audit enforcement, TypeScript, Next.js build, Chromium, RLS, cleanup, and prepared-transaction QA266/QA267 passed.
- QIMA CodeQL #979 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42505426427): **SUCCESS**.
- Vercel combined status on code commit \`f567d500fb89935f03cc5c9a91d32d81dd74281c\`: **SUCCESS** (Preview only; no Production deployment).
- Classification: deterministic concurrency regression coverage of the existing same-tenant idempotency/advisory-lock contract. The expected \`IDEMPOTENCY_KEY_REUSE\` SQL error is the negative assertion under test, not a failed CI run or evidence of a production incident/confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA289 — CREATE_OFFER public failed-status and unsupported-status response contract (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `888150afcf2fe27e80ab67e3dbdbaee1616f194f`.
- Strengthened the existing failed-result route test to assert the complete public response: HTTP 409; exact `executionId`, `status: "failed"`, `objectId`, and nested result; no authentication challenge; and exactly one `execute_create_offer_v1` RPC call.
- Added route-level negative coverage for unsupported engine result statuses `pending`, `running`, `completed`, and the empty string. Each is rejected by the action-result contract and mapped to the generic HTTP 500 body `{"error":"ACTION_FAILED"}`; the internal `ACTION_RESULT_INVALID` code is not exposed, and the execution RPC is observed exactly once.
- The route and action-engine implementation were not changed. The existing contract already maps a valid `failed` result to HTTP 409 and the engine accepts only `succeeded` or `failed` as terminal public results; this QA entry records regression coverage, not a newly discovered production defect.
- QIMA CI #1029 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42511298360): **SUCCESS**. The browser job passed **325/325 Playwright tests**, including the strengthened failed-result test and the new unsupported-status matrix. Dependency installation and npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267 all passed.
- QIMA CodeQL #981 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42511298369): **SUCCESS**.
- Vercel status on code commit `888150afcf2fe27e80ab67e3dbdbaee1616f194f`: **SUCCESS** (Preview only; no Production deployment).
- Classification: API contract regression coverage and fail-closed validation of unsupported action statuses. The synthetic invalid-status fixtures do not establish a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.



### QA290 — CREATE_OFFER succeeded public response contract (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `9fb9df7da041767dae86bc037c1ea0ec2be40b06`.
- Added an explicit positive route regression for an execution RPC result with `status: "succeeded"`. It asserts HTTP 200 and the complete exact JSON response: `executionId`, `status`, `objectId`, and nested `result.offerId`.
- The test also asserts that no `WWW-Authenticate` challenge is returned, exactly one `execute_create_offer_v1` RPC is called, and the request sequence is Auth, profile, membership, action-definition lookup, then execution RPC.
- No route, action-engine, SQL, or migration implementation was changed; this locks down the existing success contract complementary to QA289's failed HTTP 409 and unsupported-status HTTP 500 cases.
- QIMA CI #1031 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42516121757): **SUCCESS**. The browser job passed **326/326 Playwright tests**, including the new QA290 test. npm installation, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser suite passed.
- The PostgreSQL integration job in CI #1031 also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267. The QA290 change itself is route-test-only and adds no SQL fixture.
- QIMA CodeQL #983 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42516122123): **SUCCESS**; CodeQL analysis and upload completed successfully.
- Vercel combined status on code commit `9fb9df7da041767dae86bc037c1ea0ec2be40b06`: **SUCCESS** (Preview status only; no Production deployment).
- Classification: positive API contract regression coverage. The mocked route fixture is not evidence of a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.



### QA291 — CREATE_OFFER malformed successful RPC result at the HTTP boundary (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `158f25336f8db32fd5aec85809afa18db96a23c2`.
- Extended the route fixture with a test-only RPC result override, removed from the submitted request body before dispatch. Added eight malformed RPC result cases: null result, missing/blank/non-string `executionId`, non-string `objectId`, and null/array/primitive nested `result` payloads.
- For every malformed result, the real Next.js `POST` route is exercised through the mocked Supabase Auth/REST boundary. The route must return exactly HTTP 500 with `{"error":"ACTION_FAILED"}`, omit the internal `ACTION_RESULT_INVALID` code and a private sentinel, emit no authentication challenge, and call `execute_create_offer_v1` exactly once after the expected Auth/profile/membership/action-definition sequence.
- Existing engine unit tests already cover the normalization rules; QA291 adds route-boundary regression coverage. No application route, engine, SQL, migration, or production configuration was changed.
- QIMA CI #1033 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42521070588): **SUCCESS**. Browser job passed **327/327 Playwright tests**, including QA291. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL integration job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267.
- QIMA CodeQL #985 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42521070573): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel status on code commit `158f25336f8db32fd5aec85809afa18db96a23c2`: **SUCCESS** (Preview only; no Production deployment).
- Vercel status on documentation-only HEAD `48d04ce0f788fdc7c680106612a0023d4437b9e9`: **FAILURE** (`upgradeToPro=build-rate-limit`). The Preview quota limit prevented a new Preview for this docs-only commit; QIMA CI and CodeQL were not re-triggered because both workflows exclude `docs/**`. The code commit's Preview remains **SUCCESS**; no Production deployment.
- Classification: synthetic route-contract regression coverage. The malformed RPC fixtures do not establish a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.

### QA292 — CREATE_OFFER action-definition contract at the HTTP boundary (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `678d397d27ab4a67785a3f9c76f689d43a361bd3`.
- Widened only the route-test helper's action-definition fixture type to `unknown`, allowing malformed JSON RPC responses to be represented without weakening application types.
- Expanded the existing route-level definition gate from 3 to 12 cases: missing definition, draft, retired, wrong action key, mismatched numeric version, string version, missing action key, missing version, missing status, unsupported status, empty RPC row set, and malformed primitive response.
- Every case must return exactly HTTP 400 with `{"error":"ACTION_NOT_PUBLISHED"}`, no `WWW-Authenticate` challenge, and no internal/diagnostic details. The test verifies exactly one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, the complete request order ending at definition lookup, and zero `execute_create_offer_v1` calls.
- No route, runtime, action-engine, SQL, migration, or production configuration was changed. Existing engine validation remains the implementation; QA292 locks its malformed/mismatched definition behavior at the HTTP boundary. These JSON fixtures are synthetic regression cases, not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1036 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528402681): **SUCCESS**. Browser job passed **327/327 Playwright tests**, including the 12-case QA292 definition matrix. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL integration job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267.
- QIMA CodeQL #988 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528402703): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel status on code commit `678d397d27ab4a67785a3f9c76f689d43a361bd3`: **SUCCESS** (Preview only; no Production deployment).
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.
- Final HEAD verification: QIMA CI #1037 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528616794): **SUCCESS** on documentation HEAD `fce7d05a8f6172b09b90edfbd0285cf65f3b7d5e`; browser job passed **327/327 Playwright tests**, including QA292, and the PostgreSQL integration/RLS/cleanup/prepared-transaction jobs passed. QIMA CodeQL #989 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528617212): **SUCCESS**. Vercel on that HEAD: **SUCCESS** (Preview only; no Production deployment).

### QA293 — CREATE_OFFER accepts a published action definition returned as a PostgREST row array (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `ab616742bb135454e727aef5985551946692231b`.
- Added a positive route-level regression in which the mocked `get_action_definition_v1` RPC returns a one-row PostgREST array: `[{ action_key: "CREATE_OFFER", version: 1, status: "published" }]`. This covers the row-array representation handled by `lib/actions/runtime.ts` (`Array.isArray(data) ? data[0] : data`) without changing runtime behavior.
- The real Next.js `POST` route must accept the first row and return HTTP 200 with the exact `executionId`, `status: "succeeded"`, `objectId`, and nested `result.offerId`. Assertions also verify no `WWW-Authenticate` challenge, the Auth/profile/membership/definition/execution request order, exactly one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, and exactly one `execute_create_offer_v1` call.
- The test-only fixture uses a one-row array consistent with a table-returning PostgREST RPC. No route, runtime, action-engine, SQL, migration, or production configuration was changed. QA293 is synthetic route-contract regression coverage, not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1039 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531695458): **SUCCESS**. Browser job passed **328/328 Playwright tests**, including QA293. npm ci, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, active-session cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #991 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531695658): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel status on code commit `ab616742bb135454e727aef5985551946692231b`: **SUCCESS** (Preview only; no Production deployment).
- QIMA CI #1040 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531880610) and QIMA CodeQL #992 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531880603) were also triggered on documentation HEAD `60051878b97ea5aaf497cf54e69fc457de5d9bdf`. Although both workflows declare `paths-ignore: docs/**`, GitHub evaluates the `pull_request` path filter against the aggregate PR diff, which still contains non-documentation changes; the documentation-only commit therefore did trigger both workflows. CI #1040 completed **SUCCESS** with **328/328 Playwright tests** and successful PostgreSQL integration/RLS/cleanup/prepared-transaction jobs; CodeQL #992 completed **SUCCESS**. The earlier code-commit checks #1039/#991 also remain successful.
- Vercel status on documentation HEAD `60051878b97ea5aaf497cf54e69fc457de5d9bdf`: **FAILURE** (`upgradeToPro=build-rate-limit`; deployment rate limited). The QA293 code commit's Preview remains **SUCCESS**; no Production deployment.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA294 — reject malformed PostgREST action-definition row arrays (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `1c60b03340f2ed1c9eec9c204d54d3347bbe1f03`.
- Extended the existing CREATE_OFFER invalid-definition matrix with two row-array cases: `[null]` and a one-row array whose first row has `action_key = PUBLISH_PRODUCT_REQUEST` instead of `CREATE_OFFER`.
- The first case exercises the runtime's PostgREST array normalization when its selected first row is null. The second exercises the engine's action-key/version contract after the runtime maps the first row. Both must be rejected before the CREATE_OFFER handler runs.
- For both cases, the route must return exactly HTTP 400 and `{"error":"ACTION_NOT_PUBLISHED"}`, omit `WWW-Authenticate`, make exactly one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, stop the request sequence at definition lookup, and make zero `execute_create_offer_v1` calls. The existing empty-array and malformed-definition cases remain in the same matrix.
- No route, runtime, action-engine, SQL, migration, or production configuration was changed. QA294 adds synthetic route-contract regression fixtures; these tests are not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1042 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538658786): **SUCCESS**. Browser job passed **328/328 Playwright tests**, including the QA294 matrix cases. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL integration job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, active-session cleanup, and prepared-transaction restoration checks.
- QIMA CodeQL #994 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538658800): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel on code commit `1c60b03340f2ed1c9eec9c204d54d3347bbe1f03`: **SUCCESS** (Preview only; no Production deployment).
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA294 final PR-head validation (9 November 2026)

- Final documentation HEAD `5b55f749e4fceb8727d543cb9a8ef7974da9b9bd` was revalidated after all three QA294 register updates.
- QIMA CI #1043 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538857184): **SUCCESS**; browser job passed **328/328 Playwright tests**. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, browser tests, and the isolated PostgreSQL integration/RLS/cleanup/prepared-transaction jobs all completed successfully.
- QIMA CodeQL #995 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538857062): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel on final documentation HEAD `5b55f749e4fceb8727d543cb9a8ef7974da9b9bd`: **SUCCESS** (Preview only; no Production deployment).
- The CI log contains expected negative-test PostgreSQL messages such as `IDEMPOTENCY_KEY_REUSE`, a deliberately missing relation, and prepared-transaction cleanup guards; the corresponding regression jobs completed **SUCCESS**. These are expected test assertions, not observed production incidents.


### QA295 — no fall-through from an invalid first PostgREST row (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `dab975ab38decc74102d4f4390d07a52a0e0d471`.
- Extended the existing invalid action-definition matrix with two multi-row fixtures: `[null, valid CREATE_OFFER definition]` and `[published PUBLISH_PRODUCT_REQUEST definition, published CREATE_OFFER definition]`.
- The runtime contract selects only the first PostgREST row (`Array.isArray(data) ? data[0] : data)); it must not scan later rows or fall through to a later valid definition when the first row is null or mismatched.
- Both scenarios must return exactly HTTP 400 with `{"error":"ACTION_NOT_PUBLISHED"}`, make one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, stop at definition lookup, and make zero `execute_create_offer_v1` calls. Existing empty-array, null-first-row, wrong-first-row, and valid single-row tests remain in the same contract suite.
- No application runtime, route, action-engine, SQL, migration, production data, or persistent configuration was changed. QA295 adds synthetic route-contract regression fixtures; they are not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1045 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42539491350): **SUCCESS**; Playwright passed **328/328**. npm ci, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, browser tests, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration all completed successfully.
- QIMA CodeQL #997 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42539491319): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel combined status on code commit `dab975ab38decc74102d4f4390d07a52a0e0d471`: **FAILURE** with `upgradeToPro=build-rate-limit` (Preview rate limit; not a GitHub build failure). No Preview READY status is confirmed for this commit; no Production deployment was performed.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA296 — CREATE_OFFER RPC JSON object result contract (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `5e06f5e5f793334f8bea023a3c9f9a5390956c23`.
- Added five malformed execution RPC fixtures: an array containing a valid-looking `succeeded` object, an empty array, a string primitive, a numeric primitive, and a boolean primitive.
- The engine's result normalizer rejects arrays and primitives; the public route must return HTTP 500 with exactly `{"error":"ACTION_FAILED"}`, never expose `ACTION_RESULT_INVALID` or a private sentinel, and make exactly one execution RPC call without retry. The test also verifies the expected request order and that `__rpcResultOverride` is not forwarded in `p_input`.
- The SQL function returns `jsonb`, which can represent non-object JSON values; QA296 verifies the stricter object-shaped application action-result contract at the HTTP boundary. No application implementation or SQL migration was changed.
- These are synthetic route-contract regressions, not evidence of a production incident or confirmed vulnerability. No Supabase production data, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed.
- QIMA CI #1047 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42547297646): **SUCCESS**; **328/328 Playwright tests passed**. npm ci, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, browser tests, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration all passed.
- QIMA CodeQL #999 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42547297568): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed (75/75 TypeScript files, 3/3 GitHub Actions files, 1/1 JavaScript file).
- Vercel on code commit `5e06f5e5f793334f8bea023a3c9f9a5390956c23`: **SUCCESS** (Preview only; no Production deployment).
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.

### QA297 — PostgreSQL CREATE_OFFER JSONB object and persistence contract (9 November 2026)

- Test location: `tests/sql/create-offer-runtime.sql`; final code commit: `169f02cde879df777e485a9928c20954462e6f25`.
- Added real PostgreSQL 16 integration assertions around the first successful `execute_create_offer_v1` call in the disposable CI fixture. The returned JSONB must be an object containing `status`, `executionId`, `objectType`, and `objectId`; status must be `succeeded`, object type `Offer`, and both identifiers must be UUID strings.
- The test resolves the returned execution and offer IDs and checks persistence coherence: `action_executions` is `COMPLETED` with matching `object_id` and `result`; `idempotency_keys` is `COMPLETED` with the same execution ID and result; exactly one `ACTION_SUCCEEDED` event carries the same payload/object ID/object type; and exactly one offer row matches the returned object ID and the fixture's demand, product, provider, quantity, price, and currency.
- An identical retry must replay the same object-shaped JSONB result and leave exactly one execution, idempotency row, offer, and success event for that tenant/key. The public SQL result shape is the actual migration contract (`status`, `executionId`, `objectType`, `objectId`); no nested `result` field was assumed.
- Superseded intermediate edit commit `019b99b46bdd8e6563f3f26d8a640f598815d5a7` triggered QIMA CI #1049: the browser/typecheck job succeeded, but the PostgreSQL job failed on an unterminated SQL string at line 1239. The SQL fixture was rebuilt from its original Git blob and the replacement was corrected in commit `169f02cde879df777e485a9928c20954462e6f25`; the final file is 483,887 characters versus the original 478,015, with the intended QA297 assertions only. The intermediate failure is retained here for an auditable history; it is not the final validation result.
- QIMA CI #1050 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555110306): **SUCCESS** on final code commit `169f02cde879df777e485a9928c20954462e6f25`. Both jobs succeeded: TypeScript, npm audit enforcement at the configured high threshold, Next.js production build, Chromium, **328/328 Playwright tests**, isolated PostgreSQL CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1002 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555110298): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel on final code commit `169f02cde879df777e485a9928c20954462e6f25`: **SUCCESS** (Preview only; no Production deployment).
- The QA297 SQL assertions ran only against the ephemeral PostgreSQL 16 CI fixture. No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.

### QA298 — CREATE_OFFER idempotency replay across committed PostgreSQL transactions (9 November 2026)

- Test location: `tests/sql/run-create-offer-integration.sh`; code commit: `f7a4f1dc42bc09e9165b95402cabe70f3f04164d`.
- Added an isolated PostgreSQL 16 integration scenario that performs the first successful `execute_create_offer_v1` call in one explicit transaction and commits it, then repeats the identical tenant/key/payload/business parameters from a second independent `psql` process and transaction.
- The runner captures `txid_current()` with each response and requires distinct transaction IDs, proving that the replay occurs after the first transaction commits rather than inside the same transaction. Both responses must be object-shaped JSONB and byte-for-byte equal; the second response must also match the persisted `idempotency_keys.result` value.
- Post-replay assertions verify exactly one completed idempotency row, one completed `action_executions` row, one offer preserving the original demand/product/provider/quantity/price/currency/conditions/market/geography/attributes/documentation values, and one `ACTION_SUCCEEDED` event whose payload/object identifiers match the stored result.
- QIMA CI #1052 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555882623): **SUCCESS**. Both jobs completed successfully. The browser/typecheck job passed npm ci, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium, and **328/328 Playwright tests**. The PostgreSQL job passed the full isolated CREATE_OFFER integration/concurrency suite including QA298, legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration. The PostgreSQL job log explicitly reports that QA298 replayed the exact persisted JSONB result from a distinct committed transaction and left one idempotency row, execution, offer, and success event.
- QIMA CodeQL #1004 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555882639): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `f7a4f1dc42bc09e9165b95402cabe70f3f04164d`: **FAILURE** with `Deployment rate limited — retry in 24 hours` (`api-deployments-free-per-day`). This is a Preview deployment quota limitation, not a GitHub Actions build failure; no Preview READY status is confirmed for this commit.
- The QA298 runner uses only the ephemeral PostgreSQL 16 CI service. No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change. The test is integration evidence for the fixture contract, not evidence of a production incident or confirmed vulnerability.

- Final documentation-updated PR HEAD `a0ffb73b063a4128d7781d9b123c2ec608ac6ecd` was revalidated by QIMA CI #1053 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42556138662): **SUCCESS**; both jobs passed, including **328/328 Playwright tests** and the PostgreSQL job log's explicit QA298 cross-transaction replay success.
- QIMA CodeQL #1005 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42556138558): **SUCCESS**; 75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned; results uploaded successfully.
- Vercel combined status on documentation-updated PR HEAD `a0ffb73b063a4128d7781d9b123c2ec608ac6ecd`: **FAILURE** with `Deployment rate limited — retry in 24 hours` (`api-deployments-free-per-day`). No Preview READY status is confirmed for this HEAD; this quota status does not change the successful GitHub CI or CodeQL results.

### QA299 — reject a changed CREATE_OFFER payload after a committed success (9 November 2026)

- Test location: `tests/sql/run-create-offer-integration.sh`; code commit: `e7c245bb99bb811815583076d2619888d45b9ae3`.
- Extended the PostgreSQL 16 integration runner immediately after QA298. QA298 first commits a successful CREATE_OFFER request; QA299 then starts a second independent `psql` process/transaction and reuses the same tenant/idempotency key with a changed effective payload (changed `p_input`, price, and conditions).
- The second transaction captures `txid_current()` and must differ from QA298's committed first transaction. The call must fail with `IDEMPOTENCY_KEY_REUSE`; a successful response or a different error fails the test.
- After rejection, the test compares the stored request hash and JSONB result byte-for-byte with their pre-attempt values. SQL assertions require exactly one completed idempotency row, one completed execution with the original input/result, one original offer at EUR 31.50 with the original conditions, and one `ACTION_SUCCEEDED` event matching the original result. No offer at the changed EUR 32.00 price may exist.
- QIMA CI #1055 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563738733): **SUCCESS**. Both jobs completed successfully. The browser job passed `npm ci`, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and **328/328 Playwright tests**. The PostgreSQL 16 integration job passed the full CREATE_OFFER suite; its log explicitly reports that QA299 rejected the changed payload in a distinct transaction with `IDEMPOTENCY_KEY_REUSE` and preserved the original hash/result/offer/execution/event without duplicates. Legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration also passed.
- QIMA CodeQL #1007 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563738705): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `e7c245bb99bb811815583076d2619888d45b9ae3`: **SUCCESS** (Preview only; no Production deployment).
- QA299 ran only against the ephemeral PostgreSQL 16 CI service. No application code, migration, Supabase production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. This integration regression is not evidence of a production incident or confirmed vulnerability. No Production deployment, PR merge, force-push, or branch-protection change.

- The QA299 register-update PR HEAD `4d51447707ceb16572cf490398792e91772f5cb3` was revalidated by QIMA CI #1056 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563946777): **SUCCESS**; both jobs passed, including **328/328 Playwright tests**, the PostgreSQL 16 CREATE_OFFER integration suite with QA299, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1008 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563946755): **SUCCESS**; 75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned; results uploaded successfully.
- Vercel combined status on register-update PR HEAD `4d51447707ceb16572cf490398792e91772f5cb3`: **SUCCESS** (Preview only; no Production deployment).


### QA300 — keep PostgREST execution-error metadata private at the CREATE_OFFER HTTP boundary (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `09bcb0fb333407dc0bba33cda5df0e4db2c28daf`.
- Extended the route test helper with optional PostgREST `details` and `hint` values, then added one regression covering both a documented domain conflict and an unknown internal RPC failure.
- For an execution RPC error whose message is exactly `IDEMPOTENCY_KEY_REUSE`, the route must return HTTP 400 with exactly `{"error":"IDEMPOTENCY_KEY_REUSE"}`; synthetic private details/hint sentinels and the upstream `XX000` code must not appear in the public body.
- For an unrecognized database error message, the route must return HTTP 500 with exactly `{"error":"ACTION_FAILED"}`; the internal message, private details/hint sentinels, and `XX000` must remain hidden. Both cases verify the normal authenticated request order through the single execution RPC and omit `WWW-Authenticate`.
- QIMA CI #1058 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42564383936): **SUCCESS**. Both jobs completed successfully. The browser job passed `npm ci`, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and **329/329 Playwright tests**, including QA300. The PostgreSQL 16 integration job passed the full CREATE_OFFER suite including QA299, legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1010 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42564383956): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `09bcb0fb333407dc0bba33cda5df0e4db2c28daf`: **SUCCESS** (Preview only; no Production deployment).
- QA300 uses synthetic route-contract fixtures; it does not establish a production incident or confirmed vulnerability. No application route/engine behavior, SQL migration, Supabase production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.

### QA301 — exact matching of public CREATE_OFFER SQL error messages (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `7e36a8dbdfe3cdeac57eee8d0100ca524a3da1b2`.
- Added a table-driven route regression for five near-miss variants of the documented `IDEMPOTENCY_KEY_REUSE` message: trailing whitespace, appended private text, lowercase spelling, an `XX000:` prefix, and a private prefix. The existing QA300 exact-message positive control remains the documented HTTP 400 case.
- Each near-miss must be treated as an unknown internal error and return HTTP 500 with exactly `{"error":"ACTION_FAILED"}`. The original message, SQLSTATE text, PostgREST `details`/`hint`, and private sentinels must not appear in the response.
- Each case verifies the authenticated request sequence through exactly one `execute_create_offer_v1` call, the expected Bearer header on every request, and absence of an incorrect `WWW-Authenticate` challenge. No route or engine implementation change was required; this is regression coverage for the existing exact `Set.has(candidate)` allowlist.
- QIMA CI #1060 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42569555067): **SUCCESS**. Both jobs completed successfully. The browser job passed `npm ci`, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and **330/330 Playwright tests**, including QA301. The PostgreSQL 16 job passed the full isolated CREATE_OFFER integration/concurrency suite, legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1012 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42569555068): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `7e36a8dbdfe3cdeac57eee8d0100ca524a3da1b2`: **SUCCESS** (Preview only; no Production deployment).
- QA301 uses synthetic route-contract fixtures. It does not establish a production incident or confirmed vulnerability. No application route/engine behavior, SQL migration, Supabase production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.

### QA302 — isolate action-definition RPC errors from execution-domain allowlisting (9 November 2026)

- Code commit: `cc7a61c410e40356730a58f7d4d719007e1d1486`; files: `lib/actions/runtime.ts` and `tests/e2e/create-offer-route-contract.spec.ts`.
- Source inspection found that `get_action_definition_v1` errors were previously rethrown using their raw `error.message`, while the route applied the same public SQL-domain allowlist to every exception. Therefore, an exact allowlisted message returned by the definition lookup could be classified like an execution-time domain conflict. This is a code-path classification issue; the synthetic regression does not establish that such a response occurred in production.
- The runtime now converts returned RPC errors and rejected definition-lookup calls to the internal `ACTION_DEFINITION_LOOKUP_FAILED` marker. It is intentionally absent from the public allowlist, so the route returns only HTTP 500 with `{"error":"ACTION_FAILED"}`. A valid missing/draft definition still follows the engine's separate `ACTION_NOT_PUBLISHED` contract.
- Added a paired route regression: a synthetic HTTP 400 from `get_action_definition_v1` carrying the exact message `IDEMPOTENCY_KEY_REUSE` plus private `details`/`hint` must return generic HTTP 500 and must not call `execute_create_offer_v1`; the same exact code from `execute_create_offer_v1` remains HTTP 400 with only `{"error":"IDEMPOTENCY_KEY_REUSE"}`. Both paths verify Bearer forwarding, request order, and non-disclosure of SQLSTATE/details/hints.
- QIMA CI #1062 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42573117014): **SUCCESS**. Browser job completed dependency installation, high-severity audit enforcement, TypeScript, Next.js production build, Chromium installation, and the Playwright suite successfully. PostgreSQL 16 integration job completed the CREATE_OFFER integration/concurrency suite, legacy messages RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration successfully.
- QIMA CodeQL #1014 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42573117107): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel Preview Comments check on code commit `cc7a61c410e40356730a58f7d4d719007e1d1486`: **SUCCESS**. This check alone is not treated as proof that a new Preview deployment is READY. No Production deployment was performed.
- QA302 uses synthetic route-contract fixtures and source inspection; it does not establish a confirmed production vulnerability or incident. No SQL migration, Supabase Production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.


### QA303 — mask rejected action-definition RPC transport failures (9 November 2026)

- Code commit: `f9e80a0039038e1a7df9ccc7b6f29787c3758a0e`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Extended the route test harness with a transport-failure fixture for `get_action_definition_v1`. The mocked fetch records the authenticated definition request and then rejects with `ECONNRESET: GET_ACTION_DEFINITION_TRANSPORT_PRIVATE_SENTINEL`, exercising the runtime's rejected-promise catch rather than a PostgREST HTTP error response.
- Added a regression asserting HTTP 500 with exactly `{"error":"ACTION_FAILED"}`, no `WWW-Authenticate` challenge, no transport/internal marker disclosure, exactly one definition RPC request, and zero `execute_create_offer_v1` calls. The existing QA302 paired regression remains the positive control: the exact `IDEMPOTENCY_KEY_REUSE` returned by the execution RPC remains HTTP 400.
- QIMA CI #1064 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42583578314): **SUCCESS**. Browser job passed `npm ci`, npm audit enforcement at the configured `high` threshold (0 advisories in the report), TypeScript, Next.js production build, Chromium installation, and **332/332 Playwright tests**, including QA303. PostgreSQL 16 integration job passed CREATE_OFFER integration/concurrency, legacy messages RLS, participant self-enrollment RLS, disposable database cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1016 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42583578317): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed (75/75 TypeScript files, 3/3 GitHub Actions files, 1/1 JavaScript file scanned).
- Vercel combined status on code commit `f9e80a0039038e1a7df9ccc7b6f29787c3758a0e`: **SUCCESS** (Preview status only; no Production deployment).
- QA303 uses a synthetic route-transport fixture and source inspection; it does not establish a production incident or confirmed vulnerability. No application runtime behavior, SQL migration, Supabase Production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.


### QA304 — lost CREATE_OFFER response after simulated commit and same-key replay (9 November 2026)

- Code commit: `9cdbad10542c604e2ada4c6941022125754fa721`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Extended the route mock with shared replay state. On the first execution-RPC request, the fixture records the exact RPC input and a successful result as committed, then rejects the fetch promise with `ECONNRESET: CREATE_OFFER_RESPONSE_LOST_AFTER_COMMIT_PRIVATE_SENTINEL`. The first HTTP request must return only HTTP 500 `{"error":"ACTION_FAILED"}`, without exposing the transport marker.
- The test asserts exactly one `execute_create_offer_v1` request on the first attempt (no automatic retry), one simulated committed creation, and no replay yet. A second HTTP request with the same idempotency key and identical effective RPC input returns the stored successful result; the fixture verifies that the serialized RPC input is identical and increments the replay count without incrementing the creation count.
- QIMA CI #1066 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42588763511): **SUCCESS**. Both jobs completed successfully. The browser job passed dependency installation, npm audit, TypeScript, Next.js production build, Chromium installation, Playwright browser tests, and audit-report upload. The PostgreSQL 16 job passed CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1018 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42588763612): **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- Final HEAD validation: QIMA CI #1067 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42589039499): **SUCCESS**; both browser/build and PostgreSQL 16 integration jobs completed all steps successfully. QIMA CodeQL #1019 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42589039491): **SUCCESS**; analysis and upload completed. Vercel combined status on this documentation HEAD: **SUCCESS** (Preview only).
- Vercel combined status on code commit `9cdbad10542c604e2ada4c6941022125754fa721`: **SUCCESS** (Preview status only; no Production deployment).
- QA304 is a deterministic synthetic route-level transport fixture. It models a durable commit followed by a lost response and a subsequent idempotent replay; it is not a real network fault injected into PostgreSQL and does not establish a production incident or vulnerability. QA298 remains the separate PostgreSQL 16 integration proof for cross-transaction replay. No application runtime change, SQL migration, Supabase Production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was modified. No Production deployment, PR merge, force-push, or branch-protection change.



### QA305 — reject changed payload after a lost committed CREATE_OFFER response (9 November 2026)

- Code commit: `3ba8c169c92d14548cd16f85755db1764d83c9b4`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Added a route-level regression that reuses QA304's shared replay fixture. The first request sends `price: 10` with a fixed idempotency key; the fixture records a successful committed result and then rejects the fetch promise with the post-commit response-loss sentinel. The first HTTP response must be HTTP 500 with only `{"error":"ACTION_FAILED"}`, and the fixture records exactly one simulated creation and no automatic retry.
- A second independent HTTP request uses the same idempotency key but changes the effective RPC input to `price: 12`. The fixture compares the complete serialized execution-RPC payload against the committed payload and returns the exact allowlisted `IDEMPOTENCY_KEY_REUSE` error. The route must return HTTP 400 with only `{"error":"IDEMPOTENCY_KEY_REUSE"}`; the original committed result remains unchanged and the creation count remains exactly one.
- Assertions cover the authenticated five-request sequence, one execution-RPC call per HTTP attempt, the same idempotency key, changed `p_input.price`, unchanged committed result, and non-disclosure of transport markers, SQLSTATE, and private details. The fixture's `replayCount` records the second idempotency lookup attempt, including the rejected changed-payload attempt; it is not a count of successful replays.
- QIMA CI #1069 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732484): **SUCCESS**. Both jobs completed successfully. Browser/build job passed `npm ci`, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and **334/334 Playwright tests**, including QA305. PostgreSQL 16 integration job passed CREATE_OFFER integration/concurrency, QA298 cross-transaction replay, QA299 changed-payload-after-commit rejection, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1021 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732447): **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `3ba8c169c92d14548cd16f85755db1764d83c9b4`: **SUCCESS** (Preview only; no Production deployment).
- The QA305 route fixture is synthetic: it models a durable commit followed by a lost HTTP response, then a same-key request with a changed payload. It does not inject a real network fault into PostgreSQL or establish a production incident/vulnerability. QA299 remains the separate PostgreSQL 16 integration proof for rejecting changed effective payload after a committed request. The CI workflow excludes `docs/**` via `paths-ignore`, so this documentation-only follow-up is covered by the successful code-commit validation above; it does not trigger a new CI/CodeQL run by itself. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, or application runtime behavior was modified. No Production deployment, PR merge, force-push, or branch-protection change.

### QA306 — replay equivalent numeric payloads after route normalization (9 November 2026)

- Code commit: `013b2affe99f40bf45889130bca65035b52f078f`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Extended the shared route replay fixture so a successful first execution records the simulated committed idempotency result, not only the response-loss path used by QA304/QA305. Added a regression using one fixed idempotency key: the first HTTP request sends `price: "10.00"`, `quantity: "01"`, and currency `" USD "`; the second sends numeric `price: 10`, `quantity: 1`, and currency `"USD"`. The route normalizes these representations before the execution RPC, so both complete RPC payloads must be identical.
- Expected route behavior: both requests return HTTP 200 with the exact same succeeded JSON result; one simulated creation is recorded, followed by one successful replay. The stored and replayed RPC inputs must match exactly, including the normalized currency, price, and quantity. This guards against rejecting semantically equivalent client representations as `IDEMPOTENCY_KEY_REUSE`.
- Validation limitation at record time: no QIMA CI or CodeQL workflow run was returned for code commit `013b2affe99f40bf45889130bca65035b52f078f`; the GitHub Actions runs query for this exact SHA was empty. The latest completed QIMA CI #1069 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732484) and CodeQL #1021 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732447) are **SUCCESS** on the prior QA305 code commit `3ba8c169c92d14548cd16f85755db1764d83c9b4`, but do not validate QA306. Accordingly, QA306 Playwright/CI and CodeQL results remain **NOT VERIFIED**; no success is inferred from the previous run.
- Vercel Preview for code commit `013b2affe99f40bf45889130bca65035b52f078f`: **READY** (deployment `dpl_BwdfJteunM6QxLcBScCW4aSQDDGg`, build completed in 46 seconds; Preview only, no Production deployment).
- This QA306 scenario is a synthetic route-level replay fixture and source-level normalization check. It does not prove PostgreSQL idempotency behavior by itself, establish a production incident, or confirm a vulnerability. QA298 remains the separate PostgreSQL 16 cross-transaction replay integration test. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, or production runtime behavior was modified. No Production deployment, PR merge, force-push, or branch-protection change.

### QA306 validation follow-up — 9 November 2026

- The contemporaneous QA306 entry above recorded CI/CodeQL as not verified because no workflow run was visible for code commit `013b2affe99f40bf45889130bca65035b52f078f` at that moment. A subsequent PR-head validation completed on commit `929392b2f3a6ef04994d1fb9c917833e84d7136b`, which contains the QA306 code commit: QIMA CI #1070 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42602676184) **SUCCESS**, including **335/335 Playwright tests** and the PostgreSQL 16 integration job; QIMA CodeQL #1022 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42602676156) **SUCCESS**, with analysis results uploaded (75/75 TypeScript, 3/3 GitHub Actions, 1/1 JavaScript files). This follow-up supersedes the earlier NOT VERIFIED status for QA306 while preserving the original time-of-check note.
- QA306 remains a synthetic route-level normalization/replay test; QA298 remains the separate PostgreSQL 16 cross-transaction replay integration proof. No production incident or vulnerability is inferred. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.

### QA307 — replay omitted optional fields against explicit null defaults (9 November 2026)

- Code commit: `df9d554f2fd24ee223585de2592b5100e4cd6919`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Added a route-level idempotency regression using one fixed key. The first request omits optional offer fields; the second sends explicit `null` for `pricingModel`, `conditions`, `market`, `geography`, `attributes`, `documentationStatus`, `lifecycle`, and `offerType`.
- The route's current normalization contract maps both representations to the same effective values: `pricingModel: "fixed"`, nullable fields to `null`, `attributes: {}`, `lifecycle: "draft"`, and `offerType: "supplier_offer"`. The test compares the complete serialized execution-RPC inputs and requires the same successful JSON result, one simulated creation, and one replay.
- Validation at this documentation update: QIMA CI #1071 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690939) and CodeQL #1023 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690954) were still **IN PROGRESS**. No Playwright, PostgreSQL, or CodeQL success is claimed for QA307 until those runs complete. The route fixture is synthetic and does not by itself establish PostgreSQL idempotency behavior, a production incident, or a vulnerability. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.

### QA307 validation follow-up — 9 November 2026

- Code commit `df9d554f2fd24ee223585de2592b5100e4cd6919` was validated on the PR branch. QIMA CI #1071 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690939): **SUCCESS**; browser/build job passed `npm ci`, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright tests**, including QA307. The PostgreSQL 16 integration job also completed successfully, including CREATE_OFFER integration/concurrency, QA298/QA299, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1023 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690954): **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `df9d554f2fd24ee223585de2592b5100e4cd6919`: **SUCCESS** (Preview only; no Production deployment).
- QA307 is a synthetic route-level test of omitted-versus-null normalization and replay fixture behavior. It does not by itself prove PostgreSQL idempotency semantics, establish a production incident, or confirm a vulnerability. Existing QA298/QA299 remain the PostgreSQL 16 integration proofs for replay and changed-payload rejection. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.



### QA308 — PostgreSQL JSONB object-key order and idempotency replay (9 November 2026)

- Code commit: `fbb8def4f75c04e979d55c8c0ea6f4be9046a481`; test file: `tests/sql/run-create-offer-integration.sh`.
- Added a PostgreSQL 16 integration regression using two independent `psql` processes and two distinct committed transactions. The first creates an offer with nested JSONB keys in one order; the second reuses the same tenant/idempotency key and the same semantic values while reversing both top-level and nested key order in `p_input` and `p_attributes`.
- The test requires distinct transaction IDs, an identical replay JSONB result, the stored result matching the replay, and the persisted request hash matching the canonical `md5(jsonb_build_object(...)::text)` for the full effective request.
- Persistence assertions require exactly one completed idempotency row, one completed execution, one offer with the expected fields/JSONB attributes, and one matching `ACTION_SUCCEEDED` event. The runner log explicitly reports: “QA308 JSONB key order was canonicalized recursively; a distinct committed transaction replayed the exact result with one idempotency row, execution, offer, and success event”.
- Validation on code commit `fbb8def4f75c04e979d55c8c0ea6f4be9046a481`: QIMA CI #1073 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42616938896) **SUCCESS**. Browser/build job passed dependency installation, npm audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. PostgreSQL 16 integration job **SUCCESS**, with QA308 explicitly present in the job log and all existing CREATE_OFFER, concurrency, RLS and cleanup checks successful. QIMA CodeQL #1025 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42616938912) **SUCCESS**, with JavaScript/TypeScript analysis completed and results uploaded.
- Vercel combined status for the code commit: **SUCCESS** (Preview only; no Production deployment).
- QA308 is an isolated PostgreSQL 16 integration test of PostgreSQL JSONB canonicalization and the existing request-hash contract. It does not establish a production incident or confirm a vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA308 final-head validation follow-up — 9 November 2026

- Documentation commit: `f9dd1ae25745cabcb01460374921088d019bea9c`.
- The final documentation HEAD was independently validated: QIMA CI #1074 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42617302829) **SUCCESS**. Both jobs completed successfully. The browser/build job passed dependency installation, npm audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job passed QA308, CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1026 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42617302810) **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- Vercel combined status on the documentation HEAD: **SUCCESS** (Preview only; no Production deployment).
- This follow-up validates the documentation synchronization after the QA308 code commit. It does not infer a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA309 — JSONB array order remains significant — 9 November 2026

- Added an isolated PostgreSQL 16 integration scenario to `tests/sql/run-create-offer-integration.sh`.
- The first committed transaction creates an offer using `p_input` arrays `["red","blue"]` and nested `[1,2]`, with matching ordered arrays in `p_attributes`.
- A second independent transaction reuses the same tenant/idempotency key but reverses both top-level and nested array values in `p_input` and `p_attributes`.
- Expected contract: the changed effective JSONB payload is rejected with `IDEMPOTENCY_KEY_REUSE`; the second transaction must not create or mutate an offer.
- Assertions preserve the original request hash and JSONB result, require distinct transaction IDs, and verify exactly one completed idempotency row, one completed execution with the original input, one offer with the original ordered arrays, and one `ACTION_SUCCEEDED` event.
- This is a PostgreSQL integration regression test. Its CI execution and CodeQL status are **pending at the time of this documentation commit**; no pass is claimed until GitHub reports results for the exact code commit.
- The test distinguishes JSONB object-key canonicalization (QA308) from array-order semantics. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA309 final validation follow-up — 9 November 2026

- Validated PR head `efde24b491e0ba70c0d38394f9f34f8bfe439e67`, which contains the QA309 test commit and all three QA309 register entries.
- QIMA CI #1076 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42626222108) **SUCCESS**. The browser/build job passed npm installation, dependency audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job passed; its log explicitly reports that QA309 rejected the changed top-level and nested JSONB array order with `IDEMPOTENCY_KEY_REUSE` in a distinct committed transaction and preserved the original hash, result, offer, execution and success event. All legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup and QA266/QA267 prepared-transaction checks also passed.
- QIMA CodeQL #1028 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42626222113) **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- The `Vercel Preview Comments` check completed successfully. The separate combined `Vercel` status remained **FAILURE** with `api-deployments-free-per-day`; a READY Preview deployment for this final HEAD is therefore not claimed.
- This validation is tied to the exact PR head above. Although the follow-up commits only change documentation, this PR also contains non-documentation code changes, so GitHub's pull_request path filtering still queues CI and CodeQL on the updated PR head. The runs for documentation HEAD `02cc31056308acbe61ff509fccc0b922bfaf48d8` were observed queued after this follow-up; they are distinct from the completed validation of `efde24b491e0ba70c0d38394f9f34f8bfe439e67` recorded above.
- QA309 is a disposable PostgreSQL 16 regression test, not evidence of a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA310 — numeric-scale idempotency characterization — 10 November 2026

- Added a disposable PostgreSQL 16 integration scenario for three isolated same-key retries: a numeric value inside p_input (1 versus 1.0), p_price (21 versus 21.0), and p_quantity (2 versus 2.0).
- The characterization asserts PostgreSQL JSONB equality for 1 and 1.0, compares the corresponding JSONB text/hash representations, and exercises execute_create_offer_v1 with each changed representation after the first request has committed.
- The current implementation is expected to distinguish the text-based effective-request hashes and return IDEMPOTENCY_KEY_REUSE for each changed-scale retry, while preserving the original hash, result, completed execution, offer, and success event. This is a characterization of the current implementation, not a claim that the behavior is the desired product contract.
- Whether mathematically equal numeric values with different display scales should be treated as the same idempotent request remains an API/product-contract decision. No runtime normalization or migration change is included pending that decision.
- Code test commit: 47f07ad59637d81e92c0ce2c842fc1b1562c3a0f. QIMA CI #1080 and CodeQL #1032 were queued/in progress when this entry was added; no pass is claimed until their results are checked for the exact commit.
- QA310 uses only the disposable PostgreSQL integration database. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA310 final validation follow-up — 10 November 2026

- Validated code commit 47f07ad59637d81e92c0ce2c842fc1b1562c3a0f.
- QIMA CI #1080 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642188204) **SUCCESS**. TypeScript, production build, dependency audit, Chromium and **336/336 Playwright tests** passed. The disposable PostgreSQL 16 integration job passed all CREATE_OFFER, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction checks. Its log explicitly reports the QA310 assertions: JSONB 1 and 1.0 compare equal, while the current text-based request hash distinguishes the p_input, price, and quantity numeric scales; all three changed-scale retries were rejected and the original records remained unchanged.
- QIMA CodeQL #1032 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642188233) **SUCCESS**; JavaScript/TypeScript analysis and result upload completed.
- The combined Vercel status for the code commit was **FAILURE**. A READY Preview for this commit is not claimed; the combined-status response did not provide a failure reason.
- The PostgreSQL log also shows pre-existing QA111 and QA112 coverage for numeric scale in p_input/p_attributes and p_price/p_quantity. QA310 is therefore a consolidated cross-check with explicit snapshots of all three first results, not a newly discovered production issue or a claim that the underlying numeric-scale behavior was previously untested.
- The current behavior remains a contract question: whether mathematically equal numbers with different display scales should share an idempotency key. No runtime normalization is introduced without an explicit API/product decision.
- QA310 was executed only against the disposable PostgreSQL 16 CI service. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA310 final PR-head verification — 10 November 2026

- Final documentation HEAD 0eb019da64b5479cc8a192a849863505112ed30a passed QIMA CI #1081 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642690279) **SUCCESS** and QIMA CodeQL #1033 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642690438) **SUCCESS**.
- CI #1081 completed TypeScript, dependency audit, Next.js production build, Chromium, **336/336 Playwright tests**, the full disposable PostgreSQL 16 CREATE_OFFER integration/concurrency suite (including QA310), legacy-message RLS, participant self-enrollment RLS, prepared-transaction restoration, and disposable-resource cleanup.
- The PostgreSQL job log explicitly reports the QA310 result: JSONB 1 and 1.0 compare equal, but the current text-based effective-request hash distinguishes p_input, price, and quantity scale; all three changed-scale retries were rejected and the first hashes/results/executions/offers/events remained unchanged.
- CodeQL #1033 completed JavaScript/TypeScript analysis and uploaded its results successfully.
- The combined Vercel status for this HEAD is **FAILURE** with upgradeToPro=build-rate-limit; no READY Preview or Production deployment is claimed.
- This validation is tied to the exact HEAD above. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.

 
### QA311 — PostgreSQL JSONB duplicate object keys and idempotency replay (10 November 2026)

- Added a disposable PostgreSQL 16 integration regression to tests/sql/run-create-offer-integration.sh. The first committed transaction passes duplicate top-level and nested object keys in both p_input and p_attributes; the second independent committed transaction reuses the same tenant/idempotency key with the equivalent canonical objects after duplicate keys have been removed.
- The duplicate-key inputs use conflicting earlier values followed by the intended final values. PostgreSQL JSONB parsing retains the last value for each duplicate object key, including nested objects. The test first asserts that each duplicate-key JSONB value is IS NOT DISTINCT FROM its canonical equivalent.
- The replay must return the exact original JSONB result. Assertions verify distinct transaction IDs, the canonical full-request hash, one completed idempotency row, one completed execution with canonical input, one offer with canonical attributes, and one matching ACTION_SUCCEEDED event.
- The PostgreSQL 16 integration step in QIMA CI #1083 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648204220) completed SUCCESS. Its job log explicitly reports: “QA311 JSONB duplicate top-level and nested object keys collapsed to the last values; a distinct committed transaction replayed the canonical result with one idempotency row, execution, offer, and success event.” All other steps in that PostgreSQL integration job also passed.
- QIMA CodeQL #1035 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648204152) completed SUCCESS and uploaded its JavaScript/TypeScript analysis results.
- At the time of this entry, the browser/build job in QIMA CI #1083 had passed npm ci, dependency audit enforcement, TypeScript, and the Next.js production build; Playwright Chromium installation was still IN PROGRESS, so the overall QIMA CI run was not yet complete and no Playwright pass is claimed for QA311.
- The combined Vercel status for code commit 8bf95b09ed231bb4ebd3dada171debd901e45c4c was SUCCESS (Preview status only; no Production deployment).
- QA311 characterizes PostgreSQL JSONB duplicate-key parsing and the existing idempotency hash contract. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA311 final PR-head validation follow-up — 10 November 2026

- Final PR documentation HEAD: 61d10d6a145aad3aef7cf14609220630d1bf758e, containing QA311 code commit 8bf95b09ed231bb4ebd3dada171debd901e45c4c and all three QA311 register entries.
- QIMA CI #1084 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648687673) **SUCCESS**. The browser/build job passed npm ci, dependency audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job also completed **SUCCESS**; its log explicitly confirms that duplicate top-level and nested keys in p_input and p_attributes collapsed to the final JSONB values and the second committed transaction replayed the original result with exactly one idempotency row, execution, offer, and success event. Legacy-message RLS, participant self-enrollment RLS, prepared-transaction restoration and disposable-resource cleanup all passed.
- QIMA CodeQL #1036 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648687141) **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- The earlier code-commit QIMA CI #1083 was cancelled after the PR head advanced; its PostgreSQL integration job had already completed successfully with the QA311 log result. Final validation is provided by the complete CI #1084 run above.
- The combined Vercel status for final documentation HEAD 61d10d6a145aad3aef7cf14609220630d1bf758e is **FAILURE** with api-deployments-free-per-day; no READY Preview for this final HEAD is claimed.
- QA311 is an isolated PostgreSQL 16 integration regression. It characterizes JSONB duplicate-key parsing and the existing idempotency contract; it does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA312 — duplicate JSONB keys inside array objects and array-order preservation (10 novembre 2026)

- Added a disposable PostgreSQL 16 integration regression in `tests/sql/run-create-offer-integration.sh`. The first committed transaction supplies duplicate keys inside objects contained in arrays in both `p_input` and `p_attributes`, including duplicate keys in nested objects within the array elements. A second independent committed transaction reuses the same idempotency key with the equivalent canonical arrays after duplicate keys are removed.
- Explicit JSONB assertions confirm PostgreSQL keeps the last value for each duplicate key inside array objects, including nested object paths. The test also verifies that array lengths and element order remain unchanged: the second item remains at index 1, while canonical values at index 0 and nested paths are preserved.
- The replay must return the exact original result. Assertions verify distinct transaction IDs, identical canonical full-request hash and stored result, one completed idempotency row, one completed execution, one offer with canonical attributes, and one matching `ACTION_SUCCEEDED` event.
- QIMA CI #1086 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42655729153) completed **SUCCESS** on code commit `f3a00d93e8d248fa237607c45e96d89a21637bce`. The browser/build job passed dependency installation and audit, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job completed successfully; its log explicitly reports: “QA312 JSONB duplicate keys inside array objects collapsed to the last values; a distinct committed transaction replayed the canonical result with one idempotency row, execution, offer, and success event.” All RLS, disposable database cleanup and prepared-transaction restoration checks also passed.
- QIMA CodeQL #1038 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42655729107) completed **SUCCESS**. JavaScript/TypeScript analysis results were successfully uploaded and processed.
- QA312 characterizes PostgreSQL JSONB parsing and the existing idempotency contract. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA312 final PR-head validation follow-up — 10 novembre 2026

- Final QA312 documentation HEAD before this follow-up: `916ecdfec465b26186525b9b360c0c0c41aa440c`, containing the QA312 PostgreSQL integration regression and all three register entries.
- QIMA CI #1087 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656169558) completed **SUCCESS** on that HEAD. The browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job completed **SUCCESS** and its log explicitly confirms QA312: duplicate JSON object keys inside arrays in `p_input` and `p_attributes` collapsed to PostgreSQL JSONB's last-value representation; a second committed transaction replayed the exact result without duplicates. Legacy-message RLS, participant self-enrollment RLS, prepared-transaction restoration and disposable-resource cleanup also passed.
- QIMA CodeQL #1039 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656169446) completed **SUCCESS**; JavaScript/TypeScript analysis results were uploaded and processing completed.
- GitHub's `Vercel Preview Comments` check was successful on the QA312 documentation HEAD; this is not treated as proof of a READY deployment. No Production deployment was performed.
- This is test evidence from disposable CI infrastructure. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA311/QA312 regression-retention correction and final validation — 10 novembre 2026

- A review of the QA312 code diff identified that the first QA312 edit had replaced the final QA311 shell-test block instead of appending a second block. This was corrected in commit `0b37a18100ad77011efcf16604c5d1a726bfddcf`: the original QA311 block was restored from the verified pre-QA312 version, and the QA312 array-object block remains immediately after it. The current integration runner contains exactly one `# QA311:` section and one `# QA312:` section, with both distinct idempotency fixtures present.
- QIMA CI #1089 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656754738) completed **SUCCESS** on code commit `0b37a18100ad77011efcf16604c5d1a726bfddcf`. The PostgreSQL 16 integration log explicitly reports both QA311 and QA312 success: duplicate top-level/nested object keys replayed canonically, and duplicate keys inside array objects replayed canonically while array order assertions passed. The browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. All RLS, disposable database cleanup and prepared-transaction restoration checks passed.
- QIMA CodeQL #1041 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656754755) completed **SUCCESS**; JavaScript/TypeScript analysis results were uploaded and processing completed.
- Intermediate documentation-head workflows QIMA CI #1088 and CodeQL #1040 were superseded when the QA311-retention correction advanced the branch; final code validation is provided by #1089 and #1041 above.
- QA311 and QA312 are disposable PostgreSQL 16 regression tests. They characterize JSONB parsing and the existing idempotency contract; they do not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA313 duplicate-key final JSON null versus absent properties — 10 novembre 2026

- Added a disposable PostgreSQL 16 integration regression in tests/sql/run-create-offer-integration.sh. The first committed transaction supplies duplicate top-level and nested keys in both p_input and p_attributes, with the final occurrence explicitly set to JSON null. A second independent committed transaction uses the equivalent canonical objects with those properties explicitly set to null; it must replay the exact original result.
- The test then retries the same idempotency key twice: once with the affected p_input properties omitted and once with the affected p_attributes properties omitted. Both changed effective payloads must raise IDEMPOTENCY_KEY_REUSE. Assertions preserve the original request hash/result, one completed idempotency row, one completed execution, one offer, and one matching ACTION_SUCCEEDED event.
- Initial QIMA CI #1091 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42664310333) failed in the PostgreSQL fixture with UNAUTHENTICATED because the first version ran the changed-payload RPC attempts from a superuser verification DO block without setting the authenticated JWT/role context. This was a test-harness setup defect; it was not evidence of an application authentication regression or vulnerability.
- Corrected in commit 9df672adcfab725f1915eeed90bd19c46e45cefa: changed-payload retries now execute in a separate psql session with SET request.jwt.claim.sub and SET ROLE authenticated; read-only state verification remains in a separate privileged session. The runner retains exactly one QA311, QA312, and QA313 section.
- Final QIMA CI #1092 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42664780990) completed SUCCESS on code commit 9df672adcfab725f1915eeed90bd19c46e45cefa. The PostgreSQL 16 integration log explicitly reports QA313 success: duplicate keys ending in JSON null replay as canonical explicit-null properties, while same-key retries omitting those properties are rejected and the original records remain unchanged. The browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation and 336/336 Playwright tests. RLS, disposable database cleanup and prepared-transaction restoration checks passed.
- QIMA CodeQL #1044 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42664781025) completed SUCCESS; JavaScript/TypeScript analysis results were uploaded and processing completed.
- GitHub's Vercel status on the code HEAD reported the Free-plan api-deployments-free-per-day rate limit. This is recorded as a Preview quota limitation, not a code-test failure; no Production deployment was performed.
- QA313 characterizes PostgreSQL JSONB duplicate-key handling and the existing idempotency contract. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.



### QA314 duplicate JSON keys ending in JSON null inside JSONB array objects — 10 novembre 2026

- Added a disposable PostgreSQL 16 integration regression for duplicate keys ending in JSON null inside array objects in both `p_input` and `p_attributes`. A separate committed transaction with the canonical explicit-null array objects must replay the exact original result; same-key retries omitting either property must raise `IDEMPOTENCY_KEY_REUSE`.
- The test asserts recursive last-key-wins JSONB canonicalization, explicit-null values, array length/order, distinct transaction IDs, canonical request hash, persisted result, and exactly one idempotency row, execution, offer, and matching success event.
- Code commit: `b7b78136215a030fd4372ff7155062a74d3549f1`. QIMA CI #1094 and CodeQL #1046 were **QUEUED** for this SHA when recorded. Their results are intentionally not inferred from earlier QA313 runs.
- The Preview Comments check succeeded; the separate Vercel deployment status remained pending. No Production deployment or production database changes.


### QA314 CI validation follow-up — 10 November 2026

- Rechecked PR #26 at head `ca58aab40eae3dfd640658cb54ee235a3f78d579`: the pull request remains open, draft, and mergeable; comparison against `main` reports 1,208 commits ahead and 0 behind.
- QIMA CI #1096 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42673637723) reports a workflow-run conclusion of **failure**. Its jobs endpoint lists only one job, `Typecheck, audit, build and browser tests`, and that job completed **success**. All listed steps succeeded, including dependency installation/audit enforcement, TypeScript, Next.js build, Chromium installation, and **336/336 Playwright tests**. The job log contains no PostgreSQL integration step. The run-level failure is not explained by the available job payload/log; it is not attributed to QA314.
- QIMA CodeQL #1048 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42673637105) completed **success**.
- Workflow comparison: `.github/workflows/ci.yml` on `main` (blob `ba9841190e2c1a518c7ab43ae0c100391d6ff1bc`) does not define `postgres-integration`; the PR branch version (blob `c70e3a8f21e2fda410ae3b892265a6dbff73da7b`) does define that job. Nevertheless, the observed pull-request run #1096 did not include it. The available evidence establishes the omission, but does not by itself prove GitHub's workflow-version resolution as the cause.
- The current connected GitHub actions interface exposes workflow/run reads and reruns but no `workflow_dispatch` operation. The local execution container also has no `psql`, Docker, or Podman, and outbound DNS to GitHub is unavailable; QA314 could not be run independently in this environment.
- **QA314 remains NOT VALIDATED.** The 336 browser tests do not validate the PostgreSQL fixture. Do not treat the queued/omitted integration job or the run-level status as a PostgreSQL result. Next step: an authorized repository maintainer should dispatch the existing CI workflow against `fix/create-offer-status-contract` if the branch-specific workflow is selectable, or arrange a separately reviewed base-workflow change that makes the PostgreSQL job available to PR runs; then verify the exact SHA and the `CREATE_OFFER PostgreSQL integration tests` job.
- Vercel's combined commit status remains **failure** because of the Free-plan `api-deployments-free-per-day` quota; this is a Preview limitation, not a test result.
- No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change. No production vulnerability is inferred from these synthetic/CI observations.


### QA314 PostgreSQL validation and fixture correction — 10 November 2026

- The first QA314 PostgreSQL execution was obtained in QIMA CI #1097 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42686629868) on documentation commit `0a3423e09cccedc8a70c395070dacc95038f4e81`. The integration job exposed a test-fixture SQL syntax error, `syntax error at or near "s"`, in the first changed-payload assertion. Two `RAISE EXCEPTION` messages contained the unescaped apostrophe in `array object's`, which prematurely terminated the SQL string literal. This was a test-harness defect, not an application/runtime failure or a production vulnerability.
- Fixed exactly two occurrences in `tests/sql/run-create-offer-integration.sh` in code commit `c4b7b348978d29a13205dec3a003c66e0d026e46`, replacing the apostrophe-containing wording with SQL-safe wording. The QA314 scenario and its four negative retries were otherwise unchanged.
- Final QIMA CI #1098 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42687022991) completed **SUCCESS** on exact code SHA `c4b7b348978d29a13205dec3a003c66e0d026e46`. Both jobs passed: `Typecheck, audit, build and browser tests` and `CREATE_OFFER PostgreSQL integration tests`. The PostgreSQL 16.15 log explicitly confirms QA311, QA312, QA313, and QA314; QA314's canonical explicit-null replay succeeded, all absent-property retries were rejected, array order and original records were preserved. The remaining RLS, disposable-database cleanup, prepared-transaction restoration, and self-enrollment checks also passed.
- The browser/build job passed npm installation and audit enforcement, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright tests**. QIMA CodeQL #1050 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42687023024) completed **SUCCESS**.
- This supersedes the earlier QA314 follow-up note that manual dispatch or local PostgreSQL execution would be needed: the subsequent PR workflow run #1097 did include the PostgreSQL integration job, exposed the fixture quoting defect, and #1098 validated the correction. No manual dispatch was performed.
- QA314 is now **VALIDATED on disposable PostgreSQL 16.15 CI infrastructure**. This is regression-test evidence about the test fixture and existing JSONB/idempotency contract; it does not establish a production incident or vulnerability.
- No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### Source-only SECURITY DEFINER and EXECUTE ACL review — 10 November 2026

- Read-only source audit completed against all 18 SQL migrations on PR HEAD `a1152a8831509e472f2817d7c46743e7bbf99f82`, plus the relevant Decision Tree call sites. Detailed inventory: [SECURITY_DEFINER_ACL_SOURCE_AUDIT_2026-11-10.md](SECURITY_DEFINER_ACL_SOURCE_AUDIT_2026-11-10.md).
- Source-level ACL hardening candidates: `current_profile_actor_id()` and `execute_create_offer_v1(...)` have no explicit PUBLIC revoke in the reviewed defining/restriction migrations; `dt_select_product_master(...)` is SECURITY INVOKER and its migration grants authenticated without an explicit PUBLIC revoke. `create_offer_v1(...)` is revoked from PUBLIC/authenticated by the branch migration, but no explicit direct-`anon` revoke is present. These are not effective-ACL findings: CREATE OR REPLACE preserves ACLs, grants are additive, and default privileges may be configured outside the repository.
- The reviewed SECURITY DEFINER functions pin `search_path = public`; their application relations and `auth.uid()` calls are schema-qualified. Whether `anon` or `authenticated` can CREATE in `public` is unverified. No search_path or ACL change was made.
- Read-only live catalog verification was blocked before query execution: Supabase `execute_sql` returned PostgreSQL `28P01` for `postgres`, and `list_tables` returned `28P01` for `supabase_read_only_user`. No catalog rows were returned and no data was changed.
- Baseline on exact reviewed HEAD: QIMA CI #1099 **SUCCESS** (both browser/build and PostgreSQL integration jobs; Playwright **336/336**), CodeQL #1051 **SUCCESS**, combined Vercel status **SUCCESS**. These checks do not validate live ACLs.
- No production vulnerability is confirmed. Next gate: restore authorized read-only catalog access or have a project maintainer run the catalog-only SELECTs in the detailed report; only then decide whether a minimal new migration and isolated positive/negative tests are justified.
- No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### Explicit RPC EXECUTE ACL hardening prepared — 10 November 2026

- Rechecked the defining migrations and authenticated call sites for `current_profile_actor_id()`, `dt_select_product_master(uuid, uuid, uuid)`, and `execute_create_offer_v1(...)`. Each has an authenticated caller, while the branch migrations do not explicitly revoke the PostgreSQL default PUBLIC EXECUTE privilege. No `ALTER DEFAULT PRIVILEGES` statement exists in the 18 reviewed migrations. This is a clean-install source configuration observation, not proof of the live project's effective ACL.
- Added `supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql`: revoke all function privileges from PUBLIC and `anon`, then explicitly grant EXECUTE to `authenticated` for those three entry points. The low-level `create_offer_v1(...)` remains unchanged pending effective owner/catalog verification.
- Added `tests/sql/function-execute-acl-regression.sql` and `tests/sql/run-function-execute-acl-regression.sh`. The runner is restricted to the dedicated loopback `qima_test` CI URL, creates a separate `qima_acl_test` database, applies the migration twice, verifies PUBLIC/anon denial and authenticated EXECUTE, and cleans up its temporary database and any roles it created.
- Added the regression runner to the PostgreSQL integration job. This test validates the migration on disposable PostgreSQL; it does not validate the live Supabase catalog.
- Live Supabase catalog verification remains blocked by PostgreSQL `28P01`; effective Production ACLs remain unverified. No Production vulnerability is confirmed and the migration has not been applied to Supabase Production.
- Validation on this code commit: **pending**. No Supabase Production data/schema/RLS/grants/secrets, production migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### RPC EXECUTE ACL regression follow-up — 10 November 2026

- Code commit `4f768c103aecb50a7a53a939021020af072c228f` added the additive ACL migration and disposable PostgreSQL runner. QIMA CI #1102 passed the existing CREATE_OFFER PostgreSQL integration suite, TypeScript, dependency audit, Next.js build, and **336/336 Playwright**; CodeQL #1054 and Vercel Preview Comments also passed.
- The new ACL regression step failed at its post-migration `regprocedure` lookup because the test identity string for `execute_create_offer_v1(...)` omitted one `text` argument. The actual migration signature is 18 arguments and the migration itself was applied twice in the disposable database before the assertion error.
- Corrected the test identity to the exact 18-argument signature and added an explicit assertion that PostgreSQL's fresh-database default PUBLIC EXECUTE ACL is present before the migration, as well as the simulated direct `anon` grant.
- The failure is confined to the regression test's signature string. It does not establish a production ACL issue. Live Supabase catalog access remains blocked by PostgreSQL `28P01`; no Production ACL/migration/data change was made.
- Corrected regression validation: **pending next CI run**.


### RPC EXECUTE ACL regression follow-up — CI #1103

- QIMA CI #1103 passed the existing CREATE_OFFER PostgreSQL integration suite and the TypeScript/audit/build/browser job (**336/336 Playwright**); CodeQL #1055 and Vercel Preview Comments passed.
- The new ACL test stopped before applying the migration because its inserted precondition used an incomplete `DO $` delimiter. The function identity string correction from the prior attempt was present; this second failure is another test-fixture formatting defect, not a live ACL finding.
- Changed the precondition delimiter to `$acl$` and retained the explicit default-PUBLIC and direct-`anon` precondition assertions. The migration was not executed in CI #1103; end-to-end validation remains pending.
- Live Supabase catalog access remains blocked by PostgreSQL `28P01`. No Production ACL/data/schema/migration change was made.


### RPC EXECUTE ACL hardening — CI validation complete — 10 November 2026

- PR code HEAD `227a6dc95d521addb6f75fd1ae6cbe4e644864ea`: QIMA CI #1104 **SUCCESS**, CodeQL #1056 **SUCCESS**; the browser/build job passed **336/336 Playwright**.
- The disposable PostgreSQL ACL step logged `function EXECUTE ACL regression PASS`: PostgreSQL default PUBLIC EXECUTE and a direct anon grant were removed for `current_profile_actor_id()`, `dt_select_product_master(uuid, uuid, uuid)`, and `execute_create_offer_v1(...)`; authenticated retained an explicit EXECUTE grant. The migration was applied twice in the dedicated temporary `qima_acl_test` database, and the runner completed successfully.
- Existing CREATE_OFFER PostgreSQL integration, legacy-message RLS, participant self-enrollment RLS, prepared-transaction cleanup/restore, and database cleanup checks all passed. CI #1102 and #1103 fixture failures are documented above and superseded by #1104.
- Vercel Preview Comments passed, but the combined Vercel status remains failed due to `upgradeToPro=build-rate-limit`; no Preview READY is confirmed.
- This is disposable-CI migration evidence only. Live Supabase catalog access still fails with PostgreSQL `28P01`, so effective Production ACLs remain unverified; no Production vulnerability is confirmed and the migration has not been applied to Supabase Production.
- Next gate: authorized read-only live ACL/owner/schema-privilege output and human review before any Production migration. No Supabase Production data/schema/RLS/grants/secrets, production migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### Authenticated-only helper RPC anon ACL hardening — 10 November 2026

- Added branch-only migration `supabase/migrations/20261110080000_harden_authenticated_helper_anon_acl.sql` to reassert authenticated-only EXECUTE privileges for four helpers: `dt_has_tenant_access(uuid)`, `dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)`, `dt_publish_product_request(uuid, uuid)`, and `is_message_participant(uuid, uuid, uuid)`.
- Source call-site review found no anonymous application caller: tenant access is used by RLS policies scoped to authenticated; Decision Tree answer submission and product-request publication authenticate the current user before the RPC; the legacy-message participant helper is used by the authenticated message RLS path. This is a source-level caller review, not proof of effective live ACLs.
- Extended `tests/sql/function-execute-acl-regression.sql` from three to seven function signatures. The disposable fixture establishes default PUBLIC EXECUTE plus a direct `anon` grant, applies both ACL migrations twice, and asserts no effective PUBLIC/anon EXECUTE and an explicit authenticated grant for all seven functions.
- Code commit `3357a3bf5cf65de0d5dd4d6be051126ce1f71bf5` is on PR #26. QIMA CI run [#1106](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710206948) and CodeQL run [#1058](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710207078) were **IN PROGRESS** when this entry was written; no pass is claimed yet.
- Live Supabase catalog access remains blocked by PostgreSQL `28P01`. This proves only the intended migration semantics when the disposable regression passes; it does not confirm a Production vulnerability or effective Production ACL. The migration has not been applied to Supabase Production.
- Next gate: finish CI #1106 / CodeQL #1058, inspect the ACL regression log, then update this record with the final result. Keep `create_offer_v1(...)` and schema CREATE privileges unchanged until authorized live owner/ACL evidence is available.


### Final validation — authenticated-only helper RPC anon ACL hardening — 10 November 2026

- The first run on code commit `3357a3bf5cf65de0d5dd4d6be051126ce1f71bf5`, QIMA CI #1106, was **CANCELLED** when the subsequent documentation commit advanced the PR ref while the workflow's `cancel-in-progress: true` concurrency group was active. This was cancellation, not a test failure. CodeQL #1058 completed **SUCCESS**.
- The replacement full run on final pre-validation HEAD `3c7a2e29f6d4b4bcfc2cda00cdb00527f47a4b59`, QIMA CI [#1107](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710427788), completed **SUCCESS**. Both jobs passed: CREATE_OFFER PostgreSQL integration and TypeScript/dependency audit/Next.js build/browser tests.
- The PostgreSQL job log contains `function EXECUTE ACL regression PASS` and `covered functions: 7`. It created seven disposable function stubs with default PUBLIC EXECUTE and direct `anon` grants, applied both `20261110070000_harden_public_rpc_execute_acl.sql` and `20261110080000_harden_authenticated_helper_anon_acl.sql` twice, and passed the postconditions: no PUBLIC/anon EXECUTE and explicit authenticated EXECUTE on all seven signatures. Existing CREATE_OFFER QA311–QA314, RLS, cleanup, and prepared-transaction checks also passed.
- The browser/build job passed npm installation, dependency audit, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright**. CodeQL [#1059](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710427629) completed **SUCCESS**.
- Vercel Preview Comments completed **SUCCESS** and the combined Vercel status for HEAD `3c7a2e2` was **SUCCESS**. No Production deployment was made.
- Live Supabase catalog access remains blocked by PostgreSQL `28P01`; effective Production ACLs and owners remain unverified. These tests establish migration semantics on disposable PostgreSQL only, not a Production vulnerability. Neither ACL migration has been applied to Supabase Production.
- Next gate: obtain authorized read-only catalog output for function owners/effective ACLs and `public` schema CREATE privileges. Keep the low-level `create_offer_v1(...)` ACL unchanged until its effective owner and SECURITY DEFINER caller relationship are verified.


### ACL regression postcondition coverage correction — 10 November 2026

- Review of `tests/sql/function-execute-acl-regression.sql` found that the pre-migration fixture and direct-`anon` grant covered seven function signatures, but the post-migration `v_function_oids` array contained only the first three. The test therefore did not assert the final ACL state for the four helper functions in `20261110080000_harden_authenticated_helper_anon_acl.sql`, despite printing `covered functions: 7`.
- Expanded the postcondition array to all seven exact signatures: `current_profile_actor_id()`, `dt_select_product_master(uuid,uuid,uuid)`, `execute_create_offer_v1(...)`, `dt_has_tenant_access(uuid)`, `dt_submit_answer(...)`, `dt_publish_product_request(uuid,uuid)`, and `is_message_participant(uuid,uuid,uuid)`. The existing loop now checks effective anon denial, effective authenticated access, and explicit absence of PUBLIC/direct-anon EXECUTE ACL entries for all seven.
- This is a regression-test coverage correction, not evidence of a Production ACL weakness. Both ACL migrations remain PR-only and have not been applied to Supabase Production.
- Code commit: `614c07a11cfc42ddc41e9d9ac40e0d28b6dc7da1`. QIMA CI #1109 and CodeQL #1061 were **IN PROGRESS** when this note was prepared; no result is claimed here. Vercel status was **PENDING**.
- Next gate: inspect the PostgreSQL job log for all seven postconditions, verify the full CI/CodeQL outcome, then append final results. Live Supabase catalog access remains blocked by PostgreSQL `28P01`; no Production vulnerability is confirmed.


### Final validation — direct-anon ACL fixture precondition — 10 November 2026

- A second review of the seven-function regression found that its pre-migration `has_function_privilege('anon', ...)` assertion could be satisfied through PUBLIC inheritance. Although the fixture issued direct `GRANT EXECUTE TO anon` statements, it did not independently assert that each direct anon ACL entry existed before the migrations. This was a test-precondition coverage gap, not evidence that either ACL migration failed or that Production was exposed.
- Commit `8ba029a3a802365946075d618d235a6aea074b17` adds an explicit `aclexplode(...)` precondition for `grantee = anon` on every one of the seven function OIDs, and fails clearly if the `anon` role is absent. The existing postconditions continue to assert no PUBLIC/direct-anon EXECUTE and an explicit authenticated EXECUTE grant for all seven signatures.
- QIMA CI [#1111](https://github.com/meridane/QimaTrade-MVP/actions/runs/42731262768) on code HEAD `8ba029a3a802365946075d618d235a6aea074b17`: **SUCCESS**. The PostgreSQL job completed CREATE_OFFER integration/concurrency, the seven-function ACL regression, legacy-message RLS, unsafe-URL guard, disposable database cleanup, prepared-transaction cleanup/restore, and participant self-enrollment RLS. Its log contains `function EXECUTE ACL regression PASS` and `covered functions: 7`.
- The browser/build job completed **SUCCESS**: npm install, dependency audit, TypeScript, Next.js build, Chromium install, and **336 passed**. npm audit reported **0 total** (0 info, low, moderate, high, critical). The log's `ECONNRESET` line comes from the explicit Playwright case that simulates an Auth transport failure and verifies the route returns a sanitized 401; the test passed.
- CodeQL [#1063](https://github.com/meridane/QimaTrade-MVP/actions/runs/42731262767): **SUCCESS**. Combined Vercel status for the code HEAD: **SUCCESS**. The preceding postcondition-array correction was also validated by QIMA CI #1110 and CodeQL #1062; CI #1109 was cancelled by the workflow's concurrency policy when the PR ref advanced, not by a test failure.
- Live Supabase catalog verification remains blocked. Project metadata lists QIMA (`yyulzlnrfcbaxovzjbnh`) as ACTIVE_HEALTHY on PostgreSQL 17.6.1.166, but the read-only `execute_sql` call still failed before query execution with PostgreSQL `28P01` for user `postgres`. The security-advisor endpoint separately returned a hibernation message inconsistent with the project metadata. No catalog rows were returned; this provider/connection inconsistency is not a database finding. Effective Production ACLs, owners, and `public` schema CREATE privileges remain unverified.
- Both ACL migrations remain PR-only and have not been applied to Supabase Production. The disposable regression proves the tested migration semantics on PostgreSQL 16 CI only; it does not establish a Production vulnerability. No Production data/schema/RLS/grants/secrets, persistent database configuration, deployment, PR merge, force-push, or branch-protection setting was changed.
- Next gate: restore an authorized read-only catalog query path or have a project maintainer run the SELECT-only owner/ACL/schema-privilege checks in the audit report. Keep the low-level `create_offer_v1(...)` ACL unchanged until its effective owner and SECURITY DEFINER caller relationship are verified.


### SECURITY DEFINER search_path metadata guard — 10 November 2026

A focused re-read of the defining migrations confirmed the execution metadata for the seven functions covered by the ACL hardening regression:

| Function | Source execution mode | Source search_path |
|---|---|---|
| `current_profile_actor_id()` | SECURITY DEFINER | `public` |
| `dt_select_product_master(uuid, uuid, uuid)` | SECURITY INVOKER | `public` |
| `execute_create_offer_v1(...)` | SECURITY DEFINER | `public` |
| `dt_has_tenant_access(uuid)` | SECURITY DEFINER | `public` |
| `dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)` | SECURITY DEFINER | `public` |
| `dt_publish_product_request(uuid, uuid)` | SECURITY DEFINER | `public` |
| `is_message_participant(uuid, uuid, uuid)` | SECURITY DEFINER | `public` |

The separate `get_action_definition_v1(text, integer)` function is also SECURITY DEFINER with `search_path = public`; its defining migration already explicitly revokes PUBLIC and anon and grants authenticated.

The reviewed bodies schema-qualify application relations (for example `public.dt_memberships`, `public.profiles`, and `public.offers`) and the Auth identity function (`auth.uid()`). The unqualified calls observed in these bodies are PostgreSQL/PLpgSQL built-ins such as `coalesce`, `nullif`, `trim`, `now`, `jsonb_build_object`, `md5`, `hashtextextended`, `gen_random_uuid`, `to_jsonb`, and `btrim`. PostgreSQL implicitly searches `pg_catalog` before user schemas when it is not explicitly listed in `search_path`; this source review did not find an unqualified application relation/function dependency in the reviewed bodies.

No `search_path` migration is proposed. Effective `CREATE`/ `USAGE` grants on schema `public`, owners, and live function ACLs remain unverified because the read-only Supabase catalog connection is blocked by PostgreSQL `28P01`. This review therefore does not establish a Production vulnerability or prove that the live schema is safe.

The disposable ACL regression fixture now mirrors the source-audited execution modes (six SECURITY DEFINER, one SECURITY INVOKER) and `search_path=public` for all seven signatures. It asserts those `pg_proc.prosecdef` and `proconfig` attributes both before and after applying the two ACL-only migrations twice. This protects the fixture contract and confirms those ACL migrations do not alter function security metadata; it remains a synthetic PostgreSQL test, not a live catalog inspection.

Validation on the new code commit: pending GitHub Actions. No Supabase Production data/schema/RLS/grants/secrets, migration application, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### SECURITY DEFINER function-owner invariant guard — 10 November 2026

A focused review of PostgreSQL privilege semantics found one remaining fixture assumption worth making explicit: revoking EXECUTE from PUBLIC and anon does not remove a function owner's implicit privileges. The seven-function disposable ACL regression now snapshots each target function's `pg_proc.proowner` before applying the two ACL migrations. It fails up front if a fixture function is owned by `anon` or `authenticated`, then compares every owner OID with its snapshot after both migrations have been applied twice. The snapshot lives in a session-local temporary table with `ON COMMIT PRESERVE ROWS`; the runner's dedicated psql session ends with the disposable database cleanup.

The change is test-only. It does not assert or infer the owner of any live Supabase function. It protects the migration regression's model by proving that the ACL-only migrations preserve ownership and that the fixture does not accidentally test a client role as function owner.

- Code commit: `abdc7772267f3f0814d97272dbd3415db8fac3f3` (`test(security): preserve RPC function ownership in ACL regression`).
- QIMA CI #1114: PostgreSQL CREATE_OFFER integration passed; the explicit seven-function ACL regression step passed; legacy-message RLS, unsafe-URL guard, database cleanup, prepared-transaction cleanup/restore, and participant self-enrollment RLS steps also passed. At the time of this note, the browser job had passed dependency audit, TypeScript, and Next.js build, while Chromium installation was still running; Playwright had not yet been confirmed.
- CodeQL #1066: SUCCESS. Combined Vercel status for the code HEAD: SUCCESS.
- A fresh read-only Supabase catalog query still failed before execution with PostgreSQL `28P01` (password authentication failed for `postgres`). Effective live owners, ACLs, role memberships, and `public` schema CREATE/USAGE grants therefore remain unverified. This synthetic regression does not establish a Production vulnerability.
- No Supabase Production data/schema/RLS/grants/secrets, migration application, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### Final validation — function-owner invariant ACL regression — 10 November 2026

- Code commit: abdc7772267f3f0814d97272dbd3415db8fac3f3. The regression snapshots pg_proc.proowner for all seven functions before the two ACL migrations, rejects fixture ownership by anon or authenticated, and compares each owner OID after the migrations. The temporary snapshot table remains session-local and is removed with the disposable database.
- QIMA CI #1114 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42743870617): SUCCESS. The CREATE_OFFER PostgreSQL integration job passed; its “Verify explicit RPC EXECUTE ACLs on disposable PostgreSQL” step completed SUCCESS. The log contains “function EXECUTE ACL regression PASS” and “covered functions: 7”. Existing QA311–QA314, legacy-message RLS, unsafe-URL guard, disposable database cleanup, active-session cleanup, prepared-transaction restoration/cleanup, and participant self-enrollment RLS steps also passed.
- The TypeScript/dependency-audit/Next.js build/browser job passed installation, npm audit, TypeScript, production build, Chromium installation, and 336 passed Playwright tests. npm audit reported 0 total advisories (0 info, low, moderate, high, critical).
- CodeQL #1066 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42743870903): SUCCESS. Combined Vercel status for the code commit abdc777 was SUCCESS. The three subsequent commits only append documentation; the CI and CodeQL workflows ignore documentation-only changes.
- The live Supabase read-only catalog query was retried and again failed before query execution with PostgreSQL 28P01 (password authentication failed for postgres). Effective Production function owners, ACLs, role memberships, and public schema CREATE/USAGE privileges remain unverified. The disposable test validates migration semantics and owner preservation in CI only; it does not confirm a Production vulnerability or the live catalog state.
- The PR branch is still open and draft. The code change was fast-forwarded from the work branch; no force-push, merge, Production migration/application, Production data/schema/RLS/grant/secret change, deployment, or branch-protection change was made.


### CI concurrency — preserve active pull-request validation — 10 November 2026

- Review of recent PR history found that active QIMA CI runs had been cancelled when a later commit advanced the same pull-request ref (for example, CI #1106 and #1109). The workflow used one concurrency group per `github.ref` with unconditional `cancel-in-progress: true`; a documentation follow-up on a code-bearing PR can still trigger a `pull_request.synchronize` run because path filtering evaluates the PR's aggregate diff.
- Commit `fe7df943257aa82ff6c1f0889e082036a5126537` changes `.github/workflows/ci.yml` to `cancel-in-progress: ${{ github.event_name != 'pull_request' }}`. Active PR validation is now allowed to finish when newer PR commits arrive. Push, scheduled, and manually dispatched runs retain cancellation of stale active runs.
- The concurrency group remains keyed by `github.ref`. GitHub permits one running and one pending run per group; a newer pending run may replace an older pending run. The change specifically prevents cancellation of an active PR run; it does not promise that every queued intermediate revision will execute.
- QIMA CI #1116 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42750878678) and CodeQL #1068 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42750878372) were triggered for this code commit and were **IN PROGRESS** at the time of this entry. No success is claimed. The combined Vercel status was **PENDING**.
- Previous HEAD `353068e759005d0e519d208dc0d037e9e02d9f4f` had QIMA CI #1115 **SUCCESS** (both PostgreSQL and browser/build jobs), CodeQL #1067 **SUCCESS**, and a Vercel failure caused by `build-rate-limit`; this prior result is not attributed to the new workflow commit.
- Next gate: verify that CI #1116 and CodeQL #1068 complete on `fe7df943257aa82ff6c1f0889e082036a5126537`; then append final outcomes. No Production data/schema/RLS/grants/secrets, Production migration, deployment, PR merge, force-push, or branch-protection setting was changed.


### Final validation — preserve active pull-request CI runs — 10 November 2026

- Workflow code commit: `fe7df943257aa82ff6c1f0889e082036a5126537`. `.github/workflows/ci.yml` now sets `cancel-in-progress: ${{ github.event_name != 'pull_request' }}` in the existing per-ref concurrency group. Active pull-request runs are not cancelled by a later PR synchronize event; push, schedule, and workflow_dispatch runs retain cancellation of stale active runs. A newer pending run can still replace an older pending run in the same group.
- QIMA CI #1116 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42750878678): **SUCCESS** on code HEAD `fe7df943257aa82ff6c1f0889e082036a5126537`. Both jobs completed successfully. The browser/build job passed dependency audit, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright tests**. The PostgreSQL job passed CREATE_OFFER integration/concurrency, QA311–QA314 (including QA314 explicit-null array-object replay), the seven-function EXECUTE ACL regression, unsafe-database-URL guard, legacy-message RLS, participant self-enrollment RLS, database cleanup, active-session cleanup, and prepared-transaction restoration/cleanup.
- CodeQL #1068 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42750878372): **SUCCESS** on the same code HEAD.
- Combined Vercel status for code HEAD `fe7df943257aa82ff6c1f0889e082036a5126537`: **SUCCESS**. The subsequent documentation-only HEAD `acd2b4bb033ec3191f3cfbde913abcf986998b80` has a separate Vercel status **PENDING**; no Production deployment was made.
- During CI #1116, the PR head advanced from `fe7df943` to documentation-only commit `acd2b4bb`. GitHub continued to report CI #1116 as **IN PROGRESS** rather than cancelling it, and the run later completed **SUCCESS**. No replacement CI run was created for the docs-only commit because the workflow ignores `docs/**`. This is an observed non-cancellation on a head advance, not a multi-run concurrency stress test.
- The prior code HEAD `353068e759005d0e519d208dc0d037e9e02d9f4f` had CI #1115 and CodeQL #1067 **SUCCESS**; its Vercel failure was the free build-rate limit. These results are separate from CI #1116.
- The canonical function register and QA185 addendum now contain this workflow change and the final CI/CodeQL evidence. Live Supabase ACL/owner/schema-privilege verification remains blocked by PostgreSQL `28P01`; disposable PostgreSQL tests do not establish a Production vulnerability. No Supabase Production data/schema/RLS/grants/secrets, Production migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### CI concurrency isolation by event type — 10 November 2026

- Review of the preceding change found one remaining cross-event collision: the concurrency group was keyed only by `github.ref`, while `cancel-in-progress` was true for non-`pull_request` events. A manually dispatched `workflow_dispatch` run on the PR branch could therefore share the PR group and cancel an active pull-request validation.
- Code commit: `0174d399c8bb1fc172711df38a6780a4e5ccff40`; follow-up test-quoting correction: `caf017246cd25e6f4447970cf340e859a3221053`. The group is now `qima-ci-${{ github.event_name }}-${{ github.ref }}`, isolating `pull_request`, `push`, `schedule`, and `workflow_dispatch` runs while preserving the existing cancellation policy within each event/ref group.
- Added `tests/ci/verify-workflow-concurrency.sh` and wired it into the CI verify job. The regression checks the exact event/ref group and the PR-specific cancellation expression. Local positive fixture passed; a negative fixture with the old ref-only group failed as expected. GitHub Actions step **Verify workflow concurrency isolation** also completed **SUCCESS** on the new PR HEAD.
- QIMA CI #1119 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42757396618) was triggered for `caf017246cd25e6f4447970cf340e859a3221053` and was **IN PROGRESS** at this entry. The new concurrency regression step passed; npm installation, dependency audit, and TypeScript passed. PostgreSQL integration, build, Playwright, and final job outcomes were still pending. No CI success is claimed here.
- CodeQL #1071 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42757396669) was **IN PROGRESS**; Vercel status was **PENDING**. Next gate: verify both workflows complete and inspect the final commit checks. No multi-run stress test is claimed.
- No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### Final validation — event-isolated CI concurrency — 10 November 2026

- QIMA CI #1119 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42757396618): **SUCCESS** on code HEAD `caf017246cd25e6f4447970cf340e859a3221053`. The browser/build job passed the new workflow-concurrency regression, `npm ci`, dependency audit, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright tests**. The PostgreSQL job passed CREATE_OFFER integration/concurrency, the seven-function EXECUTE ACL regression, unsafe-database-URL guard, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, active-session cleanup, prepared-transaction cleanup/restoration, and all cleanup steps.
- The browser log contains an `ECONNRESET` stack trace from the intentional Auth transport-failure fixture; the corresponding Playwright test passed. PostgreSQL logs contain expected negative-test exceptions (for example `IDEMPOTENCY_KEY_REUSE`, forced fixture failures, and the deliberate missing-relation cleanup test); the job and every listed step completed **SUCCESS**. These expected fixture errors are not reported as failed tests or confirmed vulnerabilities.
- CodeQL #1071 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42757396669): **SUCCESS** on code HEAD `caf0172`.
- After CI #1119 had started, the PR advanced to documentation-only HEAD `250ab93ff5c2a80cbaeae3a0d927b30f6c44e011`. GitHub continued to report CI #1119 as **IN PROGRESS** and it later completed **SUCCESS**; the docs-only HEAD did not create a replacement CI run because `docs/**` is ignored by the workflow path filter. This confirms that a PR synchronize event did not cancel the active PR run. It is not a concurrent `workflow_dispatch` stress test; event-type isolation is enforced by the new group expression and static regression.
- Latest combined Vercel status on documentation HEAD `250ab93`: **FAILURE** with the account build/deployment rate-limit link (`build-rate-limit`). This is a provider quota status, not a demonstrated Next.js build failure. No Production deployment was made.
- PR #26 remains **OPEN**, **DRAFT**, and unmerged; latest head is `250ab93ff5c2a80cbaeae3a0d927b30f6c44e011`, 1,243 PR commits, 75 changed files, and GitHub reported mergeable at the final read.
- The canonical register and QA185 addendum were re-read after publication; this final-validation section appears exactly once in each. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.

### CREATE_OFFER wrapper-owner EXECUTE preservation — 10 November 2026

- Conditional issue: the direct low-level `create_offer_v1(...)` revocation could remove PUBLIC access previously used by a `SECURITY DEFINER` wrapper whose owner is different from the low-level function owner. The live owner relationship remains unknown; no Production vulnerability or outage is inferred.
- Branch migration now revokes PUBLIC, anon, and authenticated from the low-level RPC, validates that the exact wrapper exists and is SECURITY DEFINER with a non-client owner, then grants EXECUTE to that wrapper owner only. Authenticated retains EXECUTE on the supported wrapper.
- Added a disposable PostgreSQL 16 regression with a distinct NOLOGIN/NOSUPERUSER wrapper owner. It applies the migration twice; asserts no PUBLIC/anon/authenticated low-level access, an explicit owner EXECUTE ACL, authenticated wrapper access, denied direct anon/authenticated calls, and a successful wrapper-to-low-level call. Runner restricts DATABASE_URL to loopback `qima_test` and cleans its dedicated database/role.
- QIMA CI #1122 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42763972930) initially failed only because psql saw doubled backslashes in the new fixture's first meta command (`invalid command \\`). Main CREATE_OFFER integration and the separate browser/build job passed; browser count was 336/336. CodeQL #1074 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42763972941) passed.
- Commit `84de16dead7fbc0182ba80e8b886561527d53d72` corrected the psql meta commands to single backslashes. QIMA CI #1123 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42764151217) then completed **SUCCESS**: the wrapper-owner regression printed **CREATE_OFFER wrapper-owner EXECUTE regression PASS**, all PostgreSQL/RLS/cleanup steps passed, and browser/build passed TypeScript, audit, Next.js build, Chromium, and 336/336 Playwright. CodeQL #1075 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42764151495) passed.
- Vercel on the latest HEAD reports the known `build-rate-limit` failure; this is a provider quota status, not a failed GitHub build. Supabase Production catalog access remains unavailable, so live function owners/ACLs are not verified. The isolated regression is not Production evidence.
- PR #26 remains OPEN/DRAFT/unmerged and mergeable at `84de16dead7fbc0182ba80e8b886561527d53d72`. No Supabase Production data/schema/RLS/grants/secrets, Production migration, persistent PostgreSQL configuration, Production deployment, merge, force-push, or branch-protection setting was changed.

### CI path-filter observation correction — 10 November 2026

- Clarification: an earlier event-isolation note said a documentation-only head did not create a replacement run because of `paths-ignore: docs/**`. That was an incomplete point-in-time observation, not a general guarantee. Because PR #26's aggregate diff still contains non-documentation paths, the later documentation-only HEAD `d0d4779199d02587d6332291165e5b53c975b095` triggered QIMA CI #1124 and CodeQL #1076.
- QIMA CI #1124 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42764400892): **SUCCESS**. The distinct-wrapper-owner PostgreSQL regression, the existing CREATE_OFFER/ACL/RLS/cleanup suite, TypeScript, audit, build, and **336/336 Playwright tests** all passed.
- CodeQL #1076 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42764400921): **SUCCESS**. Vercel remains rate-limited (`build-rate-limit`); GitHub's build succeeded. No Production deployment.
- PR #26 remains OPEN/DRAFT/unmerged and mergeable. No Supabase Production data/schema/RLS/grants/secrets, Production migration, persistent PostgreSQL configuration, Production deployment, merge, force-push, or branch-protection setting was changed.


## PostgreSQL 17.6 version-guard boundary regression — 10 November 2026

- Starting PR #26 state was verified before changes: OPEN, DRAFT, unmerged, mergeable; base `main`; head `3cde4a1550d1270f17b7291cea2838dad5b73c57`. The latest commits were `3cde4a1` (PostgreSQL 17.6 CI validation), `3f8d4e5` (follow-up documentation), and `06d3d92` (pin PostgreSQL compatibility image to 17.6). QIMA CI #1154 (run 42817064435) and CodeQL #1106 (run 42817064323) both completed SUCCESS on the starting HEAD; the combined Vercel status was SUCCESS for a Preview deployment.
- Identified a maintainability gap: the PostgreSQL 17.6 guard was embedded inline in `.github/workflows/ci.yml`, so its accepted and rejected version boundaries had no independent regression test.
- Extracted the exact-version check into `tests/sql/assert-postgres-17-6-version.sh`. It accepts only numeric `server_version_num=170006` and rejects non-numeric, missing, and other version values. The PostgreSQL service job now calls this same validator after reading `SHOW server_version_num`.
- Added `tests/sql/test-postgres-17-6-version-guard.sh` and wired it into the main CI verify job. The test accepts 170006 and rejects nine cases: 170005, 170007, 170011, 160006, 180000, the string `17.6`, a non-numeric value, an empty value, and a missing argument.
- Local shell execution passed: `PostgreSQL 17.6 version guard regression PASS: exact 170006 accepted; 9 invalid/missing cases rejected.` A direct validator invocation with 170006 also passed.
- Code change commits on the dedicated work branch: `2366d8e4297d076b9fed186f4f92f294e3680cbe` (CI wiring/extraction), `9c363021fe2b4ac50bd1aa2fb58675c382643a8f` (validator), and `08ff79d1e357113d3e604bde8376e20a6a4889c0` (boundary tests). The changes were fast-forwarded to `fix/create-offer-status-contract` with expected starting SHA `3cde4a1550d1270f17b7291cea2838dad5b73c57`; no force update was used. PR #26 now reports head `08ff79d1e357113d3e604bde8376e20a6a4889c0`, OPEN/DRAFT/unmerged and mergeable, with 1,296 commits and 79 changed files.
- QIMA CI #1155 (run 42823439048; https://github.com/meridane/QimaTrade-MVP/actions/runs/42823439048) was IN PROGRESS at this documentation checkpoint. The new version-guard boundary step completed SUCCESS; workflow-concurrency isolation, npm ci, dependency audit, TypeScript, and Next.js build also completed SUCCESS. PostgreSQL 16 and PostgreSQL 17.6 jobs were still running, and Chromium/Playwright had not completed. Do not claim full CI success until the run concludes.
- CodeQL #1107 (run 42823439052; https://github.com/meridane/QimaTrade-MVP/actions/runs/42823439052) was IN PROGRESS at this checkpoint. The combined Vercel status on code HEAD `08ff79d` reported provider `build-rate-limit`; this is not evidence of a Next.js build failure and no Production deployment occurred.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` blob is 1,621,952 bytes. GitHub's file-content connector returns its blob SHA but not the body at this size. To avoid replacing or truncating the 1.6 MB history without its full contents, this validation is recorded in this append-only supplement, which explicitly references the canonical register. Canonical blob at the starting HEAD: `0f1c8a802d0bfa95b4726808fa5f418829a81924`.
- Safety: no Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change occurred.


### Final verification follow-up — 10 November 2026

- QIMA CI #1155 (run 42823439048; https://github.com/meridane/QimaTrade-MVP/actions/runs/42823439048) completed **SUCCESS** on code HEAD `08ff79d1e357113d3e604bde8376e20a6a4889c0`. All three jobs succeeded: TypeScript/audit/build/browser, PostgreSQL 16 integration, and PostgreSQL 17.6 compatibility.
- The new `Verify PostgreSQL 17.6 version guard boundary cases` step completed SUCCESS. The PostgreSQL 17.6 service reported `server_version_num=170006`; CREATE_OFFER integration/concurrency, wrapper-owner/membership regression, and seven-function EXECUTE ACL regression all passed. PostgreSQL 16 CREATE_OFFER, ACL, RLS, disposable-database cleanup, active-session, prepared-transaction, and participant self-enrollment checks also passed.
- The browser/build job completed npm ci, the high-severity dependency audit, TypeScript, Next.js production build, Chromium installation, and browser smoke tests successfully. Playwright result: **336 passed, 0 failed**.
- CodeQL #1107 (run 42823439052; https://github.com/meridane/QimaTrade-MVP/actions/runs/42823439052) completed **SUCCESS** on the same code HEAD.
- The combined Vercel status on code HEAD `08ff79d` was FAILURE with provider target `upgradeToPro=build-rate-limit`. This is a deployment quota response, not evidence of a GitHub Next.js build failure. No Production deployment was performed.
- A documentation-only commit `e7900aab28018439f5e8a8fe062517eccd9050c5` then fast-forwarded the addendum to PR #26. At that verification point PR #26 was OPEN, DRAFT, unmerged and mergeable, with head `e7900aab28018439f5e8a8fe062517eccd9050c5`, 1,297 commits and 79 changed files. No separate CI run for that docs-only commit was present in the Actions list; the code it documents is the exact code HEAD validated by CI #1155 and CodeQL #1107.
- The canonical register remains 1,621,952 bytes at the code checkpoint and its content body is not returned by the GitHub file-content connector. This addendum remains append-only; the canonical 1.6 MB blob was not replaced or truncated.
- No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment, PR merge, force update, or branch-protection change occurred.


### Supabase read-only catalog retry and current PR checks — 10 November 2026

- A fresh Supabase connector attempt used a read-only SELECT over `pg_proc`, `pg_namespace`, function owners, `prosecdef`, `proconfig`, `proacl`, effective anon/authenticated EXECUTE, wrapper-owner schema USAGE/CREATE, and direct membership checks. The connector returned an internal error containing PostgreSQL `FATAL: 28P01: password authentication failed for user "postgres"` before the query ran. No catalog rows were returned. This is an access/authentication blocker, not evidence of an ACL defect.
- Supabase project metadata and the previous catalog attempts identify the project as `yyulzlnrfcbaxovzjbnh`; the actual Production owners, ACLs, memberships, and schema privileges remain unverified. No SQL mutation, migration, grant, policy change, or secret change was attempted.
- Current PR #26 state after the final documentation commit: OPEN, DRAFT, unmerged, mergeable; head `72822f23058a0b8680efc5479c1c9c4e4515efe9`; 1,298 commits and 79 changed files.
- Code HEAD `08ff79d1e357113d3e604bde8376e20a6a4889c0` remains validated by CI #1155 and CodeQL #1107, both SUCCESS. CI #1155's three jobs all passed, including the extracted version-guard boundary step, PostgreSQL 16, PostgreSQL 17.6, dependency audit, TypeScript, Next.js build, Chromium, and browser smoke tests.
- Documentation-only follow-up runs observed at the latest read: CI #1156 (run 42823677169) IN PROGRESS on docs checkpoint `e7900aab28018439f5e8a8fe062517eccd9050c5`; CI #1157 (run 42823801367) PENDING/queued on current PR HEAD `72822f23058a0b8680efc5479c1c9c4e4515efe9`; CodeQL #1108 and #1109 IN PROGRESS on those respective documentation heads. No failures were observed in these not-yet-completed runs. They do not change the validated code content.
- Combined Vercel status on current PR HEAD is FAILURE with target `upgradeToPro=build-rate-limit`, a provider deployment quota. GitHub build #1155 succeeded; no Production deployment occurred.
- Safety: no Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No PR merge, force update, or branch-protection change occurred.


## QA186 — strict PostgreSQL 17.6 validator argument arity

- **Scope:** harden the standalone CI validator `tests/sql/assert-postgres-17-6-version.sh` so its command-line contract is exact and fail-closed.
- **Change:** the validator now requires exactly one positional argument before parsing the value. Zero arguments and more than one argument are rejected with an explicit argument-count error; the accepted value remains exactly `170006`.
- **Regression coverage:** `tests/sql/test-postgres-17-6-version-guard.sh` retains the one accepted PostgreSQL 17.6 value and the nine prior invalid/missing cases, and adds an extra-positional-argument case. Expected result: 1 accepted input and 10 rejected inputs.
- **Local validation:** `bash tests/sql/test-postgres-17-6-version-guard.sh` — **PASS**. Output: `PostgreSQL 17.6 version guard regression PASS: exact 170006 accepted; 10 invalid/missing/arity cases rejected.`
- **Code commits:** `e00c957fab72e516fa8a429f95463b4d4dfb208f` (exactly-one-argument guard) and `254ff8e0e025188ff80c33ac5bc45606e1a2dbec` (extra-argument regression). The work branch was fast-forwarded to PR branch `fix/create-offer-status-contract` from expected prior head `89dd2b48adbdc32ff9775ca99c2b0a12d9e949d7`; no force update was used.
- **PR state after code publication:** PR #26 remains OPEN, DRAFT, unmerged and mergeable; code head `254ff8e0e025188ff80c33ac5bc45606e1a2dbec`, 1,301 commits and 79 changed files at the latest read.
- **CI on the new code head:** QIMA CI run `42840191031` was still **IN PROGRESS** at this checkpoint. PostgreSQL 17.6 compatibility job completed successfully, including the version assertion and all three CREATE_OFFER/ACL suites. In the PostgreSQL 16 job, CREATE_OFFER integration/concurrency, wrapper-owner, seven-function ACL, legacy migration URL guard, legacy messages RLS, database cleanup, real-failure cleanup, active-session cleanup, and multiple-session cleanup had passed; prepared-transaction configuration restoration was still running and later prepared-transaction checks plus participant self-enrollment had not yet run. In the browser/build job, workflow isolation, the PostgreSQL 17.6 boundary regression, npm installation, dependency audit, TypeScript and Next.js build had passed; Chromium installation and browser tests were still pending.
- **CodeQL on the new code head:** run `42840190999` completed successfully.
- **Earlier baseline verification:** the preceding PR head `89dd2b48adbdc32ff9775ca99c2b0a12d9e949d7` had all three QIMA CI jobs and CodeQL completed successfully (CI run `42824122607`; CodeQL run `42824122927`). These are baseline results, not validation of the new argument-arity change.
- **Canonical register limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` was re-read by SHA on the current PR branch, but its body remains unavailable through the GitHub file-content connector because the blob exceeds the connector's supported retrieval size. Its blob SHA is `0f1c8a802d0bfa95b4726808fa5f418829a81924`. To avoid replacing or truncating the 1.6 MB history, this run records the change in this append-only QA185 addendum instead.
- **Safety:** this change affects only the local CI validator and its shell regression test. No Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, deployment, merge, force update, or branch-protection setting was changed.


## QA187 — PostgreSQL 17.6 validator exact argument count

- **Code HEAD:** `254ff8e0e025188ff80c33ac5bc45606e1a2dbec`.
- **Validator change:** `tests/sql/assert-postgres-17-6-version.sh` now rejects every invocation whose argument count is not exactly one, before parsing the value. The only accepted value remains `170006`.
- **Regression test:** `tests/sql/test-postgres-17-6-version-guard.sh` now covers the prior nine invalid/missing values plus a tenth case with an extra positional argument. The one valid input is accepted; all ten invalid/missing/arity cases are rejected.
- **Local validation:** `bash tests/sql/test-postgres-17-6-version-guard.sh` — **PASS**. Exact output: `PostgreSQL 17.6 version guard regression PASS: exact 170006 accepted; 10 invalid/missing/arity cases rejected.`
- **QIMA CI #1159:** run `42840191031` — **SUCCESS**, all 3 jobs. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42840191031).
  - PostgreSQL 16 integration job: **SUCCESS**, including CREATE_OFFER integration/concurrency, wrapper-owner regression, seven-function EXECUTE ACL regression, legacy messages RLS/cleanup, active-session and prepared-transaction cleanup, and participant self-enrollment.
  - PostgreSQL 17.6 compatibility job: **SUCCESS**. Server reported `server_version_num=170006`; CREATE_OFFER integration/concurrency, wrapper-owner/membership regression, and seven-function EXECUTE ACL regression all passed.
  - Browser/build job: **SUCCESS**. Workflow isolation and the PostgreSQL 17.6 boundary test passed; npm installation, high-severity dependency audit, TypeScript, Next.js production build, Chromium installation, and browser tests passed. Playwright: **336 passed, 0 failed**.
  - The browser log includes `ECONNRESET: Auth network connection reset` in the deliberately simulated Auth network-failure case; the suite completed with 336 passing tests and no failures. This is a test fixture result, not a production incident.
- **CodeQL #1111:** run `42840190999` — **SUCCESS** on code HEAD `254ff8e0e025188ff80c33ac5bc45606e1a2dbec`. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42840190999).
- **PR publication:** the code branch was fast-forwarded from expected prior head `89dd2b48adbdc32ff9775ca99c2b0a12d9e949d7` to `254ff8e0e025188ff80c33ac5bc45606e1a2dbec`, then this addendum was fast-forwarded to `fe2db85651cf55ae38d494ae98489e78c2ffb9aa`. No force update was used. PR #26 remains OPEN, DRAFT, unmerged and mergeable; 1,302 commits and 79 changed files at final verification.
- **Documentation-trigger behavior:** the final addendum-only commit changes only `docs/**`, which is excluded by the CI workflow's `paths-ignore` filter. No additional CI or CodeQL run was created for that documentation-only commit at the final Actions read. The code itself is covered by the successful CI #1159 and CodeQL #1111 runs on the immediately preceding code HEAD.
- **Canonical register limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` was checked at the PR head; GitHub's file-content connector returned its blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but no body because the file exceeds the connector's supported retrieval size. The 1.6 MB canonical history was not replaced or truncated. This result is recorded in the append-only QA185 addendum.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, deployment, merge, force update, or branch-protection setting was changed.


## QA188 — follow-up correction: documentation commit checks

- **Correction to QA187:** the statement that no workflow was created for the documentation-only PR update was incorrect. After addendum commit `fe2db85651cf55ae38d494ae98489e78c2ffb9aa` was fast-forwarded to the PR branch, GitHub did trigger another pull-request validation. The PR-wide diff still includes non-documentation files, so the `paths-ignore: docs/**` filter did not suppress this PR run. This observed behavior supersedes the QA187 sentence claiming no run was created.
- **QIMA CI #1160:** run `42840867871` on addendum HEAD `fe2db85651cf55ae38d494ae98489e78c2ffb9aa` — **SUCCESS**, all 3 jobs. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42840867871).
  - PostgreSQL 16 integration job: **SUCCESS**, including CREATE_OFFER integration/concurrency, wrapper-owner regression, seven-function ACL regression, legacy RLS/cleanup, prepared-transaction restoration/cleanup, and participant self-enrollment.
  - PostgreSQL 17.6 compatibility job: **SUCCESS**. Exact server version assertion passed; CREATE_OFFER integration/concurrency, wrapper-owner/membership, and seven-function ACL regressions passed.
  - Browser/build job: **SUCCESS**. Workflow concurrency guard, exact-arity PostgreSQL 17.6 version-guard regression, npm installation, dependency audit, TypeScript, Next.js production build, Chromium installation, and browser tests passed. Playwright log reports **336 passed, 0 failed**.
- **CodeQL #1112:** run `42840867798` on the same addendum HEAD — **SUCCESS**. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42840867798).
- **Code validation remains anchored to code commit:** CI #1159 (`42840191031`) and CodeQL #1111 (`42840190999`) both succeeded on code HEAD `254ff8e0e025188ff80c33ac5bc45606e1a2dbec`. CI #1160 and CodeQL #1112 also succeeded on the subsequent addendum HEAD, which contains the same code plus documentation.
- **Final safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.


## QA189 — exact per-commit workflow evidence

- **Evidence correction:** QA188 correctly records that QIMA CI #1160 and CodeQL #1112 were created for addendum head `fe2db85651cf55ae38d494ae98489e78c2ffb9aa` and both completed successfully. However, the explanation in QA188 attributing the trigger to the PR-wide diff is not established by the available evidence and should not be treated as a confirmed explanation.
- **Observed current-head behavior:** commit `095cf03fd2cd992fc4c406ba283397a6bab9e9d5` changes only the QA185 documentation addendum. At the final check, `fetch_commit_workflow_runs` returned no workflow runs for this SHA and its check-runs endpoint returned zero checks. Therefore no CI or CodeQL result is claimed for this exact documentation-only commit.
- **Adjacent documentation checkpoint:** CI #1161 (run `42841136683`) was created for earlier addendum head `97ab8713ee79f7a9b3290c6e2f4dd41a2f28d2ba` and remained **IN PROGRESS** at this checkpoint. CodeQL #1113 (run `42841136723`) for that same SHA completed **SUCCESS**. These are not checks attached to current HEAD `095cf03`.
- **Code verification:** code HEAD `254ff8e0e025188ff80c33ac5bc45606e1a2dbec` is fully validated by QIMA CI #1159 (run `42840191031`) and CodeQL #1111 (run `42840190999`), both **SUCCESS**. The subsequent addendum head `fe2db85651cf55ae38d494ae98489e78c2ffb9aa` is also fully validated by CI #1160 and CodeQL #1112, both **SUCCESS**.
- **Interpretation rule:** record workflow/check evidence against the exact commit SHA. Do not infer why a workflow did or did not trigger solely from `paths-ignore` or from a previous documentation update.
- **PR state at this checkpoint:** PR #26 remains OPEN, DRAFT and unmerged; latest head `095cf03fd2cd992fc4c406ba283397a6bab9e9d5`, 1,304 commits and 79 changed files. GitHub returned `mergeable=null` / `mergeable_state=unknown` while recalculating; mergeability is not asserted at this checkpoint.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.


## QA190 — Supabase read-only catalog access retry

- **Project metadata:** Supabase `get_project` returned project `yyulzlnrfcbaxovzjbnh`, name `QIMA`, status `ACTIVE_HEALTHY`, region `ap-southeast-1`, PostgreSQL `17.6.1.166` (engine 17).
- **Read-only query attempted:** a single SELECT-only catalog query resolved the exact wrapper and low-level CREATE_OFFER signatures and requested their owners, SECURITY DEFINER flags, `proconfig`, function ACLs, effective EXECUTE privileges, owner schema USAGE/CREATE, direct role memberships, and client schema CREATE privileges. No DDL or DML was included.
- **Result:** Supabase `execute_sql` failed before returning query rows with `FATAL: 28P01: password authentication failed for user "postgres"`. No catalog row was returned; the query did not execute successfully.
- **Interpretation:** project metadata reports ACTIVE_HEALTHY, but the SQL execution path is currently blocked by database authentication. This is an access failure, not evidence that either CREATE_OFFER function has an ACL defect. Production ownership, grants, role memberships, and schema privileges remain unverified.
- **Next required input:** a working read-only SQL/catalog access path for project `yyulzlnrfcbaxovzjbnh`. Do not change the database password, secrets, roles, grants, schema, or project configuration to bypass this failure.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed. No Production deployment or PR merge occurred.


## QA315 — CREATE_OFFER SECURITY DEFINER temporary-relation shadow regression

- **Priority selected:** MKT-1.1 demand/provider eligibility remains blocked on a business ownership decision. Supabase production catalog verification remains blocked by the recorded PostgreSQL 28P01 authentication failure. A non-blocking, test-only defense-in-depth task was selected instead.
- **Code change:** tests/sql/create-offer-runtime.sql now creates empty temporary relations shadowing the nine public relations used by the CREATE_OFFER wrapper/low-level path: dt_memberships, profiles, product_masters, demands, action_definitions, idempotency_keys, action_executions, offers, and action_events.
- **Preflight:** the disposable session verifies that unqualified relation lookup resolves each name to pg_temp. The test then runs the existing authenticated CREATE_OFFER runtime regression while the shadows exist, verifies all nine temporary relations remain empty, drops them, and emits a QA315 success marker.
- **Security rationale:** PostgreSQL implicitly searches the session temporary schema first for relation/type names when it is not explicitly present in search_path. The CREATE_OFFER functions pin search_path=public; this test protects the existing explicit public qualification of relation references against a future accidental unqualified lookup/write. It does not establish a production vulnerability or prove the live Supabase function body is identical.
- **Isolation:** the temporary relations exist only in the disposable PostgreSQL integration session. No production function, migration, schema, role, grant, or data is changed.
- **Work branch:** work/create-offer-temp-schema-shadowing-20261111-0013.
- **Commit history:** initial work-branch patch 12e2c0970fe62130e85dad5a9c8c5ebd0df66b09 had a malformed SQL delimiter/placement and was immediately corrected by 9dd049299582bc90bd631cac28147025be2d3caf before fast-forwarding to the PR branch. The final base-to-PR diff contains only 57 insertions in tests/sql/create-offer-runtime.sql; no deletions or other files changed.
- **PR update:** PR #26 was OPEN, DRAFT and unmerged. Head advanced from 8d1112b929ebb61ad6e69aba936652b12564f815 to 9dd049299582bc90bd631cac28147025be2d3caf (1,308 commits, 79 changed files). GitHub reported mergeable=false during the immediate post-update read; this is recorded as an observed state, not interpreted as a code conflict without a fresh compare.
- **Baseline checks before QA315:** CI #1163 (run 42842003491) on prior head 8d1112b929ebb61ad6e69aba936652b12564f815 completed SUCCESS across all three jobs: PostgreSQL 16 integration, PostgreSQL 17.6 CREATE_OFFER compatibility, and typecheck/audit/build/browser. CodeQL #1115 (run 42842003758) on that same prior head completed SUCCESS.
- **QA315 commit checks:** immediately after advancing the PR ref to 9dd049299582bc90bd631cac28147025be2d3caf, fetch_commit_workflow_runs returned no CI or CodeQL runs for that exact SHA. Combined status returned only the Vercel failure build-rate-limit. Therefore QA315 is NOT YET CI-VALIDATED at this checkpoint; do not infer success from CI #1163, which predates the test change.
- **Canonical register retrieval:** docs/QIMA_V1_FUNCTION_REGISTER.md was queried at the PR branch and returned blob SHA 0f1c8a802d0bfa95b4726808fa5f418829a81924 but no file body from the connector because of the large-file retrieval limitation. The canonical file was not replaced or truncated; this QA315 record is appended to the official QA185 addendum.
- **Production access:** Supabase project metadata remains ACTIVE_HEALTHY, PostgreSQL 17.6.1.166; the read-only catalog query remains blocked before returning rows by 28P01: password authentication failed for user "postgres". Live owners, ACLs, memberships, and schema privileges remain unverified.
- **Next gate:** obtain a workflow result for the exact QA315 code SHA and inspect the PostgreSQL 16 and 17.6 job logs for the QA315 success marker. If the PR ref update did not trigger Actions, use an authorized workflow-dispatch path or wait for a normal PR synchronization run; do not report QA315 as passing until the exact code SHA is covered.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.


## QA316 — QA315 validation checkpoint and fresh Supabase catalog retry

- **Current PR state:** PR #26 remains OPEN, DRAFT and unmerged. Current head before this documentation checkpoint: 0b45d560c8c9647bc167cb2f97641fd6b679ca6f; 1,309 commits, 79 changed files. The raw GitHub PR endpoint returned mergeable=null and mergeable_state=unknown; do not interpret this as a confirmed conflict. The base/head comparison is 1,309 ahead and 0 behind.
- **QA315 exact-head checks:** the GitHub check-runs endpoint returned total_count=0 for both code commit 9dd049299582bc90bd631cac28147025be2d3caf and current documentation head 0b45d560c8c9647bc167cb2f97641fd6b679ca6f. The PR-triggered workflow-run lookup also returned no runs for either SHA. No CI or CodeQL result is claimed for QA315.
- **Prior validated baseline only:** CI #1163 (run 42842003491) and CodeQL #1115 (run 42842003758) completed SUCCESS on the earlier head 8d1112b929ebb61ad6e69aba936652b12564f815. These checks predate QA315 and do not validate the temporary-shadow regression.
- **Fresh Supabase metadata:** get_project again returned QIMA project yyulzlnrfcbaxovzjbnh, status ACTIVE_HEALTHY, region ap-southeast-1, PostgreSQL 17.6.1.166.
- **Fresh read-only catalog attempt:** execute_sql was called with a SELECT-only query for the exact CREATE_OFFER wrapper and low-level signatures, function owners, SECURITY DEFINER/proconfig, function ACLs, effective EXECUTE, owner schema USAGE/CREATE, client schema CREATE, and direct role membership. The connector returned INVALID_ARGUMENT wrapping an InternalServerErrorException whose database cause was FATAL 28P01: password authentication failed for user "postgres". No query rows were returned; no catalog facts were verified.
- **Vercel status:** combined commit status reports Vercel failure with build-rate-limit. This is a provider quota status, not evidence of a Next.js build failure. No Production deployment occurred.
- **Next required action:** a repository-authorized workflow_dispatch or normal PR synchronization run is required to validate the exact QA315 code SHA. Inspect both PostgreSQL 16 and PostgreSQL 17.6 logs for the QA315 marker before claiming success. Separately, a working read-only Supabase SQL/catalog connection is still required before making any statement about live Production owners/ACLs.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.


## QA317 — QA315 temporary-relation shadow regression validated on current PR head

- **Current PR state:** PR #26 is OPEN, DRAFT, unmerged and mergeable. Head: `5543acb0a7f2973773897279dd0f620ddf2eb8c0`; 1,310 commits ahead of `main`, 0 behind, 79 changed files. The base/head comparison reports `ahead`, not a merge conflict.
- **Code lineage:** QA315 test code is in commit `9dd049299582bc90bd631cac28147025be2d3caf`. The subsequent commits `0b45d560c8c9647bc167cb2f97641fd6b679ca6f` and `5543acb0a7f2973773897279dd0f620ddf2eb8c0` are documentation-only; the QA315 SQL code is unchanged at the validated PR head.
- **Test implementation inspected:** `tests/sql/create-offer-runtime.sql` (blob `4740b227d1199c2b5a9db078ae2d089fc6673dd4`) creates empty temporary shadows for nine relations: `dt_memberships`, `profiles`, `product_masters`, `demands`, `action_definitions`, `idempotency_keys`, `action_executions`, `offers`, and `action_events`. The preflight confirms each unqualified relation name resolves to its `pg_temp` relation. The authenticated CREATE_OFFER runtime scenario then executes; the postcondition checks that all nine temp shadows remain empty, drops them, and emits the QA191 success marker.
- **QIMA CI #1165:** run `42843549530` on current PR head `5543acb0a7f2973773897279dd0f620ddf2eb8c0` — **SUCCESS**, all 3 jobs. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42843549530).
  - PostgreSQL 16 integration job `129926872189`: **SUCCESS**. Its log contains the exact QA191 marker: `SECURITY DEFINER relation lookups and writes bypassed all temporary shadows and used schema-qualified public objects`. CREATE_OFFER integration/replay/rollback checks, wrapper-owner regression, eight negative wrapper-owner rollback scenarios, and the seven-function EXECUTE ACL regression also passed.
  - PostgreSQL 17.6 compatibility job `129926871236`: **SUCCESS**. The server reported `server_version_num=170006`; its log contains the same QA191 success marker. CREATE_OFFER integration, wrapper-owner/membership scenarios, and seven-function EXECUTE ACL regression passed.
  - Browser/build job `129926871849`: **SUCCESS**. Workflow-concurrency regression, npm ci, high-severity dependency audit, TypeScript, Next.js production build, Chromium installation and Playwright all passed. Playwright reported **336 passed, 0 failed**. The logged `ECONNRESET` is emitted by the deliberate Auth network-failure test fixture; the suite completed successfully.
- **CodeQL #1117:** run `42843549440` on the same PR head — **SUCCESS**. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42843549440).
- **Validation interpretation:** QA315 is now validated by CI on the current PR head, which includes the unchanged QA315 code commit. This is disposable PostgreSQL 16 and 17.6 evidence only. It does not establish that the same function definitions, grants, owners, or behavior exist in Supabase Production, and it does not establish a live vulnerability.
- **Canonical register retrieval:** `docs/QIMA_V1_FUNCTION_REGISTER.md` was re-read at the PR branch. The connector returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but no body because of the large-file retrieval limitation. The canonical historical file was not overwritten or truncated; this validation is appended here.
- **Production access:** Supabase catalog access remains blocked by the previously observed PostgreSQL `28P01` authentication failure. Production function owners, ACLs, memberships, and schema privileges remain unverified.
- **Next gate:** retain the passing QA315 baseline. The next meaningful security comparison still requires a working read-only Supabase catalog path; MKT-1.1 demand/provider eligibility separately requires a business ownership decision. Do not add further speculative ACL changes before those gates are resolved.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, PR merge, force update, or branch-protection setting was changed.


## QA318 — PR-head correction after QA317 documentation fast-forward

- **Correction to QA317 wording:** head `5543acb0a7f2973773897279dd0f620ddf2eb8c0` is the exact PR head validated by CI #1165 and CodeQL #1117. After QA317 was appended, a documentation-only commit `97d6f807e249309a2ea34a03e9710862da53e3ea` was fast-forwarded to `fix/create-offer-status-contract`. Thus `5543acb` is the validated code head, while `97d6f80` is the subsequent documentation head.
- **Current PR metadata:** PR #26 is OPEN, DRAFT and unmerged; current head `97d6f807e249309a2ea34a03e9710862da53e3ea`, 1,311 commits, 79 changed files. The base/head comparison is 1,311 ahead and 0 behind. The normalized PR endpoint currently reports `mergeable=false`; because the compare endpoint reports no commits behind and no merge-conflict detail is available, do not infer a specific conflict or alter the base/protection settings.
- **Latest commit scope:** commit `97d6f807e249309a2ea34a03e9710862da53e3ea` changes only `docs/QIMA_V1_FUNCTION_REGISTER_QA185_APPEND.md`; no SQL test, application code, migration, or workflow changed after the validated code head.
- **Current-head workflow lookup:** `fetch_commit_workflow_runs` returned no PR-triggered workflow runs for documentation-only head `97d6f807e249309a2ea34a03e9710862da53e3ea`. Therefore no CI or CodeQL result is claimed for that exact documentation commit.
- **Code validation remains valid for unchanged code:** CI #1165 and CodeQL #1117 both succeeded on parent code head `5543acb0a7f2973773897279dd0f620ddf2eb8c0`. CI #1165's PostgreSQL 16 and PostgreSQL 17.6 logs both contain the QA191 success marker; the browser/build job reports 336 passed and 0 failed.
- **Next gate:** no additional code change is needed to close QA315. Preserve the validated code baseline. Investigate the unexplained PR `mergeable=false` metadata without changing branch protection or rebasing; continue to require read-only live Supabase catalog access before any Production ACL conclusion.
- **Safety:** this correction is documentation-only. No Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, merge, force update, or branch-protection setting was changed.



## QA319 — QA315 authenticated-caller precondition regression

- **Priority:** harden the QA315 test itself so the temporary-relation shadow scenario cannot silently run under the privileged CI database owner instead of the intended client role.
- **Code commit:** `ebb6da9c35e338113a6cc1b53d88792a0649f73f` on work branch `work/qa315-authenticated-context-guard-20261111-0243`; fast-forwarded to `fix/create-offer-status-contract`.
- **File:** `tests/sql/create-offer-runtime.sql` only.
- **Preflight assertions added:** after `SET ROLE authenticated` and creation of the nine `pg_temp` shadows, the test now requires `current_user = 'authenticated'` and `pg_my_temp_schema() <> 0` before checking that unqualified relation resolution reaches each temporary shadow.
- **Postcondition assertion added:** before checking the nine temporary tables remain empty, the test again requires `current_user = 'authenticated'`. This protects against a future accidental `RESET ROLE` or role-context change between setup and assertion.
- **Diff:** 12 insertions, 0 deletions in the SQL regression file. The prior QA315 test body and runtime function/migration code are unchanged.
- **QIMA CI #1168:** run `42868091678` on exact code commit `ebb6da9c35e338113a6cc1b53d88792a0649f73f` — **SUCCESS**, all 3 jobs. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42868091678).
  - PostgreSQL 16 integration job `130011717745`: **SUCCESS**. Its decoded log contains the exact marker `QA191 SECURITY DEFINER relation lookups and writes bypassed all temporary shadows and used schema-qualified public objects`. The new authenticated-caller preflight and postcondition completed without exception. CREATE_OFFER integration/replay/rollback/concurrency, wrapper-owner regression, seven-function EXECUTE ACL, legacy RLS/cleanup, prepared-transaction restoration/cleanup, and participant self-enrollment checks passed.
  - PostgreSQL 17.6 compatibility job `130011717680`: **SUCCESS**. Server version assertion reported `server_version_num=170006`; the decoded log contains the same QA191 marker. The new caller-role assertions passed, as did CREATE_OFFER integration/concurrency, wrapper-owner/membership, and seven-function EXECUTE ACL tests.
  - Browser/build job `130011717180`: **SUCCESS**. Workflow-concurrency guard, PostgreSQL version-guard boundary cases, npm ci, dependency audit, TypeScript, Next.js production build, Chromium installation, and Playwright passed. Playwright reported **336 passed, 0 failed**.
- **CodeQL #1119:** run `42868091679` on the same code commit — **SUCCESS**. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42868091679).
- **Vercel Preview:** combined commit status is **SUCCESS** for `ebb6da9`; this is a Preview status, not a Production deployment.
- **PR metadata correction:** at the start of this run, PR #26 was OPEN, DRAFT and unmerged at head `551d751cb6d86440544ca0708f5d39361d47907f`, with 1,312 commits ahead of `main`, 0 behind, and `mergeable=true`. This supersedes the stale `mergeable=false` observation recorded in QA318. After the code fast-forward, the PR head is `ebb6da9c35e338113a6cc1b53d88792a0649f73f`, 1,313 commits ahead, 0 behind; GitHub again reports `mergeable=true`.
- **Review state:** the latest read returned no submitted PR reviews and no inline review threads. The PR remains DRAFT; no readiness or merge action was taken.
- **Validation interpretation:** CI #1168 and CodeQL #1119 validate the test change on disposable PostgreSQL 16 and 17.6. They do not prove the live Supabase function definitions, owners, grants, memberships, or search-path settings, and do not establish a Production vulnerability.
- **Canonical register:** `docs/QIMA_V1_FUNCTION_REGISTER.md` was queried at the PR branch; the connector returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but no body. It was not overwritten. This evidence is appended to the reviewable QA185 addendum.
- **Production/business gates:** the previously recorded Supabase read-only catalog query remains blocked by PostgreSQL `28P01` authentication failure; no new Production connection was attempted in this run. MKT-1.1 demand/provider eligibility still requires an explicit business ownership decision.
- **Safety:** no Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, PR merge, force update, or branch-protection setting was changed.


## QA320 — latest PR and check reconciliation after QA319

- **Current code head:** `ebb6da9c35e338113a6cc1b53d88792a0649f73f` is the code commit validated by CI #1168 and CodeQL #1119.
- **Latest checks:** QIMA CI #1168 and CodeQL #1119 both completed **SUCCESS** on the exact code SHA. Vercel Preview status for the same SHA is **SUCCESS**.
- **PR state:** OPEN, DRAFT, unmerged, mergeable=true; 1,313 commits ahead of `main`, 0 behind, 79 changed files.
- **Last commit before this documentation update:** `ebb6da9` changes only `tests/sql/create-offer-runtime.sql` (12 additions, 0 deletions).
- **Next validation rule:** record any subsequent CI/CodeQL result against its exact SHA; do not attribute CI #1168 / CodeQL #1119 to a later documentation-only commit unless GitHub reports those checks on that exact SHA.
- **Next work:** retain the QA315 passing baseline; prioritize read-only Supabase catalog access and the separately blocked MKT-1.1 business contract before adding speculative authorization/ACL changes.
- **Safety:** documentation-only entry. No Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, PR merge, force update, or branch-protection setting was changed.


## QA321 — fail-closed DATABASE_URL guard for CREATE_OFFER integration runner

## QA321 — fail-closed DATABASE_URL guard for CREATE_OFFER integration runner

- **Priority:** close a destructive-test safety gap found during review of the current PR. The CREATE_OFFER integration runner applies fixture DDL and branch migrations directly to the supplied `DATABASE_URL`, but unlike the wrapper-owner, function-ACL, and legacy-message runners it previously relied only on a comment saying not to use Production. This was a guard omission in test tooling, not evidence of a Production incident.
- **Baseline at start of this run:** PR #26 OPEN, DRAFT, unmerged, `mergeable=true`; head `a776df21395d2e96af8c5cacdc3d3a8d8025f4ea`; 1,314 commits ahead of `main`, 0 behind, 79 changed files. Baseline QIMA CI #1169 (run `42868469707`) and CodeQL #1120 (run `42868469593`) were SUCCESS; Vercel Preview status was SUCCESS.
- **Code changes on work branch `work/create-offer-runner-url-guard-20261111-0336`:**
  - `tests/sql/run-create-offer-integration.sh`: before constructing any `psql` command or connecting, reject any `DATABASE_URL` that is not exactly PostgreSQL/PostgreSQL URI with credentials, host `localhost`, `127.0.0.1`, or `[::1]`, port `5432`, database `qima_test`, and no query string. Rejection exits 2 with a generic message; credentials are not printed.
  - `tests/sql/test-create-offer-integration-runner-guard.sh` (new): seven unsafe destinations (remote host, wrong database, query parameters, wrong port, wrong scheme, lookalike hostname, and non-allowlisted loopback address) must be rejected before the `psql` stub is called. Three supported loopback URI forms must pass the guard and reach the stub. The stub never opens a database connection.
  - `.github/workflows/ci.yml`: run the new guard regression immediately before the real CREATE_OFFER integration runner in the PostgreSQL 16 job.
- **Work commits:** `2f542e2efa5ec44744f10028dbfc8766e12676e6` (guard), `129b6be5629d4a4f4303b11b905a8effcbaa706f` (regression), `f0254ad457072feaa78dc11383f1caca899f66fa` (CI step), and `043942e096d9656749ea97360cac93771c012eca` (correct exact loopback regex). The work branch is four commits ahead of the baseline and zero behind; its three-file diff is 102 additions, 0 deletions.
- **Local harness:** Bash syntax checks passed for the guard and test harness. A stubbed shell harness exercised seven rejected URL shapes and three accepted loopback forms; result: `CREATE_OFFER integration runner URL guard regression PASS`. The CI run below is the authoritative execution of the committed repository test.
- **QIMA CI #1170:** run `42877621065` on exact code HEAD `043942e096d9656749ea97360cac93771c012eca` — **IN PROGRESS at this checkpoint**. The new step `Verify CREATE_OFFER integration runner rejects unsafe database URLs` is **SUCCESS** in the PostgreSQL 16 job. The PostgreSQL 16 CREATE_OFFER integration and PostgreSQL 17.6 integration steps were still running. In the browser/build job, workflow-concurrency guard, PostgreSQL version-guard boundary test, `npm ci`, npm audit, and TypeScript completed SUCCESS; build/Chromium/Playwright were not all complete at this checkpoint. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42877621065).
- **CodeQL #1121:** run `42877620867` on the same code HEAD — **IN PROGRESS at this checkpoint**. [Workflow run](https://github.com/meridane/QimaTrade-MVP/actions/runs/42877620867).
- **Current PR metadata after code fast-forward:** OPEN, DRAFT, unmerged, `mergeable=true`; head `043942e096d9656749ea97360cac93771c012eca`; 1,318 commits ahead of `main`, 0 behind, 80 changed files. The PR branch was advanced with a non-force fast-forward using the expected prior head SHA. No rebase or branch-protection change occurred.
- **Canonical register:** `docs/QIMA_V1_FUNCTION_REGISTER.md` was re-read on the PR branch. The connector returned blob SHA `0f1c8a802d0bfa95b4726808fa5f418829a81924` but no body because of the large-file retrieval limit. It was not overwritten or truncated; this result is recorded in this append-only QA register.
- **Production/business gates:** no Supabase Production connection was attempted in this run. The earlier read-only catalogue attempt remains blocked by PostgreSQL `28P01`; live owners/ACLs/memberships remain unverified. MKT-1.1 provider/demand eligibility still requires an explicit business ownership decision.
- **Safety:** this guard limits the integration runner to the ephemeral loopback CI database and rejects remote or non-`qima_test` targets before `psql`. No Supabase Production data, schema, migration, RLS policy, grant, secret, persistent configuration, Production deployment, PR merge, force update, or branch-protection setting was changed.
