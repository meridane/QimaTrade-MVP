# QimaTrade PERFORMANCE — run 12 closeout (2026-11-29)

## Baseline and isolation
- Main PR #26 was re-read at HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`; it remains OPEN / DRAFT / not merged.
- PERFORMANCE remains isolated on `work/qima-performance-baseline-20261127-0441`, based on the verified PR #26 snapshot. This closeout does not merge or synchronize mission branches.
- Previous branch HEAD before this journal: `ace1d784f510fcae68f5eb8bc8bd1abb3433f1f3`.

## Tested change
- Tested code commit: [`7ae99848`](https://github.com/meridane/QimaTrade-MVP/commit/7ae99848eafb378644fe0b0a0338192dc3d35db2).
- File: `tests/e2e/offer-context-query-budget.spec.ts`.
- The AST query-shape guard now rejects Supabase `.from()` reads, `.rpc()` calls, and `executeUniversalAction` dispatches inside per-item `.map()` callbacks for the reviewed offer-context paths. The `createOffer` dispatch remains bounded to exactly one call.
- This is a static structural regression guard. It does not change runtime queries or the CREATE_OFFER business contract.

## Final GitHub Actions evidence
- QIMA CI [#2272](https://github.com/meridane/QimaTrade-MVP/actions/runs/46179658296) completed **SUCCESS**.
- Verify job `141086115198` completed **SUCCESS** with **438 Playwright tests passed (38.5 s)**. The new test `createOffer keeps demand lookup and action dispatch bounded independently of attribute count` passed explicitly in **16 ms**.
- Dependency audit, TypeScript, Next.js production build, Chromium/browser tests, and the isolated QIMA security-contract fixture all completed successfully. The fixture cleanup removed its disposable container, network, and named volume.
- PostgreSQL 16 job `141086114960` completed **SUCCESS**; PostgreSQL 17.6 job `141086115241` completed **SUCCESS**. Both completed the CREATE_OFFER integration/concurrency, replay, runner-safety, and legacy RLS/ACL checks.
- CodeQL [#2195](https://github.com/meridane/QimaTrade-MVP/actions/runs/46179658293) completed **SUCCESS**.
- Vercel status for the tested code snapshot `7ae99848` was **SUCCESS**.
- Prepared-transaction failure-injection jobs reported their expected injected FAILURE outcomes; their independent assertion jobs completed SUCCESS. The intentionally skipped harness remained SKIPPED and its assertion completed SUCCESS. No unexpected failing job remained.

## Preview quota and performance limits
- The documentation branch HEAD before this closeout (`ace1d784f510fcae68f5eb8bc8bd1abb3433f1f3`) has a combined Vercel **FAILURE** caused by the provider's `build-rate-limit` / `api-deployments-free-per-day` quota. This is external to GitHub Verify and CodeQL. No quota bypass was attempted.
- No database latency, throughput, p50/p95/p99, EXPLAIN plan, buffer, lock-wait, CPU, or memory benchmark is claimed. The AST duration is a test runtime, not SQL latency. An authorized active non-Production staging environment is still required before runtime optimization.

## Safety
- No Supabase Production data/schema, migration, secret, grant, RLS policy, or persistent configuration was changed.
- No Production deployment, PR merge, force-push, or branch-protection change was made.
- This is a documentation-only closeout; tested code remains `7ae99848`.
