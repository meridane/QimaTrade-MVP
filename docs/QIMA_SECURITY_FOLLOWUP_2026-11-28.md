# QIMA SECURITY — follow-up 2026-11-28

## Scope and branch
- Branch: `work/qima-security-error-boundary-20261127-0441`
- Tested code head: `ff1643edc2a4e700f18d0b6fb4d15c7e8cb5688c`
- Parent mission PR: [#27](https://github.com/meridane/QimaTrade-MVP/pull/27), OPEN / DRAFT.
- Source base: PR #26 HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.

## New regression
- `tests/fixtures/mock-supabase-auth-server.mjs`: allow synthetic Auth HTTP 401 and return an `invalid_token` response for that status.
- `tests/e2e/product-request-publish-route-contract.spec.ts`: add Auth HTTP 401 to the fail-closed matrix (401, 429, 500, 502, 503, 504).
- Each case starts from a valid synthetic session and membership fixture, then requires HTTP 401 UNAUTHENTICATED with zero membership reads, zero definition RPC calls and zero publish RPC calls. Fixtures are restored in `finally`.

## Commits
- `ce2047c8d6c7fe0a1731eb0d21f0e30bb0216806` — synthetic invalid-token response.
- `ff1643edc2a4e700f18d0b6fb4d15c7e8cb5688c` — route regression for invalid Auth token.

## Validation
- Earlier snapshot `566c2f4e`: QIMA CI [run 46094838391](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094838391) SUCCESS, 461 Playwright tests, PostgreSQL 16 and 17.6 SUCCESS; CodeQL [run 46094838407](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094838407) SUCCESS.
- Current final-head QIMA CI [run 46098403789](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403789): PENDING, no jobs published at the latest read. No result is claimed for the new 401 case.
- CodeQL [run 46098403749](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403749): IN PROGRESS.
- The intermediate fixture-only run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) is separate from the final test head.
- Vercel status for the final branch snapshot reports the external `build-rate-limit` failure.

## Security interpretation
The 401 case is synthetic contract coverage. It does not establish a live Auth outage, RLS failure, cross-tenant exposure or exploitable Production vulnerability. No Production policy, grant, secret, data or schema was touched.

## Next step
Wait for the final-head Verify and CodeQL workflows to complete; inspect the exact Auth 401 Playwright result before marking this regression validated.


## CodeQL closeout update
- CodeQL [run 46098403749](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403749) for final code head `ff1643ed` completed **SUCCESS**.
- QIMA CI [run 46098403789](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403789) remains PENDING with no jobs published; the intermediate fixture-only run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) is still IN PROGRESS. The Auth 401 matrix has no final Verify result yet.


## Intermediate Verify closeout
- The fixture-only intermediate run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) completed its Verify job SUCCESS: dependency audit, TypeScript, production build, browser tests and the isolated QIMA security fixture all passed.
- This intermediate commit did not yet include the new Auth 401 test loop. Its result must not be used as validation of the final 401 matrix.
- The final-head run [46098403789](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403789) remains PENDING with no jobs; CodeQL [46098403749](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403749) is SUCCESS.


## Intermediate browser-suite detail
- Verify log for job `140834990651` in run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) records **462 Playwright tests passed** and the isolated QIMA security fixture passed.
- The route matrix in that intermediate snapshot still contained Auth 429/500/502/503/504 only. It did not include HTTP 401; that case exists only in final code head `ff1643ed`, whose QIMA CI remains queued.

 
## Auth 403 follow-up — 2026-11-28

