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
