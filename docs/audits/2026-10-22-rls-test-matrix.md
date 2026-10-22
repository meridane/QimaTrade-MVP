# QIMA — RLS / multi-tenant security test matrix

Date: 2026-10-22  
Branch: `chore/qima-free-autopilot-review`  
Status: test plan only; not executed against Supabase.

## Scope

Validate the Decision Tree's tenant boundary, state-machine integrity, idempotency and append-only history in a **disposable staging project**. Use two unrelated tenants (A and B) and one authenticated user per tenant (Alice in A, Bob in B). Add a separate multi-tenant test user only if that scenario is supported by the test fixture.

Never run this plan against production. Do not use service-role credentials in browser/client tests. Seed only synthetic records.

## Preconditions

- [ ] Staging migration history is recorded and matches the repository migration sequence.
- [ ] Staging schema snapshot confirms the effective grants, policies, function owners, function definitions and execute privileges.
- [ ] Tenant A/B have separate published Decision Tree versions and test sessions.
- [ ] Alice owns session A; Bob owns session B.
- [ ] A valid product master exists for each test classification.
- [ ] Record initial row counts and session revisions before each mutation test.

## Test matrix

| ID | Actor | Attempt | Expected result |
|---|---|---|---|
| AUTH-01 | Anonymous | Call `dt_submit_answer` | Denied; no row or revision change. |
| TEN-01 | Alice | Read session A | Allowed for her session. |
| TEN-02 | Alice | Read session B by guessed UUID | No row returned / denied; no metadata leakage. |
| TEN-03 | Alice | Call answer RPC for session B | Denied with stable public error; no writes. |
| TEN-04 | Alice | Create a request using session B's ID | Rejected; no request created. |
| TEN-05 | User with no membership | Start a Decision Tree session | Denied; no session created. |
| TEN-06 | User with multiple memberships | Start/create offer without explicit tenant selection | Rejected with tenant-selection-required until a verified tenant selector exists. |
| STATE-01 | Alice | Directly update session `current_node_id`, `revision`, `status`, `tenant_id`, or `user_id` | Denied unless a narrowly defined authorized operation explicitly allows the field change. |
| STATE-02 | Alice | Directly insert a session with a forged tenant or user ID | Denied. |
| STATE-03 | Alice | Submit an answer with a node outside the session's tree version | Rejected; no observation, transition or revision change. |
| STATE-04 | Alice | Submit a value with no matching stored rule | Rejected; no observation, transition or revision change. |
| IDEM-01 | Alice | Submit the same valid `client_command_id` twice | Second call returns the original result; exactly one observation/transition and one revision increment. |
| IDEM-02 | Alice | Submit two different commands with the same expected revision concurrently | At most one succeeds; the other gets a conflict; no duplicate revision. |
| HIST-01 | Alice | Direct INSERT/UPDATE/DELETE on `dt_observations` | Denied for authenticated role. |
| HIST-02 | Alice | Direct INSERT/UPDATE/DELETE on `dt_transitions` | Denied for authenticated role. |
| HIST-03 | Alice | Read her recorded history | Allowed according to current read policy. |
| PROD-01 | Alice | Select a product master matching her current classification | Supported RPC succeeds; session becomes completed and product selection is stored. |
| PROD-02 | Alice | Select a product master outside her classification | Rejected; session state unchanged. |
| REQ-01 | Alice | Insert a product request with her own session and valid active product | Allowed if the intended draft-creation flow is retained. |
| REQ-02 | Alice | Insert a request using Bob's session or forged tenant/user IDs | Denied. |
| REQ-03 | Alice | Direct UPDATE/DELETE of a product request | Denied unless a specifically authorized lifecycle operation is designed and tested. |
| RPC-01 | Authenticated caller | Call each `SECURITY DEFINER` function with forged user/session/tenant identifiers | Denied or constrained to caller-owned data; no cross-tenant effects. |

## Evidence to capture

For every test, record:
- migration version and staging project identifier (never secrets);
- authenticated role and test actor;
- request/function and input identifiers (use synthetic UUIDs);
- HTTP status or SQLSTATE/error code;
- before/after row counts and session revision;
- query proving no cross-tenant row or partial write was created.

## Function and grant inventory to verify in staging

Use the catalog to inspect:
- `information_schema.role_table_grants` for `authenticated` and `anon`;
- `pg_policies` for every `public.dt_%` and `public.product_requests` table;
- `pg_proc.prosecdef`, function owner, `proconfig` (especially `search_path`), and execute grants for `dt_submit_answer`, `dt_select_product_master`, `dt_publish_product_request`, `dt_has_tenant_access`, `current_profile_actor_id`, and `get_action_definition_v1`;
- effective RLS and privileges on `dt_sessions`, `dt_observations`, `dt_transitions`, `product_requests`, and all tables read or mutated by privileged functions.

## Acceptance criteria

- All cross-tenant attempts fail without disclosing whether another tenant's resource exists.
- No client can directly bypass the session state machine or mutate the historical observation/transition ledger.
- Valid answer and product-selection flows still work.
- Idempotent retry writes no duplicate history and does not advance the revision twice.
- All tests run under authenticated test users, not the service role.
- CI and staging evidence is attached to the PR before the Security Gate is marked PASS.

## Important limitations

This document is a plan, not evidence of passing tests. It does not connect to Supabase, inspect the live database catalog, or apply migrations. Current browser smoke tests cover login and unauthenticated request validation; they do not prove the multi-tenant assertions above.
