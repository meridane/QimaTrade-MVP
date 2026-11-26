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
