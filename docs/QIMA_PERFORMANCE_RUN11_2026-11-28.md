# QimaTrade PERFORMANCE — run 11 (2026-11-28)

## Baseline and isolation

- Main PR #26 was re-read: OPEN / DRAFT / not merged; branch `fix/create-offer-status-contract`; HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`; base `main`.
- PERFORMANCE remains isolated on `work/qima-performance-baseline-20261127-0441`, with the same verified merge-base.
- No application source, SQL, migration, or business contract was changed in this mission.

## Completed GitHub Actions samples

The following are completed validation/CI measurements, not application latency benchmarks.

| Mission snapshot | QIMA CI | Playwright | PostgreSQL 16 | PostgreSQL 17.6 | CodeQL |
|---|---|---:|---|---|---|
| SECURITY | [#2210](https://github.com/meridane/QimaTrade-MVP/actions/runs/46084109873) SUCCESS | 458 passed, 38.2 s | SUCCESS | SUCCESS | [#2134](https://github.com/meridane/QimaTrade-MVP/actions/runs/46084109852) SUCCESS |
| TESTS | [#2211](https://github.com/meridane/QimaTrade-MVP/actions/runs/46084110953) SUCCESS | 456 passed, 36.0 s | SUCCESS | SUCCESS | [#2135](https://github.com/meridane/QimaTrade-MVP/actions/runs/46084110947) SUCCESS |
| QUALITY | [#2212](https://github.com/meridane/QimaTrade-MVP/actions/runs/46084115353) SUCCESS | 441 passed, 40.2 s | SUCCESS | SUCCESS | [#2136](https://github.com/meridane/QimaTrade-MVP/actions/runs/46084115402) SUCCESS |

- Verify logs show the audit, TypeScript, production build, Chromium installation and browser suite completed successfully for all three snapshots.
- PostgreSQL 16 and PostgreSQL 17.6 completed successfully for all three snapshots.
- The expected-failure prepared-transaction harness jobs report their injected failure outcomes by design; the separate assertion jobs succeeded, and the deliberately skipped harness is independently asserted.
- Verify logs include transient `ECONNRESET: Auth network connection reset` messages in these synthetic CI environments even though all listed browser suites passed. Record as a possible harness/network transient; do not interpret as an application or Production incident.
- These browser durations are whole-suite CI timings. They are not route p50/p95/p99, database query latency, or evidence of a performance trend. The snapshots are different branch contents and are not a controlled A/B benchmark.

## Static query-path findings retained

- `getOfferContext` is organized into sequential authentication/profile/membership and demand lookups, followed by parallel Product Master/attribute reads and grouped metadata reads.
- The inspected metadata paths use batched `.in(...)` filters; no N+1 loop was identified in this path.
- This is a source-level inventory only. It does not establish actual query counts under all data conditions or any latency defect.

## Supabase environment availability

A read-only project listing reconfirmed QIMA:
- project ID `yyulzlnrfcbaxovzjbnh`;
- status **INACTIVE**;
- region `ap-southeast-1`;
- PostgreSQL 17.11.0.003.

No database query, log query, resume action, migration, or cost-incurring operation was performed. The project was not reactivated.

## Measurements still blocked

Not measured:
- authenticated route p50/p95/p99;
- per-query PostgREST/RPC latency;
- EXPLAIN ANALYZE / BUFFERS;
- lock waits and row counts under controlled load;
- CPU, memory, or allocation profiles;
- production/staging request timings.

Required to proceed: an explicitly approved non-production base URL, disposable test identity/tenant, and a safe fixture dataset. Do not resume the inactive QIMA project or incur compute cost without owner authorization.

## Next step

Keep the baseline unchanged until an approved staging environment exists. Then execute the documented warm-up and repeated-sample protocol, separate each query wave, and optimize only a segment shown by measurements to be material.

## Static request-budget refinement — getOfferContext

A source-level count of the inspected `app/offers/actions.ts` path yields:

| Operation | Remote calls |
|---|---:|
| Auth `getUser` | 1 |
| Profile lookup | 1 |
| Membership lookup | 1 |
| Demand lookup | 1 |
| Product Master lookup | 1 |
| Product Master attributes lookup | 1 |
| Attribute definitions lookup | 0 or 1 |
| Attribute options lookup | 0 or 1 |
| Attribute units lookup | 0 or 1 |
| **Total** | **6–9** |

The first six calls are sequential/required for a successful context. The two product/attribute reads are issued in one `Promise.all`; the three metadata lookups are issued in a second `Promise.all` and are conditionally skipped when their identifier arrays are empty.

This is a source-derived call budget, not an observed request count or latency measurement. Duplicate IDs in the arrays, data cardinality, PostgREST planning, network overhead and database execution time are not measured here. No deduplication or other optimization is proposed without a controlled benchmark.
