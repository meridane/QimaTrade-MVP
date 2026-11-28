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

## New run 11 code/test validation samples

| Mission | QIMA CI | Playwright | Verify | CodeQL | PostgreSQL 16 / 17.6 |
|---|---|---:|---|---|---|
| SECURITY | [#2213](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090747586) | 461 passed, 36.3 s | SUCCESS | [#2137](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090747578) SUCCESS | IN PROGRESS / IN PROGRESS |
| TESTS | [#2214](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090754067) | 460 passed, 36.6 s | SUCCESS | [#2138](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090754024) SUCCESS | IN PROGRESS / IN PROGRESS |
| QUALITY | [#2215](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090757958) | 441 passed, 35.8 s | SUCCESS | [#2139](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090757968) SUCCESS | IN PROGRESS / IN PROGRESS |

The three Verify jobs completed successfully, including dependency audit, TypeScript, production build, Chromium and Playwright. The three PostgreSQL pairs are still at step 26, full CREATE_OFFER runner write-privilege characterization; no PostgreSQL conclusion is claimed yet. These suite durations remain CI measurements, not application latency benchmarks.


## Closeout of run 11 PostgreSQL validation

The three previously pending QIMA CI runs have now completed. Their workflow job summaries show both PostgreSQL jobs and the Verify job completed successfully:

| Mission | QIMA CI | PostgreSQL 16 integration | PostgreSQL 17.6 compatibility | Verify |
|---|---|---|---|---|
| SECURITY | [#2213](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090747586) | SUCCESS | SUCCESS | SUCCESS — 461 Playwright |
| TESTS | [#2214](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090754067) | SUCCESS | SUCCESS | SUCCESS — 460 Playwright |
| QUALITY | [#2215](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090757958) | SUCCESS | SUCCESS | SUCCESS — 441 Playwright |

- The PostgreSQL 16 job completed its CREATE_OFFER integration, replay, runner-privilege, legacy RLS/ACL and cleanup steps successfully.
- The PostgreSQL 17.6 compatibility job completed its corresponding compatibility, replay, wrapper-owner and EXECUTE ACL steps successfully.
- The prepared-transaction setup/cleanup failure-injection jobs intentionally ended with FAILURE conclusions. Their separate assertion jobs completed SUCCESS and confirmed that those failures remain blocking.
- The intentionally skipped cleanup harness remained SKIPPED and its separate assertion passed.
- CodeQL #2137, #2138 and #2139 each completed SUCCESS.

This closeout supersedes the earlier run-11 status above that recorded the three PostgreSQL pairs as IN PROGRESS. It does not claim that the new run-12 changes are validated.

The Playwright durations remain whole-suite CI timings, not application p50/p95/p99 or a controlled performance benchmark. The QIMA Supabase project remains INACTIVE; no database was resumed or queried.


## Run 12 snapshot — independent branch verification

- SECURITY code commit [566c2f4e](https://github.com/meridane/QimaTrade-MVP/commit/566c2f4eb06c2374fb0db0050ab2e7184a612fd3): QIMA CI #2221 is PENDING with no jobs published; CodeQL #2145 is SUCCESS.
- TESTS code commit [3d3041a3](https://github.com/meridane/QimaTrade-MVP/commit/3d3041a35860464ab887104bd8c295e6638199a4): QIMA CI #2219 remains IN PROGRESS overall; Verify SUCCESS with 461 Playwright passed (35.8 s), including the malformed publish JSON test; PostgreSQL 16/17.6 jobs remain active; CodeQL #2143 is SUCCESS.
- QUALITY code commit [864c4df6](https://github.com/meridane/QimaTrade-MVP/commit/864c4df66510551e6de217c061a4e5a072927b6a): QIMA CI #2222 remains IN PROGRESS; Verify passed audit, TypeScript, build, Chromium and the browser smoke-test step, while the security-contract fixture is active; PostgreSQL 16/17.6 jobs remain active; CodeQL #2146 is SUCCESS.
- No run-12 Playwright result is claimed yet.
- Branch comparisons against PR HEAD 61002cb21aaa738a7f018794ab84bff41a2c6eb2 report a common merge-base and zero behind for all four mission branches. Ahead counts after run-12 changes: SECURITY 98, TESTS 70, PERFORMANCE 56, QUALITY 71.
- No application source, SQL, migration or business contract was changed by PERFORMANCE. The six-to-nine request budget remains source-derived only; no application latency benchmark was performed.

This update records CI state only. It does not imply a controlled performance result or a Production measurement.


### Run 12 status refresh — 2026-11-28 10:45 KST

All three run-12 CodeQL workflows completed SUCCESS. QIMA CI #2219 and #2222 remain active in browser verification and PostgreSQL jobs. QIMA CI #2221 remains pending with no jobs published. No run-12 Playwright result is inferred.


### Run 12 Verify progress — 2026-11-28

- TESTS Verify completed SUCCESS with 461 Playwright passed (35.8 s); the new malformed publish JSON test is explicitly PASS. PostgreSQL 16/17.6 remain active, so QIMA CI #2219 is still in progress overall.
- QUALITY browser smoke-test step completed SUCCESS, but the Verify job is still waiting for the isolated security-contract fixture. PostgreSQL 16/17.6 remain active; no final Playwright count is claimed.
- SECURITY QIMA CI #2221 remains pending with no jobs published. All three run-12 CodeQL workflows are SUCCESS.
