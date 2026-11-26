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
