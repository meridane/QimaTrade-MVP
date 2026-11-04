# QimaTrade V1 Function Register — QA185 addendum

> Append-only supplement for `docs/QIMA_V1_FUNCTION_REGISTER.md`.
> The canonical register at the QA184 baseline is blob `41c26372c351e197c93d149241a1d3825a576ac6` (1,072,613 bytes). The GitHub file-content connector returned the blob metadata but not its body because the file exceeds its supported retrieval size. To avoid replacing or truncating the historical register without its full contents, this QA entry is kept in a separate, reviewable addendum.

## QA185 — unavailable first duplicated demandId

- **Test file:** `tests/e2e/legacy-offers-route-contract.spec.ts`
- **Test commit:** `3812f476b418a5b54b78c6943b628b7958422423`
- **Scenario:** submit a UUID-shaped but unavailable first `demandId`, followed by a different valid-looking duplicate.
- **Fixture:** Supabase client is mocked with `demand: null`; no remote database is queried.
- **Expected/observed assertions in the test:** HTTP 400 with `Demand not found or unavailable.`; one authenticated-user lookup; profile lookup for the authenticated user; exactly one demand lookup using the first UUID; no product-master lookup; zero offer insertions; null insert payload.
- **Contract characterized:** `FormData.get("demandId")` uses the first multipart occurrence. The later duplicate is not used. An unavailable first reference stops processing before product lookup and offer insertion.
- **Security interpretation:** this is a deterministic unit/integration-style characterization with a mocked Supabase client. It is not evidence of a production authorization bypass or a confirmed vulnerability.
- **CI status at this addendum revision:** pending; record final run URLs and exact results in the next revision.
- **Safety:** no application handler, SQL, migration, Supabase production data, policy, deployment, merge, or branch-protection setting changed.

## Register maintenance note

The canonical register's QA184 tail was inspected from commit `0eca4833bae236f321992bbc2abaa0f49ac330bd`. Its current blob is over 1 MiB and the connector did not return the file body, so a complete replacement of the canonical file could not be performed safely in this run. This addendum preserves the QA185 record without truncating the canonical history.
