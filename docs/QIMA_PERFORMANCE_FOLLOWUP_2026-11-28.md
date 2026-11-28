# QIMA PERFORMANCE — follow-up 2026-11-28

## Scope and branch
- Branch: `work/qima-performance-baseline-20261127-0441`
- Tested code head: `46a2d4faa7243e1299c45412cf0eee7ee489b47c`
- Validation PR: [#31](https://github.com/meridane/QimaTrade-MVP/pull/31), OPEN / DRAFT, targets `ci/qima-mission-validation-base-20261127`.
- Source base: PR #26 HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.

## New source-level guard
- File: `tests/e2e/offer-context-query-budget.spec.ts`.
- Initial test commit: `d77e2beea801ade3a8fe0be247491e737d1b899c`.
- Type-safety correction: `46a2d4faa7243e1299c45412cf0eee7ee489b47c`.
- TypeScript AST inspection asserts that `getOfferContext` contains exactly six grouped Supabase `.from()` query builders for demands, product masters, product-master attributes, attribute definitions, options and units.
- It asserts that no `.from()` query is nested inside per-attribute `.map()` callbacks, and that the two `Promise.all` waves and three `.in()` metadata lookups remain explicit.

This is a static regression guard for query-plan shape. It is not a latency benchmark and does not measure real PostgREST payload size, query plans, buffers, lock waits, CPU or memory.

## Validation
- QIMA CI [run 46098455377](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098455377): IN PROGRESS; Verify and PostgreSQL 16/17.6 jobs active.
- CodeQL [run 46098455416](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098455416): IN PROGRESS.
- Vercel Preview: pending at the latest status read.

## Benchmark gate
The QIMA Supabase project remains inactive and no authorized staging environment is available. Do not run `EXPLAIN ANALYZE`, live traces or data queries against Production. Do not optimize based on CI duration or this static AST guard alone.

## Next step
Validate the new AST guard in Verify, then obtain an authorized staging project and deterministic non-production fixtures before any real latency or query-plan profiling.


## CodeQL and Verify progress update
- CodeQL [run 46098455416](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098455416) for code head `46a2d4fa` completed **SUCCESS**.
- QIMA CI [run 46098455377](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098455377) remains IN PROGRESS. npm audit, TypeScript and production build passed; Chromium installation completed; Playwright and both PostgreSQL jobs were still active at the latest read. The AST guard has no final browser result yet.
- This remains a static N+1 guard, not a live benchmark.


## Browser verification closeout
- Verify job `140835169048` in QIMA CI [run 46098455377](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098455377) completed SUCCESS: dependency audit, TypeScript, production build, Playwright and the isolated security fixture passed.
- Playwright completed **436 tests**. The new AST query-plan guard is explicitly PASS (22 ms).
- PostgreSQL 16 and 17.6 jobs remain IN PROGRESS, so the overall QIMA CI is not yet closed.
- CodeQL [run 46098455416](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098455416) is SUCCESS.

 
## Parallel-wave query-plan guard — 2026-11-28

- Strengthened tests/e2e/offer-context-query-budget.spec.ts to assert the first Promise.all contains the product_masters and product_master_attributes reads, and the second contains the attribute_definitions, attribute_options and attribute_units reads.
- The three .in() metadata lookups must remain inside the second parallel wave; the test still rejects Supabase reads inside per-attribute .map() callbacks.
- Commit: https://github.com/meridane/QimaTrade-MVP/commit/6cfbe7ff7b6a97a0ba9956937f71cbdf7c071f1f.
- Previous code head 46a2d4fa is fully validated by QIMA CI #46098455377: 436 Playwright passed, including the original AST guard; Verify succeeded; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 succeeded. CodeQL #46098455416 succeeded.
- No QIMA CI or CodeQL run was visible for new head 6cfbe7ff at this checkpoint. The repository workflow file currently triggers on push to main, pull requests targeting main, schedule and workflow_dispatch; the mission PR targets the temporary validation base. An authorized workflow dispatch or equivalent CI trigger is required before claiming this new AST assertion passed.
- This remains a static query-shape guard, not a latency benchmark. No optimization or Production query was performed. A non-Production staging environment is still required for p50/p95/p99, EXPLAIN/BUFFERS, CPU and memory profiling.

 
## Parallel-wave AST guard — Verify closeout

- New code head 6cfbe7ff: QIMA CI [#46106210330](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106210330), Verify job 140859428821 **SUCCESS**, **436 Playwright passed**.
- The strengthened query-plan AST guard explicitly passed (31 ms), confirming the first Promise.all holds the product/product-attribute reads and the second holds the three grouped metadata reads.
- TypeScript, dependency audit, production build and isolated QIMA security fixture all passed.
- CodeQL [#46106210349](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106210349) **SUCCESS**.
- PostgreSQL 16 and 17.6 jobs remain IN PROGRESS at full runner write-privilege characterization. Overall QIMA CI is not yet closed.
- No latency claim is made from this AST test or Playwright duration. The staging/benchmark gate remains unchanged.

 
## External preview and staging availability

- Vercel Preview for code head 6cfbe7ff reports SUCCESS.
- Read-only Supabase metadata confirms QIMA project yyulzlnrfcbaxovzjbnh is INACTIVE, region ap-southeast-1, PostgreSQL 17.11.0.003. No SQL query was attempted against the inactive project.
- No authorized non-Production staging project is currently available for real query plans, latency percentiles, buffers, lock waits, CPU or memory profiling.


## Final PostgreSQL and CI closeout — 2026-11-28 14:10 KST

- Final tested code head: `6cfbe7ff7b6a97a0ba9956937f71cbdf7c071f1f`.
- QIMA CI [#2231](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106210330) is **SUCCESS**. Verify job `140859428821` completed **SUCCESS** with **436 Playwright tests passed**. The strengthened AST query-wave guard explicitly passed in 31 ms; dependency audit, TypeScript, Next.js production build, Chromium and the isolated QIMA security fixture also passed.
- PostgreSQL 16 job `140859428597` completed **SUCCESS** (48 job steps); PostgreSQL 17.6 job `140859428928` completed **SUCCESS** (33 job steps).
- CodeQL [#2155](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106210349) is **SUCCESS**. Vercel Preview for code head `6cfbe7ff` was **SUCCESS**.
- The prepared-transaction failure-injection outcomes and skipped harness are expected and their separate assertion jobs succeeded.
- The later documentation-only branch HEAD `0e0a6ddf` currently has combined Vercel status **FAILURE** with provider target `build-rate-limit`. This is an external preview quota failure, not a CI or CodeQL failure. No application optimization was performed.
- The AST guard proves only the inspected static query shape: six table reads, no Supabase reads inside per-attribute map callbacks, and two explicit Promise.all waves with grouped metadata .in() calls. It is not a latency benchmark and does not establish p50/p95/p99, buffers, lock waits, CPU or memory.
- QIMA Supabase remains inactive and no authorized non-Production staging environment is available. No SQL profiling or live query was run.
- No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made in this closeout. Documentation only; `[skip ci]` is used because the tested code head is unchanged.