- Extended the disposable Auth fixture to return a distinct synthetic 403 access_denied response.
- Added HTTP 403 to the pre-membership Auth failure matrix: 401, 403, 429, 500, 502, 503 and 504.
- Every status must return 401 UNAUTHENTICATED before any membership read, action-definition RPC or publish RPC.
- Code commits: [3c385c03](https://github.com/meridane/QimaTrade-MVP/commit/3c385c0310a9b0c50146e3ad1fa6d98a26766eec) (synthetic Auth 403 fixture) and [9bae97ec](https://github.com/meridane/QimaTrade-MVP/commit/9bae97ec70be9e6313c73718dd5ebab8aed6ea5a) (route regression).
- The previous final code head ff1643ed is now fully validated by QIMA CI #46098403789: 463 Playwright passed, including Auth 401/429/500/502/503/504; Verify succeeded; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 succeeded. CodeQL #46098403749 succeeded.
- New head 9bae97ec has QIMA CI #46106187513 IN PROGRESS and CodeQL #46106187493 IN PROGRESS at this checkpoint. No passing result is attributed to the new 403 case yet.
- The new 403 case is synthetic. It does not prove a live Auth outage, RLS defect, cross-tenant leak or exploitable Production vulnerability. No Production data, schema, policy, grant or secret was changed.

 
## Auth 403 Verify and repository-source authorization review — 2026-11-28

- New code head 9bae97ec: QIMA CI [#46106187513](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106187513), Verify job 140859359087 **SUCCESS**, **464 Playwright passed**. Auth HTTP 401, 403, 429, 500, 502, 503 and 504 cases all passed; the new 403 case explicitly passed before membership lookup.
- CodeQL [#46106187493](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106187493) **SUCCESS**.
- PostgreSQL 16 and 17.6 jobs are still IN PROGRESS at the full CREATE_OFFER runner write-privilege characterization step. The overall QIMA CI is not yet closed.
- Repository-source review: the earlier migration 20260829110000_product_request_to_demand_bridge_v1.sql defines dt_publish_product_request as SECURITY DEFINER and selects a request by id/user, without checking membership in that request's tenant. Because the function is SECURITY DEFINER, the product_requests RLS policy alone does not enforce the same tenant boundary inside this RPC.
- The branch-only migration 20261127100000_harden_product_request_publish_tenant_membership.sql adds an exact request-tenant membership predicate, then takes FOR KEY SHARE on that membership row before publishing; it also revokes PUBLIC and anon EXECUTE and grants authenticated EXECUTE.
- The disposable two-tenant fixture proves the branch migration rejects a user who owns a request in Tenant A but is currently a member only of Tenant B, performs no demand write, and permits the same request after Tenant A membership is restored. The isolated security fixture passed in Verify.
- Classification: **confirmed source-level authorization gap in the earlier repository function; branch-only mitigation covered by a synthetic PostgreSQL fixture.** This is not proof that the live Production function currently has that exact definition or that Production was exploitable. The live catalog remains unverified; prior read-only connection attempts failed before query execution with 28P01. No Production migration, data, policy, grant or secret was changed.

 
## External preview and live-environment boundary

- Vercel Preview for code head 9bae97ec reports SUCCESS.
- Read-only Supabase project metadata confirms QIMA project yyulzlnrfcbaxovzjbnh remains INACTIVE in ap-southeast-1, PostgreSQL 17.11.0.003. No SQL query was attempted against the inactive project.
- The branch-only tenant-membership migration and its disposable fixture are not applied to Production. Live effective ACLs and current deployed function definition remain unverified.


## Final PostgreSQL and CI closeout — 2026-11-28 14:10 KST

- Final code head: `9bae97ec70be9e6313c73718dd5ebab8aed6ea5a`.
- QIMA CI [#2229](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106187513) is **SUCCESS**. Verify job `140859359087` completed **SUCCESS** with **464 Playwright tests passed**; TypeScript, dependency audit, Next.js production build, Chromium and the isolated QIMA security fixture all passed.
- The complete Auth HTTP matrix (401, 403, 429, 500, 502, 503, 504) passed. The HTTP 403 case returned `UNAUTHENTICATED` before membership reads, action-definition RPC or publish RPC.
- PostgreSQL 16 job `140859358991` completed **SUCCESS** (all 48 job steps); PostgreSQL 17.6 job `140859359013` completed **SUCCESS** (all 33 job steps). Both include the runner privilege characterization, actor-scoped RLS checks, SECURITY DEFINER wrapper checks and explicit RPC EXECUTE ACL checks. No unexpected failed step remains.
- CodeQL [#2153](https://github.com/meridane/QimaTrade-MVP/actions/runs/46106187493) is **SUCCESS**. Vercel Preview for code head `9bae97ec` was **SUCCESS**.
- The prepared-transaction setup/cleanup failure harness jobs and the intentionally skipped harness retain their expected outcomes; the separate assertions that these outcomes remain blocking all completed **SUCCESS**. The overall QIMA CI run is **SUCCESS**.
- The later documentation-only branch HEAD `263b7fe5` currently has combined Vercel status **FAILURE** with provider target `build-rate-limit`. This is an external preview quota failure, not a GitHub Verify, PostgreSQL or CodeQL failure. The code head above remains the tested snapshot.
- The source-level authorization gap and branch-only tenant-membership mitigation described above remain repository-source findings. Disposable PostgreSQL tests do not establish the live Production catalog or exploitability. QIMA remains inactive; no Production query or migration was performed.
- No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made in this closeout. Documentation only; `[skip ci]` is used because the tested code head is unchanged.


## Membership-revocation concurrency regression — 2026-11-28 14:14 KST

- Added `tests/sql/test-product-request-publish-membership-lock.sh`. It runs only against the disposable `qima-security-db` Compose service created by `scripts/test-qima-security-fixture.sh`.
- The test starts a synthetic authenticated publish RPC in an explicit transaction, waits until the RPC has returned and the session is holding the transaction open, then attempts a privileged DELETE of the exact `dt_memberships(tenant_id, user_id)` row from a second PostgreSQL session with a 750 ms `lock_timeout`.
- Expected result: the concurrent DELETE is blocked by the RPC's `FOR KEY SHARE` and fails specifically with PostgreSQL's lock-timeout message; after the publish transaction commits, the membership row remains and the existing demand count remains exactly one.
- Added commits: [a745f832](https://github.com/meridane/QimaTrade-MVP/commit/a745f832145c8f414faade407692951c7a6146a5) (new concurrency test), [ecef31c7](https://github.com/meridane/QimaTrade-MVP/commit/ecef31c793e4419712d9a5338ea68b462a9cdb20) (preserve holder exit status), and [940304f7](https://github.com/meridane/QimaTrade-MVP/commit/940304f7282f2d95080ebd86933b5c249f2cc5a4) (wire test into disposable fixture driver).
- The test uses only synthetic UUIDs and a local disposable PostgreSQL container; it does not connect to Supabase Cloud.
- New QIMA CI [#2235](https://github.com/meridane/QimaTrade-MVP/actions/runs/46111093869) for final code head `940304f7` is **PENDING with no jobs published** at this checkpoint. CodeQL [#2159](https://github.com/meridane/QimaTrade-MVP/actions/runs/46111093800) is **IN PROGRESS**. No passing result is claimed for the new concurrency test yet.
- The immediately preceding SECURITY code head `9bae97ec` remains fully validated by QIMA CI #2229 (464 Playwright tests, PostgreSQL 16/17.6 SUCCESS) and CodeQL #2153 SUCCESS. Those results do not validate the new lock-concurrency script.
- The latest branch PR #27 remains OPEN / DRAFT / mergeable. The new test and driver touch only SECURITY-owned files; the other three mission file sets remain separate.
- No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made. The live catalog remains unverified while QIMA Supabase is inactive.

## Membership-lock concurrency closeout and post-revocation denial — 2026-11-28

- The disposable SECURITY fixture was extended by commits [a745f832](https://github.com/meridane/QimaTrade-MVP/commit/a745f832145c8f414faade407692951c7a6146a5), [ecef31c7](https://github.com/meridane/QimaTrade-MVP/commit/ecef31c793e4419712d9a5338ea68b462a9cdb20), and [940304f7](https://github.com/meridane/QimaTrade-MVP/commit/940304f7282f2d95080ebd86933b5c249f2cc5a4) to prove a concurrent membership DELETE waits behind the publish RPC's `FOR KEY SHARE`.
- QIMA CI [#2235](https://github.com/meridane/QimaTrade-MVP/actions/runs/46111093869) is now **SUCCESS**. Verify job `140876369002` passed **464 Playwright tests** and the disposable fixture explicitly reported that the concurrent DELETE was blocked until the publish transaction released its lock. PostgreSQL 16 job `140876369204` and PostgreSQL 17.6 job `140876369201` both completed **SUCCESS**; CodeQL [#2159](https://github.com/meridane/QimaTrade-MVP/actions/runs/46111093800) is **SUCCESS**. The Vercel status for that code snapshot was limited by the provider's `build-rate-limit` quota.
- A further assertion was added in commit [bfa399c9](https://github.com/meridane/QimaTrade-MVP/commit/bfa399c95cf8b12bd22e320a256b8d90b91800e3): after the publish transaction commits, the same membership DELETE must succeed; a subsequent authenticated publish attempt must be rejected with `PRODUCT_REQUEST_NOT_FOUND`; the demand count must remain one and the already-published request must remain unchanged.
- For code head `bfa399c9`, QIMA CI [#2236](https://github.com/meridane/QimaTrade-MVP/actions/runs/46112894591) Verify job `140880159143` completed **SUCCESS** with **464 Playwright tests passed (38.1s)**. The isolated SECURITY fixture explicitly passed both the blocked-delete assertion and the post-revocation denial/no-extra-write assertion. CodeQL [#2160](https://github.com/meridane/QimaTrade-MVP/actions/runs/46112894571) completed **SUCCESS**; Vercel Preview is **SUCCESS**.
- At this documentation checkpoint, PostgreSQL 16 and PostgreSQL 17.6 for QIMA CI #2236 remain **IN PROGRESS**. The overall run is not marked complete until both jobs finish.
- These concurrency checks use synthetic UUIDs and a disposable local Compose PostgreSQL service only. They do not verify the live Supabase catalog, Production ACLs, or current deployed RPC definition, and they do not establish a Production vulnerability.
- No Supabase Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push, or protection-rule change was made.


## SECURITY DEFINER search-path guard — 2026-11-28

- The previous membership-lock snapshot is now fully validated by QIMA CI [#2240](https://github.com/meridane/QimaTrade-MVP/actions/runs/46113112144): Verify **464 Playwright passed (38.2s)**, PostgreSQL 16 and PostgreSQL 17.6 **SUCCESS**, and CodeQL [#2164](https://github.com/meridane/QimaTrade-MVP/actions/runs/46113112137) **SUCCESS**. The run includes the concurrent membership-delete block and post-commit revocation checks from code head `bfa399c9`.
- Added static assertions to `tests/sql/test-product-request-publish-membership-contract.sh`: the publish function must remain `SECURITY DEFINER`, pin `search_path = public`, and call the schema-qualified `auth.uid()` helper. This guards the security context of the RPC without changing its SQL definition, grants, or policies.
- The new guard has not yet been run in GitHub Actions at this checkpoint. It is a source/fixture regression assertion, not evidence about the live Supabase catalog or Production exploitability.
- No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push, or protection-rule change was made.



## Static guard correction — 2026-11-28

- The first generated search-path guard snapshot in commit [9787a91d](https://github.com/meridane/QimaTrade-MVP/commit/9787a91d7167fd476c5a436408282aee33c29b4c) contained a malformed shell insertion. It is superseded by this commit before treating the guard as validated.
- Replaced the affected test script with a complete, single-pass assertion set preserving the original tenant, lock and ACL checks and adding only the `SECURITY DEFINER`, pinned `search_path = public`, and qualified `auth.uid()` invariants.
- QIMA CI [#2246](https://github.com/meridane/QimaTrade-MVP/actions/runs/46117390159) belongs to the superseded snapshot; its result must not be attributed to this corrected file. A new run will validate the corrected HEAD.


## Search-path guard validation checkpoint — 2026-11-28

- The superseded QIMA CI [#2246](https://github.com/meridane/QimaTrade-MVP/actions/runs/46117390159) Verify job 140894152546 completed **FAILURE** after **464 Playwright tests passed (36.5s)**. The failure came from the malformed generated shell assertion in commit 9787a91d; the exact shell diagnostic was `tests/sql/test-product-request-publish-membership-contract.sh: 25: /for: not found`. The PostgreSQL 16/17.6 jobs from that superseded run remain in progress and do not validate the corrected script.
- The shell file was replaced in commit [feb6f5c1](https://github.com/meridane/QimaTrade-MVP/commit/feb6f5c157b1cfe26c4f03538ce4685eaa2c434c). A fresh QIMA CI [#2250](https://github.com/meridane/QimaTrade-MVP/actions/runs/46117582536) is **PENDING with no jobs published** at this checkpoint. No Verify result is claimed for the corrected script yet.
- CodeQL [#2174](https://github.com/meridane/QimaTrade-MVP/actions/runs/46117582499) for corrected code head feb6f5c1 completed **SUCCESS**. Vercel reports the external build-rate-limit quota failure.
- No Production catalog, data, schema, migration, secret, grant, RLS policy, persistent configuration, deployment, merge, force-push, or protection-rule change was made.


## Corrected SECURITY DEFINER guard — final CI closeout — 2026-11-28

- Corrected code head: [feb6f5c1](https://github.com/meridane/QimaTrade-MVP/commit/feb6f5c157b1cfe26c4f03538ce4685eaa2c434c); documentation head before this closeout: `f921ae03`.
- QIMA CI [#2250](https://github.com/meridane/QimaTrade-MVP/actions/runs/46117582536) completed **SUCCESS**. Verify job `140895916416` completed **SUCCESS** with **464 Playwright tests passed (37.2s)**; dependency audit, TypeScript, Next.js production build, Chromium and the isolated QIMA security fixture all passed.
- The corrected static contract script explicitly passed: the publish RPC remains `SECURITY DEFINER`, pins `search_path = public`, uses schema-qualified `auth.uid()`, checks membership for the exact request tenant/user, and preserves the intended EXECUTE ACL assertions.
- The fixture also explicitly passed both concurrency phases: a membership DELETE is blocked while the publish transaction holds `FOR KEY SHARE`; after commit, revocation succeeds and a subsequent publish is denied without another demand write.
- PostgreSQL 16 job `140895916363` completed **SUCCESS** (48/48 steps). PostgreSQL 17.6 job `140895916105` completed **SUCCESS** (33/33 steps). CodeQL [#2174](https://github.com/meridane/QimaTrade-MVP/actions/runs/46117582499) completed **SUCCESS**.
- Prepared-transaction setup/cleanup jobs retain their expected injected FAILURE outcomes and the intentionally skipped harness remains SKIPPED; their independent blocking/assertion jobs completed SUCCESS. No unexpected failing job remains.
- The combined Vercel status for documentation head `f921ae03` is **FAILURE** solely with the provider target `build-rate-limit`. This is an external preview quota failure, not a Verify, PostgreSQL or CodeQL failure. No deployment retry or quota bypass was attempted.
- The historical source-level membership gap and branch-only mitigation remain as previously classified. Disposable tests do not prove the deployed Production catalog or exploitability. QIMA Supabase remains inactive and live ACL/function definitions remain unverified.
- No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made. This commit is documentation-only and uses `[skip ci]`; the tested code head is unchanged.


## Authenticated-subject argument binding regression — pending validation — 2026-11-28

- Source review found that the existing static guard required the presence of `auth.uid()` and the membership predicate using `p_user_id`, but did not independently require the RPC to bind its caller-supplied user argument to the authenticated JWT subject.
- Added a static assertion for the explicit `auth.uid() <> p_user_id` rejection predicate in `tests/sql/test-product-request-publish-membership-contract.sh`.
- Added a disposable SQL fixture case that authenticates synthetic user A, calls the publish RPC with synthetic user B as `p_user_id`, requires `UNAUTHENTICATED`, and verifies that no demand is inserted and the request remains `draft`.
- Corrected code commit: [21178dab](https://github.com/meridane/QimaTrade-MVP/commit/21178dabaa0a5f7a1292a8a46307da8de3ea47eb). It includes the fixture test and corrected static guard.
- The immediately preceding code commit [0da391f2](https://github.com/meridane/QimaTrade-MVP/commit/0da391f2115b557bf34114de142f596475a86de9) was superseded after source inspection caught an over-escaped grep pattern before treating its checks as valid. QIMA CI run [46122546590](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122546590) and CodeQL run [46122546586](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122546586) were associated with that superseded SHA and do **not** validate corrected head 21178dab.
- No GitHub Actions run was visible for corrected head 21178dab at this checkpoint. No Verify, PostgreSQL or CodeQL result is claimed for the new mismatch test yet.
- This is synthetic fixture coverage of the existing migration predicate, not evidence of a live Production mismatch or vulnerability. No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made.


## Corrected-head workflow scheduling — 2026-11-28

- Corrected code head [21178dab](https://github.com/meridane/QimaTrade-MVP/commit/21178dabaa0a5f7a1292a8a46307da8de3ea47eb) now has QIMA CI [#2252](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122567881) **PENDING** with no jobs published, and CodeQL [#2176](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122567877) **IN PROGRESS**.
- QIMA CI [#2251](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122546590) remains **IN PROGRESS** on superseded code head `0da391f2`; its jobs are not evidence for corrected head 21178dab.
- No Verify, PostgreSQL, or CodeQL conclusion is attributed to the new authenticated-subject mismatch case until the corrected-head workflows complete.
- This entry is documentation-only (`[skip ci]`); it does not change the tested code head.


## Authenticated-subject binding — final CI closeout — 2026-11-28

- Corrected code head: [21178dab](https://github.com/meridane/QimaTrade-MVP/commit/21178dabaa0a5f7a1292a8a46307da8de3ea47eb). The subsequent documentation-only branch head before this closeout was `b9b73d50`.
- QIMA CI [#2252](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122567881) completed **SUCCESS** on code head `21178dab`. Verify job `140911724283` completed **SUCCESS** with **464 Playwright tests passed (39.1s)**; dependency audit, TypeScript, Next.js production build, browser smoke tests, and the isolated QIMA security-contract fixture all passed.
- The successful fixture step invokes `supabase/fixtures/qima_product_request_publish_rpc_tests.sql` after applying the disposable migration. That fixture authenticates synthetic user A, calls the RPC with user B as `p_user_id`, requires `UNAUTHENTICATED`, and verifies no demand was inserted and the request remains `draft`. The fixture is disposable and the shell runner tears down its Compose project and named volume; this does not inspect or mutate Supabase Production.
- PostgreSQL 16 integration job `140911724253` completed **SUCCESS** (all 48 steps); PostgreSQL 17.6 compatibility job `140911724219` completed **SUCCESS** (all 33 steps). The logs also confirm the prior tenant-membership and concurrent-revocation checks.
- CodeQL [#2176](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122567877) completed **SUCCESS** on corrected code head `21178dab`.
- QIMA CI [#2251](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122546590) remains a **FAILURE on superseded head `0da391f2`** caused by the over-escaped grep assertion; it is not evidence against corrected head `21178dab`. CodeQL #2175 on that superseded head was successful but is not used as validation for the corrected head.
- The new authenticated-subject test is synthetic characterization of the existing migration predicate. It does not establish a live Production mismatch or vulnerability. The live function definition, effective ACLs and RLS policies remain unverified because the QIMA Supabase project is inactive.
- This closeout is documentation-only and uses `[skip ci]`; the tested code head is unchanged. No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made.


## Request-owner boundary regression — corrected fixture pending CI — 2026-11-28

- The previous authenticated-subject binding code head [21178dab](https://github.com/meridane/QimaTrade-MVP/commit/21178dabaa0a5f7a1292a8a46307da8de3ea47eb) is fully validated by QIMA CI [#2252](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122567881): **SUCCESS**, 464 Playwright tests passed, Verify and the isolated security fixture passed, PostgreSQL 16 **48/48** and PostgreSQL 17.6 **33/33** steps succeeded. CodeQL [#2176](https://github.com/meridane/QimaTrade-MVP/actions/runs/46122567877) is **SUCCESS**.
- A follow-up source review found that the SQL fixture covered a mismatched caller-supplied user ID and a missing exact-tenant membership, but did not independently characterize the case where a different user is a member of the correct tenant yet does not own the request.
- Added a disposable fixture case: synthetic user B is granted membership in the request's tenant, authenticates as B, and attempts to publish a request owned by user A. The expected result is PRODUCT_REQUEST_NOT_FOUND, zero inserted demands, and the request remaining draft. The test removes user B's synthetic membership before restoring the request owner's membership and running the positive publish case.
- Added a static assertion that the migration retains pr.user_id = p_user_id, alongside the existing tenant membership and authenticated-subject guards.
- Code changes are [af687da2](https://github.com/meridane/QimaTrade-MVP/commit/af687da242f2d223cd0756d78e20cf5a4a84f68c) (fixture), [eb118022](https://github.com/meridane/QimaTrade-MVP/commit/eb1180223e2700db8c2eaec911c73a186b809d1a) (static guard), and [b3acf40a](https://github.com/meridane/QimaTrade-MVP/commit/b3acf40abf36976a91ef758aadf540f26b641491) (repair fixture dollar-quote delimiters to tagged $q$ blocks after reviewing the generated diff).
- Runs attached to superseded intermediate snapshots af687da2 and eb118022 are not evidence for the corrected final code head. The final corrected head [b3acf40a](https://github.com/meridane/QimaTrade-MVP/commit/b3acf40abf36976a91ef758aadf540f26b641491) has QIMA CI [#2255](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126899372) **PENDING** and CodeQL [#2179](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126899402) **IN PROGRESS** at this checkpoint. No Verify or PostgreSQL result is claimed for the new ownership case.
- The owner-boundary scenario is synthetic and tests the migration in an isolated disposable PostgreSQL fixture. It does not establish a live Production ownership bypass or vulnerability. No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made.
- This is a documentation-only checkpoint ([skip ci]); the corrected code head remains b3acf40a.


## Request-owner regression — CodeQL update — 2026-11-28

- CodeQL [#2179](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126899402) for corrected code head b3acf40a completed **SUCCESS**.
- QIMA CI [#2255](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126899372) remains **PENDING with no jobs published**. The older QIMA CI [#2253](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126870527) for superseded intermediate fixture head af687da2 is still running its isolated fixture step; its result must not be attributed to the corrected head. No Verify or PostgreSQL result is claimed for b3acf40a.
- Vercel status for code head b3acf40a and documentation head is the external build-rate-limit failure; no Preview retry or quota bypass was attempted.
- Documentation-only checkpoint; no code or tested head changed.


## Request-owner boundary regression — final CI closeout — 2026-11-28

- Tested code head: [b3acf40a](https://github.com/meridane/QimaTrade-MVP/commit/b3acf40abf36976a91ef758aadf540f26b641491); documentation head before this closeout: `2bbf1be4`.
- QIMA CI [#2255](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126899372) completed **SUCCESS**. Verify job `140925153503` completed **SUCCESS** with **464 Playwright tests passed (38.0 s)**; TypeScript, dependency audit, Next.js production build, Chromium and the isolated QIMA security fixture all passed.
- The fixture runner executes `supabase/fixtures/qima_product_request_publish_rpc_tests.sql` after applying the branch-local migration. Its new ownership case gives synthetic user B membership in the request's exact tenant while the request remains owned by user A; the RPC must return `PRODUCT_REQUEST_NOT_FOUND`, leave the demand count at zero and preserve the request's `draft` status. The fixture then removes B's synthetic membership, restores the owner's membership and verifies the positive publication path.
- PostgreSQL 16 job `140925153478` and PostgreSQL 17.6 job `140925153447` both completed **SUCCESS**. The PostgreSQL 17.6 log includes the wrapper-owner/membership regression step; the PostgreSQL 16 log includes the corresponding integration, ACL and wrapper-owner checks. CodeQL [#2179](https://github.com/meridane/QimaTrade-MVP/actions/runs/46126899402) completed **SUCCESS**.
- The prepared-transaction setup/cleanup failure-injection jobs retain their expected FAILURE conclusions; independent assertion jobs succeeded. The intentionally skipped cleanup harness is separately asserted. No unexpected failing job remains in this run.
- Vercel for the current documentation head reports the provider's `api-deployments-free-per-day` / `build-rate-limit` quota failure. This is external to GitHub Actions and does not alter the Verify/CodeQL result. No quota bypass or redeployment was attempted.
- This owner-boundary test is synthetic and runs only in the disposable PostgreSQL fixture. It confirms the branch migration's behavior under the tested fixture, not a live Production authorization bypass or vulnerability. No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, Production deployment, merge, force-push or protection-rule change was made.
- This is a documentation-only `[skip ci]` closeout; tested code head remains `b3acf40a`.


## Null authenticated-subject regression — validation pending — 2026-11-28

- Added a distinct synthetic case to `supabase/fixtures/qima_product_request_publish_rpc_tests.sql`: the disposable PostgreSQL bootstrap's `auth.uid()` shim returns NULL when `request.jwt.claim.sub` is set to the empty string. The publish RPC is called with the existing synthetic request and owner UUID, and must raise `UNAUTHENTICATED`; assertions require zero new demands and the original request to remain `draft`.
- Strengthened `tests/sql/test-product-request-publish-membership-contract.sh` to require an explicit `auth.uid() is null` guard in the SECURITY DEFINER function, in addition to the existing subject-equality, tenant-membership, request-owner, pinned-search-path and EXECUTE-ACL checks.
- Commits: [`f77d699b`](https://github.com/meridane/QimaTrade-MVP/commit/f77d699b7f68c080c4720de28914dce6b3bba3a9) adds the SQL regression; [`4a866e3b`](https://github.com/meridane/QimaTrade-MVP/commit/4a866e3bcca3d2d5a2b8617c013afa95898b5100) adds the static guard; [`e30db97c`](https://github.com/meridane/QimaTrade-MVP/commit/e30db97cc1c5dc15a9eec98fdd4a911cd8afe099) corrects shell escaping in that guard. The intermediate shell-regex form is superseded; the current file was re-read and contains a single-backslash POSIX grep expression.
- QIMA CI [#2258](https://github.com/meridane/QimaTrade-MVP/actions/runs/46137107814) for code head `e30db97c` was later **CANCELLED** after a newer PR-head run was created; it produced no validation result. CodeQL [#2182](https://github.com/meridane/QimaTrade-MVP/actions/runs/46137107786) for the same code head completed **SUCCESS**.
- The test is synthetic and uses only the disposable `qima-security-db` fixture. It does not establish live Production behavior or a Production vulnerability. No Production data/schema, Supabase migration, secret, grant, RLS policy, persistent configuration, Production deployment, PR merge, force-push or protection-rule change was made.


## Null-auth regression — latest workflow status — 2026-11-28

- Current PR #27 documentation head is [`6978a88e`](https://github.com/meridane/QimaTrade-MVP/commit/6978a88edec061be798350d6f6af16eb11b7cc7a); tested code remains `e30db97c`.
- QIMA CI [#2259](https://github.com/meridane/QimaTrade-MVP/actions/runs/46137131974) is still **PENDING with no jobs published**. CodeQL [#2183](https://github.com/meridane/QimaTrade-MVP/actions/runs/46137132017) completed **SUCCESS** for the documentation head.
- The null-auth SQL regression has therefore not yet received Verify/PostgreSQL validation. The previous owner-boundary snapshot remains fully validated by QIMA CI #2255; that result does not cover the new null-auth case.


## Null-auth regression — final CI closeout — 2026-11-28

- Tested code head: `e30db97cc1c5dc15a9eec98fdd4a911cd8afe099`; the PR branch's later documentation snapshots `6978a88e` and `97fe617c` do not change the tested code.
- QIMA CI [#2259](https://github.com/meridane/QimaTrade-MVP/actions/runs/46137131974) completed **SUCCESS** on snapshot `6978a88edec061be798350d6f6af16eb11b7cc7a`. Verify job `140956425318` completed **SUCCESS** with **464 Playwright tests passed (36.8 s)**; dependency audit, TypeScript, Next.js production build, Chromium and the isolated security fixture all passed.
- The fixture log confirms the publish-RPC ACL/tenant-membership assertions and the concurrent membership-delete/revocation assertions completed successfully. The null-subject test is part of the disposable fixture tree at the tested code head; it is not a live Supabase test.
- PostgreSQL 16 job `140956425499` and PostgreSQL 17.6 job `140956425604` both completed **SUCCESS**. CodeQL [#2183](https://github.com/meridane/QimaTrade-MVP/actions/runs/46137132017) completed **SUCCESS**.
- The earlier #2258 run was cancelled after a newer snapshot superseded it; no test result is attributed to that cancelled run.
- This closes the null-auth regression for the tested code snapshot. It does not establish a Production authorization failure or vulnerability. No Production data/schema, migration, secret, grant, RLS policy, persistent configuration, deployment, merge, force-push or protection-rule change was made.

## Product-request direct RLS regression — added, validation pending — 2026-11-28

- New code commit: [`ac877284`](https://github.com/meridane/QimaTrade-MVP/commit/ac877284d697abaf00efa0e6d02b8f4c9762f9f8).
- The disposable fixture now mirrors the source `dt_memberships` self-read RLS policy and `product_requests_select_own_tenant` policy, with fixture-only SELECT grants for `authenticated`. It deliberately gives neither `anon` SELECT nor `authenticated` direct INSERT on `product_requests`.
- Runtime assertions cover: NULL Auth sees no membership/request rows; user A with membership only in Tenant B cannot read a Tenant A request; a non-owner member B of Tenant A can read the tenant-scoped request but the publish RPC still rejects B because B is not its owner; after restoring A's Tenant A membership, A can read and publish.
- The static shell contract now checks the source migrations for enabled RLS, the `dt_memberships` self-read policy, the exact-tenant `product_requests` SELECT policy, and the authenticated SELECT grant. This guards against the disposable fixture silently drifting from those source declarations.
- Only disposable fixture SQL and its test/static contract were changed. No production migration, table grant, RLS policy, or Supabase project was changed.
- QIMA CI / PostgreSQL validation for `ac877284` is **pending**; no pass is claimed for the new direct-RLS assertions until the workflow completes.
