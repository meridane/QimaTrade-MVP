# QimaTrade — performance mission checkpoint

Date: 2026-11-27 (Asia/Seoul)

## Provenance

- Repository: `meridane/QimaTrade-MVP`
- PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
- Verified base HEAD: `61002cb21aaa738a7f018794ab84bff41a2c6eb2`
- Mission branch: `work/qima-performance-baseline-20261127-0441`
- Branch created directly from the verified PR HEAD

## Reproducible CI timing snapshot

Two consecutive successful runs of the same workflow were inspected using GitHub Actions job start/completion timestamps.

| Job | CI #2035 | CI #2036 | Interpretation |
|---|---:|---:|---|
| Typecheck, audit, build and browser tests | 124 s | 116 s | 1m56s–2m04s |
| CREATE_OFFER PostgreSQL integration | 467 s | 446 s | 7m26s–7m47s |
| PostgreSQL 17.6 compatibility | 433 s | 440 s | 7m13s–7m20s |
| CodeQL JavaScript/TypeScript | 64 s | 66 s | 1m04s–1m06s |

Evidence:
- [QIMA CI #2035](https://github.com/meridane/QimaTrade-MVP/actions/runs/45870613897)
- [QIMA CI #2036](https://github.com/meridane/QimaTrade-MVP/actions/runs/45874542998)
- [CodeQL #1961](https://github.com/meridane/QimaTrade-MVP/actions/runs/45870613891)
- [CodeQL #1962](https://github.com/meridane/QimaTrade-MVP/actions/runs/45874542972)

The PostgreSQL jobs execute in parallel. The Verify job is materially shorter than the database integration jobs. This is a CI pipeline baseline, not an application response-time benchmark. Two runs are useful for orientation but are not enough to establish a statistically stable trend.

## Static request-path inventory

### CREATE_OFFER

In `app/api/actions/create-offer/route.ts`, the source currently performs these dependent steps:
1. Supabase Auth `getUser(token)`.
2. Profile lookup by authenticated user ID.
3. Tenant-membership lookup by authenticated user ID.
4. `get_action_definition_v1` RPC.
5. `execute_create_offer_v1` RPC.

The profile and membership reads occur sequentially after authentication even though they use the same authenticated identity. This is a **measurement candidate only**. No change is justified until route latency and database timing show that this segment is material.

### PUBLISH_PRODUCT_REQUEST

In `app/api/product-requests/publish/route.ts`, the source path includes:
1. Auth `getUser()`.
2. Tenant-membership query.
3. `get_action_definition_v1` RPC.
4. `dt_publish_product_request` RPC.

The subsequent `getSession()` access-token read is not counted as a network round trip here; this source review did not measure its implementation cost.

## Measurement plan before optimization

For a staging environment with explicit authorization and a non-production test tenant:
- record route-level p50/p95/p99 latency, status distribution, and request count;
- separate Auth, PostgREST query, definition RPC and execution RPC timings;
- run warm-up requests, then at least 30 measured samples per route;
- keep payload, user, tenant, region and concurrency fixed between comparisons;
- test concurrency at 1, 5 and 10 requests only with disposable/idempotent fixtures;
- capture query plans only for the exact read queries and only in an approved non-production environment;
- repeat the run and compare confidence intervals before accepting an optimization.

Do not benchmark by creating uncontrolled offers or publishing production requests. Do not log bearer tokens, cookies, personal data or full request bodies.

## Result and next step

- Confirmed: current CI job durations and source-level request ordering above.
- Not measured: production/staging API latency, database query latency, allocations, memory, CPU profiles, N+1 behavior, or end-user page timings.
- No performance optimization was applied; no business contract was changed.
- Next: obtain a safe staging base URL and disposable test identity, run the controlled benchmark, and profile only a segment shown to be material.

No Supabase Production data/schema, migration, secret, grant, RLS policy or persistent configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change was performed.

## Additional CI measurement — TESTS mission run 45891165262

Measured from GitHub Actions job timestamps (not application request latency):

| Job | Duration |
|---|---:|
| TypeScript, audit, build and browser tests | 146 s |
| PostgreSQL integration tests | 446 s |
| PostgreSQL 17.6 compatibility | 438 s |

All three jobs completed successfully. The browser suite reported 436 passed. These figures are a CI baseline sample only; they do not establish p50/p95/p99 API latency, database query cost, or an application performance regression. No optimization was made from this sample.

## SECURITY Verify job sample — QIMA CI 45891959349

- TypeScript, dependency audit, production build and 443 browser tests completed in **145 s**.
- This is a completed Verify-job measurement only. PostgreSQL 16 and 17.6 jobs were still in progress, so no full-workflow duration is recorded.
- The sample is CI infrastructure timing, not application latency; no product optimization is justified by it.

## Completed SECURITY and TESTS CI samples — 2026-11-27

| Mission run | Verify / browser suite | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---|---|---|---|
| SECURITY [45892064684](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892064684) | SUCCESS; 443 passed (39.2 s) | SUCCESS | SUCCESS | [45892064718](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892064718) SUCCESS |
| TESTS [45892188791](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892188791) | SUCCESS; 436 passed (35.9 s) | SUCCESS | SUCCESS | [45892188778](https://github.com/meridane/QimaTrade-MVP/actions/runs/45892188778) SUCCESS |

These are completed CI validation samples, not route/API latency or database query benchmarks. The Verify times above are Playwright suite durations, not total job durations. No optimization is justified by these figures; staging p50/p95/p99 and query-level profiling remain blocked on an approved non-production environment.

## Live database environment availability — 2026-11-27

- Read-only Supabase project metadata reports QIMA as **INACTIVE (paused)** on PostgreSQL 17.11 in ap-southeast-1.
- No SQL, table, query-plan, database-log, or performance query was run; the project was not resumed.
- Without an active approved staging environment and disposable identity, database query timing, API p50/p95/p99, N+1 behavior and CPU/memory profiling remain **not measured**.
- Do not resume the project or incur compute cost without owner authorization. Continue to treat CI durations as infrastructure-only measurements.
## Completed multi-mission CI samples — 2026-11-27

| Mission | QIMA CI run | Playwright | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---:|---:|---|---|---|
| SECURITY | [45901460978](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901460978) | 443 passed (37.2 s) | SUCCESS | SUCCESS | [45901460932](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901460932) SUCCESS |
| TESTS | [45901244355](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901244355) | 436 passed (37.3 s) | SUCCESS | SUCCESS | [45901244710](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901244710) SUCCESS |
| QUALITY | [45901538164](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901538164) | 436 passed (38.1 s) | SUCCESS | SUCCESS | [45901538086](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901538086) SUCCESS |

- These are Playwright suite durations from GitHub Actions logs, not application route latency or database query timings.
- The three runs are validation samples from different branch snapshots; they are not a controlled benchmark and should not be compared as a performance trend.
- No optimization is justified by these values. API p50/p95/p99, database query plans, N+1 behavior, allocations, CPU and memory remain unmeasured.
- The Supabase QIMA project was last reported INACTIVE (paused). No query, resume, or compute-cost action was taken. Continue to require owner authorization or a separate approved staging environment.
## Full GitHub Actions job timing sample — 2026-11-27

Durations below are calculated from the GitHub Actions job `started_at` and `completed_at` timestamps. They describe CI execution, not application performance.

| Mission run | Verify job | PostgreSQL 16 | PostgreSQL 17.6 | Playwright suite |
|---|---:|---:|---:|---:|
| SECURITY [45901460978](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901460978) | 132 s | 447 s | 426 s | 37.2 s |
| TESTS [45901244355](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901244355) | 129 s | 459 s | 433 s | 37.3 s |
| QUALITY [45901538164](https://github.com/meridane/QimaTrade-MVP/actions/runs/45901538164) | 139 s | 457 s | 438 s | 38.1 s |

- All three Verify jobs and both PostgreSQL jobs per run completed successfully.
- The PostgreSQL 16 and 17.6 jobs run concurrently, so their durations should not be summed to estimate wall-clock workflow time.
- These three runs share the same workflow shape but different branch snapshots and are too few for a stable trend. No application performance regression or optimization is inferred.


## Latest completed mission CI timing sample — 2026-11-27

Durations are computed from GitHub Actions job `started_at` and `completed_at` timestamps. They measure CI infrastructure, not application response time.

| Mission run | Verify job | PostgreSQL 16 | PostgreSQL 17.6 | Playwright |
|---|---:|---:|---:|---:|
| SECURITY [45904993720](https://github.com/meridane/QimaTrade-MVP/actions/runs/45904993720) | 125 s | 459 s | 440 s | 36.7 s |
| TESTS [45904998333](https://github.com/meridane/QimaTrade-MVP/actions/runs/45904998333) | 117 s | 461 s | 433 s | 34.9 s |
| QUALITY [45905000099](https://github.com/meridane/QimaTrade-MVP/actions/runs/45905000099) | 116 s | 455 s | 432 s | 35.6 s |

- All three Verify jobs and both PostgreSQL jobs per run completed successfully. The TESTS run reported 437 Playwright passes including the synthetic upstream-503 no-retry/no-redirect case.
- PostgreSQL 16 and 17.6 jobs run concurrently; do not sum their durations to estimate wall-clock workflow time.
- These runs are separate branch snapshots, not a controlled benchmark. No application performance trend, regression or optimization is inferred.
- Application API p50/p95/p99, SQL query plans, N+1 behavior, CPU and memory remain unmeasured. The Supabase QIMA project remains paused; no resume or query was attempted.


## Static query-topology review — 2026-11-27

Reviewed the current PR #26 source for the CREATE_OFFER path and adjacent offer/product metadata reads. This is source inspection, not runtime profiling.

- `app/api/actions/create-offer/route.ts`: after authentication and request validation, the route reads `profiles.actor_id`, then reads `dt_memberships.tenant_id`, then calls the universal action runtime. The two database reads are sequential in the current source. They are a **candidate** for later timing/parallelization review, not a measured bottleneck; authorization and error semantics must be preserved.
- `app/offers/actions.ts`: the product metadata path reads the demand first, then loads product master and product attributes in `Promise.all`, followed by attribute definitions, active options and units in a second `Promise.all`. Options are grouped in memory; no database call was found inside that loop. No N+1 pattern was established in the reviewed function.
- `lib/actions/runtime.ts`: action-definition RPC and the business RPC are sequential by contract. No retry loop was found in the reviewed runtime. Do not parallelize or reorder these calls without an explicit contract analysis.
- No source-level finding alone establishes high latency, excessive allocation, or an N+1 defect. No application code was changed.

Next measurement: on an approved non-production environment, capture per-query and end-to-end timings for authenticated CREATE_OFFER requests, record row counts and query plans, and compare p50/p95/p99 over a repeatable sample before considering changes.


## Partial TESTS follow-up run sample — 2026-11-27

- QIMA CI [#45913960558](https://github.com/meridane/QimaTrade-MVP/actions/runs/45913960558) ran on the TESTS follow-up containing the HTTP 503 diagnostic-redaction assertions.
- Verify job 140228626258 completed **SUCCESS** in **153 s** and reported **437 Playwright passed (39.1 s)**, including the updated 503 no-retry/no-redirect and synthetic details/hint non-disclosure assertions.
- At this checkpoint PostgreSQL 16 job 140228626138 and PostgreSQL 17.6 job 140228626133 were still running. Their durations and the overall workflow result are intentionally left pending until GitHub reports completion.
- This is a CI timing observation only; it is not an application latency benchmark or a controlled comparison with earlier runs.


## Completed mission CI samples — 2026-11-27

The following are completed GitHub Actions observations, not application latency measurements:

| Mission snapshot | QIMA CI | Playwright Verify | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---|---:|---|---|---|
| SECURITY `d8eea385` | [#45914072857](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914072857) SUCCESS | 443 passed, 36.0 s | SUCCESS | SUCCESS | [#45914072774](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914072774) SUCCESS |
| TESTS `14e1f1f0` | [#45914236475](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914236475) SUCCESS | 437 passed, 33.9 s | SUCCESS | SUCCESS | [#45914236465](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914236465) SUCCESS |
| QUALITY `51a7c1fe` | [#45914093235](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914093235) SUCCESS | 436 passed, 34.1 s | SUCCESS | SUCCESS | [#45914093193](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914093193) SUCCESS |

- The SECURITY Verify log includes the isolated tenant-membership fixture. The TESTS Verify log includes the HTTP 503 no-retry/no-redirect and diagnostic-redaction assertions. The QUALITY Verify log includes the keyboard focus-order and scoped OAuth alert checks.
- The SECURITY EXECUTE-ACL fixture assertion added after snapshot `d8eea385` and the TESTS malformed-success-payload regression added after snapshot `14e1f1f0` are newer changes. Their new CI runs are pending/in progress at this checkpoint and are intentionally excluded from the completed samples above.
- These measurements characterize CI execution only. They do not establish QimaTrade request latency, database query plans, N+1 behavior, or production capacity.



## Latest completed branch-validation samples — 2026-11-27

These observations were retrieved from the current mission PR heads before the newest follow-up edits in this run. They are CI validation snapshots, not a controlled performance benchmark.

| Mission snapshot | QIMA CI | Playwright | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL | Vercel |
|---|---|---:|---|---|---|---|
| SECURITY `c61f5370` | [#45924017660](https://github.com/meridane/QimaTrade-MVP/actions/runs/45924017660) SUCCESS | 443 passed (35.9 s) | SUCCESS | SUCCESS | [#45924017684](https://github.com/meridane/QimaTrade-MVP/actions/runs/45924017684) SUCCESS | SUCCESS |
| TESTS `981cb906` | [#45919013224](https://github.com/meridane/QimaTrade-MVP/actions/runs/45919013224) SUCCESS | 439 passed (37.7 s) | SUCCESS | SUCCESS | [#45919013147](https://github.com/meridane/QimaTrade-MVP/actions/runs/45919013147) SUCCESS | Provider quota failure |
| QUALITY `51a7c1fe` | [#45914093235](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914093235) SUCCESS | 436 passed (34.1 s) | SUCCESS | SUCCESS | [#45914093193](https://github.com/meridane/QimaTrade-MVP/actions/runs/45914093193) SUCCESS | Provider quota failure |

- The SECURITY Verify log explicitly reports the isolated publish-RPC ACL and tenant-membership fixture passing. PostgreSQL 16 and 17.6 both completed successfully.
- The TESTS sample includes the malformed-success payload coverage as it existed on HEAD `981cb906`; it does not include the newer alias-conflict and non-object payload follow-ups added after this snapshot.
- The QUALITY sample validates the keyboard focus-order and OAuth alert checks already present on HEAD `51a7c1fe`.
- These are independent branch snapshots and different test counts. They must not be treated as a performance trend or compared as an application benchmark.
- No application API p50/p95/p99, SQL query plan, N+1 behavior, CPU/memory profile, or end-user page timing was measured. No optimization was made.



## Current follow-up validation state — 2026-11-27

The latest SECURITY and TESTS commits contain new code/test cases and are not included in the completed timing samples above.

| Mission | Current HEAD | QIMA CI | CodeQL | Vercel |
|---|---|---|---|---|
| SECURITY | `726941e2517d36654be8123fef0051bdfa80731c` | [#45932892701](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892701) PENDING, no jobs published at last read | [#45932892666](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892666) SUCCESS | Provider build-rate quota failure |
| TESTS | `2beb027f81c9dc2d7ff8dabf1c2f32e4685c85e4` | [#45932862346](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932862346) PENDING, no jobs published at last read | [#45932861481](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932861481) SUCCESS | Provider build-rate quota failure |

- These pending CI runs are not treated as performance samples and no Playwright or PostgreSQL result is inferred from them.
- The CodeQL successes do not replace QIMA CI validation.
- The Vercel failure is the external `api-deployments-free-per-day` quota response, not an application performance measurement.
- No staging environment was made available; API latency, database plans, allocations, CPU and memory remain unmeasured. No optimization was applied.

## Completed follow-up CI samples — SECURITY and TESTS — 2026-11-27

These are GitHub Actions measurements from the two branch snapshots; they are not application latency benchmarks.

| Mission snapshot | QIMA CI | Playwright | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---|---:|---|---|---|
| SECURITY `726941e` | [#45932892701](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892701) SUCCESS | 445 passed (35.5 s) | SUCCESS | SUCCESS | [#45932892666](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892666) SUCCESS |
| TESTS `2beb027` | [#45932862346](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932862346) SUCCESS | 439 passed (37.1 s) | SUCCESS | SUCCESS | [#45932861481](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932861481) SUCCESS |

- The SECURITY sample includes the two UUID input-rejection cases and the isolated publish-RPC security fixture.
- The TESTS sample includes the malformed/non-object/conflicting-alias publish-result cases, but not the later positive case for matching camelCase/snake_case aliases with case-only UUID differences.
- The two snapshots have different suite contents and are not a controlled before/after benchmark. Do not infer an application performance trend from their durations.
- Vercel's combined status for these mission branches was blocked by the provider's daily deployment quota. GitHub Actions validation is independent.
- No API p50/p95/p99, SQL query plan, N+1 behavior, CPU/memory profile, or end-user page timing was measured. No optimization was made.

## Superseding CI status — latest SECURITY and TESTS branch snapshots — 2026-11-27

- SECURITY code/test HEAD `726941e2517d36654be8123fef0051bdfa80731c` is now fully validated by QIMA CI [#45932892701](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892701): **445 Playwright tests passed (35.5 s)**, isolated security fixture PASS, PostgreSQL 16 and 17.6 SUCCESS, TypeScript/audit/build SUCCESS. CodeQL [#45932892666](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892666) SUCCESS.
- TESTS code/test HEAD `2beb027f81c9dc2d7ff8dabf1c2f32e4685c85e4` is fully validated by QIMA CI [#45932862346](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932862346): **439 Playwright tests passed (37.1 s)**, isolated security fixture PASS, PostgreSQL 16 and 17.6 SUCCESS, TypeScript/audit/build SUCCESS. CodeQL [#45932861481](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932861481) SUCCESS.
- A subsequent TESTS-only positive regression for equivalent camelCase/snake_case UUID aliases was committed as `4afdf99de8cf665731eb9f168d2359b1659bba2f`; its new QIMA CI [#45938350591](https://github.com/meridane/QimaTrade-MVP/actions/runs/45938350591) is **IN PROGRESS** and CodeQL [#45938350660](https://github.com/meridane/QimaTrade-MVP/actions/runs/45938350660) is **IN PROGRESS**. The earlier 439-test result does not include this new test.
- Documentation-only closeout commits on SECURITY and PERFORMANCE do not alter the validated SECURITY code/test snapshot. The current PR #27 and #28 Vercel statuses are PENDING; no new Preview success is inferred.
- These timings are CI test durations, not application route latency. The samples have different suite contents and are not a controlled performance comparison. No application optimization is justified or applied.
- Staging API p50/p95/p99, query plans, N+1 behavior, CPU/memory profiles and page timings remain unmeasured because no approved active non-production environment is available.

## Latest mission-head validation queue — 2026-11-27

| Mission | Current PR head | QIMA CI | CodeQL | Vercel |
|---|---|---|---|---|
| SECURITY | `64997f6b6ea801dfb4881857d1497f63c2f35373` | [#45938444757](https://github.com/meridane/QimaTrade-MVP/actions/runs/45938444757) PENDING | [#45938444751](https://github.com/meridane/QimaTrade-MVP/actions/runs/45938444751) IN PROGRESS | Provider daily build-rate quota failure |
| TESTS | `54be4b92df3423f957e2b5c685e1e384982a7b7e` | [#45938477648](https://github.com/meridane/QimaTrade-MVP/actions/runs/45938477648) PENDING | [#45938477677](https://github.com/meridane/QimaTrade-MVP/actions/runs/45938477677) IN PROGRESS | Provider daily build-rate quota failure |

- The TESTS HEAD includes the corrected positive alias-equivalence fixture using hexadecimal letters and explicitly asserting that the uppercase UUID differs from the lowercase UUID. The earlier run #45938350591 used the superseded numeric-only fixture and is not evidence for this corrected test.
- The SECURITY HEAD includes documentation closeout of the UUID validation CI result; the validated code/test snapshot is `726941e` (445 Playwright passed, PostgreSQL 16/17.6 and CodeQL passed). The new documentation HEAD has its own pending QIMA CI and running CodeQL.
- These workflow states are validation status only, not performance measurements. No API latency, query plans, N+1 behavior, CPU/memory profile or end-user timings were collected.


## Latest verified mission CI and offer-query inventory — 2026-11-27

### Comparable boundaries and completed snapshots

| Mission snapshot | Verify / Playwright | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---|---|---|---|
| SECURITY code/test `726941e` | 445 passed · 35.5 s | SUCCESS | SUCCESS | SUCCESS |
| TESTS code/test `54be4b9` | 440 passed · 36.0 s | SUCCESS | SUCCESS | SUCCESS |
| QUALITY code/test `e94bd8e` | 436 passed · 35.6 s | SUCCESS | SUCCESS | SUCCESS |

- SECURITY evidence: QIMA CI [#45932892701](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892701), CodeQL [#45932892666](https://github.com/meridane/QimaTrade-MVP/actions/runs/45932892666).
- TESTS evidence: QIMA CI [#45941406708](https://github.com/meridane/QimaTrade-MVP/actions/runs/45941406708), CodeQL [#45941406675](https://github.com/meridane/QimaTrade-MVP/actions/runs/45941406675).
- QUALITY evidence: QIMA CI [#45905000099](https://github.com/meridane/QimaTrade-MVP/actions/runs/45905000099), CodeQL [#45905000152](https://github.com/meridane/QimaTrade-MVP/actions/runs/45905000152).

These suites have different test contents and counts; the Playwright durations are CI diagnostics only, not a controlled performance trend or application latency measurement.

### Static query-count inventory — PR #26 HEAD `61002cb`

- `app/offers/actions.ts:getOfferContext`: Auth user lookup, profile lookup, membership lookup, and demand lookup are sequential. Product plus attribute-row reads are issued together with `Promise.all`; definition, option, and unit reads are issued together with a second `Promise.all`. This is a bounded query graph, not an observed N+1. The source implies up to nine HTTP/database operations across sequential phases (including Auth), but no duration is inferred.
- `app/offers/actions.ts:createOffer`: Auth, profile, membership, demand, action-definition RPC, and CREATE_OFFER execution RPC form sequential phases. This is a candidate for end-to-end latency measurement, not a confirmed bottleneck.
- The metadata assembly loops operate on already-fetched arrays/maps; no database call occurs inside those loops in the inspected function.
- No batching, parallelization, or contract change was applied. Any optimization must first measure per-phase latency and preserve the current tenant/auth ordering.

### Current measurement limits

- No approved active staging environment was available for route p50/p95/p99, SQL plans, CPU/memory profiling, or end-user page timing.
- The Supabase QIMA project’s last recorded state is INACTIVE; no reactivation or remote database query was attempted.
- The new SECURITY offer-context error-boundary and QUALITY country-selector accessibility changes have pending fresh CI at their latest HEADs. Their results are not included in the completed samples above.
- No application optimization is justified by these CI measurements; no optimization was made.


## Mission validation queue — latest heads — 2026-11-27

| Mission | Latest HEAD | QIMA CI | CodeQL | Vercel |
|---|---|---|---|---|
| SECURITY | `a4900ee1` | [#45945561058](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945561058) PENDING (no jobs published at last read) | [#45945561183](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945561183) SUCCESS | Provider build-rate quota failure |
| TESTS | `7eb540bd` | [#45945714444](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714444) IN PROGRESS | [#45945714513](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714513) IN PROGRESS | Provider build-rate quota failure |
| QUALITY | `6162a67e` | [#45945670309](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945670309) PENDING (no jobs published at last read) | [#45945670307](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945670307) IN PROGRESS | Provider build-rate quota failure |
| PERFORMANCE | `c547085c` | No run (documentation-only branch) | No run (documentation-only branch) | Provider build-rate quota failure |

- TESTS code/test snapshot `54be4b92` is already fully validated by CI #45941406708 (440 Playwright passed, PostgreSQL 16/17.6 SUCCESS) and CodeQL #45941406675 SUCCESS. The newer documentation HEAD `7eb540bd` has its own pending/in-progress checks.
- SECURITY’s new offer-context diagnostic-boundary test and QUALITY’s new country-selector browser test are not yet validated. Prior successful snapshots do not cover these new changes.
- Provider quota failures are external Preview-build constraints, not GitHub Actions test failures.


### SECURITY HEAD supersession — 2026-11-27

- The SECURITY branch advanced from `a4900ee1` to `537f3859` after adding a source-contract assertion for the offer-context error-mapper call sites and switching the test's repository path resolution to `process.cwd()`.
- At the final read, no new workflow run for `537f3859` had appeared in the commit workflow-run listing. The earlier CodeQL SUCCESS on `a4900ee1` is not transferred to this final HEAD.
- The final SECURITY Playwright/TypeScript/build/PostgreSQL result remains **PENDING / not yet available**. Vercel remains blocked by the provider daily build-rate quota.


### Superseding workflow state — 2026-11-27

- SECURITY final HEAD `537f3859`: QIMA CI [#45945862929](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945862929) is **PENDING** with no jobs published at the latest read; CodeQL [#45945862983](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945862983) is **IN PROGRESS**. No final test result is claimed.
- TESTS documentation HEAD `7eb540bd`: QIMA CI [#45945714444](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714444) is **IN PROGRESS**; PostgreSQL 16 and 17.6 are at the final runner write-privilege characterization, and Verify is still active. CodeQL [#45945714513](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714513) is **SUCCESS**.
- QUALITY HEAD `6162a67e`: QIMA CI [#45945670309](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945670309) is **PENDING** with no jobs published at the latest read; CodeQL [#45945670307](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945670307) is **SUCCESS**.
- Vercel Preview statuses on all three mission heads are blocked by the provider's daily deployment quota. This is not a GitHub Actions failure.


### TESTS Verify closeout — current documentation HEAD — 2026-11-27

- TESTS HEAD `7eb540bd`: Verify job `140329806236` in QIMA CI [#45945714444](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714444) completed **SUCCESS** with **440 Playwright tests passed (35.7 s)**. The malformed successful publish-result regression is included in the passing suite.
- PostgreSQL 16 job `140329806149` and PostgreSQL 17.6 job `140329806090` remain **IN PROGRESS** at the final full-runner write-privilege characterization. Therefore the overall QIMA CI run is not yet SUCCESS.
- CodeQL [#45945714513](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714513) is **SUCCESS**.


## Mission validation refresh — 2026-11-27 15:22 KST

| Mission code/test snapshot | QIMA CI | Verify / Playwright | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---|---|---|---|---|
| SECURITY `537f3859` | [#45945862929](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945862929) SUCCESS | 447 passed · 34.9 s | SUCCESS | SUCCESS | [#45945862983](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945862983) SUCCESS |
| TESTS `7eb540bd` | [#45945714444](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714444) SUCCESS | 440 passed · 35.7 s | SUCCESS | SUCCESS | [#45945714513](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945714513) SUCCESS |
| QUALITY previous `6162a67e` | [#45945670309](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945670309) FAILURE | Browser job: 6 failed | SUCCESS | SUCCESS | [#45945670307](https://github.com/meridane/QimaTrade-MVP/actions/runs/45945670307) SUCCESS |

- QUALITY failure diagnosis from the Verify job log: one new accessibility test reached protected `/offers/new` without authenticating; five existing offer-confirmation flows still expected the removed `aria-haspopup=listbox` / `role=listbox` semantics and timed out. TypeScript, dependency audit, production build and the security fixture succeeded; the PostgreSQL jobs also succeeded. This is a test integration regression from the semantic UI change, not a measured performance issue.
- QUALITY follow-up is now on HEAD `31d88dc8`: shared test authentication helper, authenticated accessibility smoke, and all five country-selection flows updated to the labelled button/group contract. QIMA CI [#45951688863](https://github.com/meridane/QimaTrade-MVP/actions/runs/45951688863) is **PENDING**; CodeQL [#45951688883](https://github.com/meridane/QimaTrade-MVP/actions/runs/45951688883) is **IN PROGRESS**; Vercel Preview is **PENDING**. No result is inferred before those checks finish.
- The SECURITY and TESTS snapshots above are fully validated; the QUALITY fix is not yet validated. These CI timings are browser-suite diagnostics only, not application latency benchmarks.
- No p50/p95/p99, SQL plan, CPU/memory profile or user-perceived page timing was collected. No performance optimization was made. An approved active staging environment remains required.
- No Supabase Production data/schema, migration, secret, grant, RLS policy, Production deployment, PR merge, force-push or branch-protection change was performed.