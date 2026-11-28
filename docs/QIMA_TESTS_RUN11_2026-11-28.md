# QimaTrade TESTS — run 11 (2026-11-28)

## Baseline

- Main PR #26 was re-read before work: OPEN / DRAFT / not merged; branch `fix/create-offer-status-contract`; HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`; base `main`.
- TESTS work remains isolated on `work/qima-tests-publish-runtime-20261127-0441`, sharing merge-base `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.
- Prior TESTS snapshot `e9dae30932eed37462f78992d6e1500e0e88de91` completed QIMA CI #2211 and CodeQL #2135 successfully. Verify reported 456 Playwright passed (36.0 s); npm audit, TypeScript, Next.js build, Chromium, the isolated security fixture, PostgreSQL 16 and PostgreSQL 17.6 all succeeded.
- The Verify log included transient Auth `ECONNRESET` messages despite the complete passing suite. No Production incident is inferred.

## Change in this run

Commit [`6fde5b7a`](https://github.com/meridane/QimaTrade-MVP/commit/6fde5b7a9436d802f72c6e78a26e4196b97cd09a) adds a parameterized action-definition RPC upstream failure matrix for HTTP 500, 502, 503 and 504.

For each status the regression asserts:
- result is null and the public error is `ACTION_DEFINITION_LOOKUP_FAILED`;
- internal message/details/hint are not exposed;
- exactly one `get_action_definition_v1` POST occurs;
- no `dt_publish_product_request` call or redirect occurs.

File changed:
- `tests/e2e/action-runtime-publish-product-request.spec.ts`

The runtime implementation and business contract were not changed.

## Validation status at snapshot

- QIMA CI #2214: [run 46090754067](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090754067) IN PROGRESS.
- CodeQL #2138: [run 46090754024](https://github.com/meridane/QimaTrade-MVP/actions/runs/46090754024) IN PROGRESS.
- Initial job observation: npm audit passed; TypeScript was running; build and browser verification were pending; PostgreSQL 16 and 17.6 jobs were active.
- No Playwright result is claimed for the new action-definition matrix until Verify completes.
- Vercel Preview for the new code commit was pending at the last status read.

## Limits

- All upstream responses are synthetic and served locally.
- The tests characterize normalization, single-attempt behavior and diagnostic masking. They do not prove a Production RPC failure or vulnerability.
- No Supabase Production data/schema, migration, secret, grant, RLS policy, or persistent configuration was changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- PR #28 remains OPEN / DRAFT and targets the temporary CI validation base, not `main`.

## Next step

Complete QIMA CI #2214 and CodeQL #2138, then inspect the PostgreSQL 16/17.6 conclusions. Only add further runtime cases if the logs reveal a distinct uncovered contract.
