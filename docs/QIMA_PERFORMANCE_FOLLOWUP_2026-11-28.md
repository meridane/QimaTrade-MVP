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
