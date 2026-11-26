# QIMA MKT-1.2 — Independent legacy draft idempotency contract

Date: 2026-11-11 (KST)  
Status: **PROPOSAL ONLY — NOT APPROVED**  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch under review: `fix/create-offer-status-contract`  
Scope: source/test-fixture analysis and contract design. No application, schema, or production changes.

## 1. Executive finding

QA340 characterizes an ambiguous HTTP outcome in the independent supplier-draft route:

1. The browser submits the unchanged form.
2. The route and isolated synthetic PostgREST fixture complete the first INSERT (upstream HTTP 201).
3. Playwright drops only the browser-facing response.
4. The browser displays the generic retry message and retains the form.
5. The supplier retries.
6. The current handler generates a fresh UUID for the second POST; the fixture records a second offer.

This is a deterministic test-fixture observation. It is **not** evidence that a duplicate was created in Supabase Production or that a Production vulnerability is confirmed.

The safe conclusion is narrower: the current independent-draft request contract has no stable operation key, and the handler cannot replay the result of an earlier committed request after an ambiguous response.

## 2. Source facts verified on PR #26 HEAD

### 2.1 Independent draft UI and route

- UI: `app/offers/new/page.tsx`.
- Form target: `POST /api/offers`.
- Browser request: `Accept: application/json`, same-origin credentials, and `new FormData(form)`.
- No hidden idempotency field or `Idempotency-Key` request header is currently added by the form.
- Route adapter: `app/api/offers/route.ts`; it delegates to `createLegacyOfferHandler`.
- Handler: `lib/offers/create-legacy-offer.ts`.
- The handler derives `provider_actor_id` from the authenticated profile, generates `offerId = randomUUID()` for each POST, and inserts directly through `supabase.from("offers").insert(...)`.
- The handler does not read or persist an idempotency key. A successful JSON request receives HTTP 201 with the generated `id`.
- The independent draft path permits `demand_id = NULL`, `product_master_id = NULL`, `price = NULL`, and `currency = NULL`.

### 2.2 Existing CREATE_OFFER action idempotency is not a drop-in fit

The branch migration `supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql` defines `public.execute_create_offer_v1` with an existing tenant-scoped idempotency contract:

- `p_tenant_id` is mandatory.
- `p_idempotency_key` is mandatory.
- A current authenticated user and membership in the supplied tenant are mandatory.
- The provider actor must match the authenticated user's profile actor.
- An active Product Master and an existing demand are mandatory.
- Price and supported currency are mandatory.
- The request hash covers the supplied input and effective offer parameters.
- A transaction advisory lock is acquired for the tenant/key pair.
- A completed matching key replays its stored result; a different request hash is rejected.

The disposable schema fixture `tests/sql/fixtures/create-offer-schema.sql` models `idempotency_keys.tenant_id` as NOT NULL and has a unique constraint on `(tenant_id, key)`. This is fixture evidence for the tested RPC contract, not a substitute for a fresh Production catalog inspection.

The independent draft UI has no tenant selector/tenant field and intentionally permits the nullable demand, Product Master, price, and currency values listed above. Reusing the current RPC unchanged would reject valid independent drafts. Relaxing that RPC would broaden the existing action contract and affect more than the legacy route.

## 3. Required semantics

The following are proposed acceptance requirements, not approved business policy.

1. **Stable operation identity:** one form submission attempt receives one opaque, high-entropy idempotency key. Explicit retry after timeout, connection loss, or lost response reuses that same key.
2. **New intent gets a new key:** after confirmed success, “Create another offer” starts a new operation with a new key. A deliberately separate submission must not be deduplicated merely because its content matches an earlier offer.
3. **Server-owned identity:** authenticate the request and derive the user and provider actor from the session/profile. Never trust a client-supplied actor or tenant as the ownership scope.
4. **Canonical payload binding:** compute a server-side hash after validation and normalization. Include every persisted business field (including nullable demand/Product Master/price/currency, market, geography, conditions, documentation status, lifecycle, offer type, pricing model, and server-derived provider actor). Exclude generated IDs and transport-only fields.
5. **Matching replay:** same scope + same key + same canonical hash returns the original offer ID and a success response without a second INSERT.
6. **Key misuse:** same scope + same key + a different canonical hash returns a stable conflict (proposed HTTP 409) and performs no second INSERT.
7. **Concurrency:** concurrent requests using the same scope/key serialize or rely on an equivalent unique-constraint protocol; only one offer is persisted and all matching callers receive the same offer ID.
8. **Atomic persistence:** the idempotency record and offer creation must commit or roll back together. A failed/rolled-back INSERT must not leave a completed replay result pointing to a nonexistent offer.
9. **Bounded retention:** define how long completed keys remain replayable and how cleanup works. A key must not silently become reusable while a client may still retry it.
10. **No content-based deduplication:** two distinct keys represent two distinct user intents, even if all offer fields happen to be identical.

## 4. Architecture options

### Option A — dedicated independent-draft idempotency operation

Introduce a narrowly scoped database/API operation for independent drafts. A possible record shape is:

- authenticated principal ID;
- server-derived provider actor ID;
- operation name/version;
- idempotency key;
- canonical request hash;
- offer ID/result;
- state and created/completed timestamps.

A unique constraint would cover the approved scope and key. The database operation would authenticate/derive identity, serialize concurrent requests, insert the offer, and persist the replay result atomically. Direct client table writes should not be required.

**Advantages:** preserves the current independent-draft contract (no tenant, demand, Product Master, or price required); isolates the new behavior from the demand-specific action RPC.

**Costs:** new schema/function, ACL/RLS review, retention/cleanup design, and isolated concurrency tests. Requires approval of the key scope.

### Option B — extend the shared action/idempotency model

Generalize the existing action engine and `idempotency_keys` model to represent a tenantless independent-draft action.

**Advantages:** one common action/event/idempotency model.

**Costs:** changes a shared contract currently used by tenant-scoped actions; requires careful treatment of the NOT NULL tenant key, uniqueness, authorization, action definitions, status constraints, and all existing callers. This is a larger change and should not be inferred from the legacy route alone.

### Option C — derive a tenant for the legacy draft

Do not implement this without an explicit product rule. The current independent form does not choose a tenant, and a user may have zero or multiple memberships. Selecting an arbitrary/default membership would silently change ownership semantics.

### Recommendation for review

Option A is the narrowest technical fit **if** the product confirms that independent drafts are a distinct, tenantless workflow. This is a recommendation for discussion only; it is not authorization to create a migration or function.

## 5. Decisions required before implementation

| Decision | Choices requiring confirmation | Why it matters |
|---|---|---|
| Key scope | authenticated user; provider actor; another explicit organization scope | Determines whether two users sharing an actor may replay one another's result |
| Key lifetime | explicit duration and cleanup policy | Defines the window during which a retry must replay rather than create |
| Browser persistence | component lifetime only; session storage; another approved mechanism | Determines whether retries after refresh/tab restoration retain the same key |
| Replay response | same HTTP 201; HTTP 200 on replay; another stable contract | Must remain compatible with the browser's `response.ok` and UUID handling |
| Payload mismatch | proposed HTTP 409 and generic public error | Prevents accidental reuse of one key for changed form contents |
| Cross-tab behavior | separate intent per form instance or shared pending intent | Controls whether two tabs intentionally create separate drafts |
| Storage architecture | dedicated table/function or shared action-engine extension | Determines migration, ACL, RLS, and operational scope |

No value is assumed for these decisions in this document.

## 6. Proposed regression matrix

Run only against disposable PostgreSQL and the isolated browser fixture until the contract is approved.

| Scenario | Expected result after an approved implementation |
|---|---|
| First request, new key | One offer; return its ID |
| Same key and same payload after response loss | Same offer ID; still one offer |
| Same key and changed quantity/name/price/market | Conflict; no second offer |
| Two concurrent requests, same key and payload | One offer and one replayable result |
| Two different keys, identical payload | Two offers (two distinct intents) |
| User A reuses User B's key | Behavior follows the explicitly approved scope; never leak another principal's result |
| No tenant, demand, Product Master, price, or currency | Remains valid for the independent-draft contract |
| INSERT transaction fails before commit | No completed idempotency result; retry follows the approved failure semantics |
| Retry after retention expiry | Explicitly defined behavior; never accidental key reuse |
| “Create another offer” after success | New key and a new operation |

Tests must assert the persisted offer count, returned offer ID, request hash, scope, execution/result state, and absence of cross-principal replay. A synthetic pass is not proof of deployed Production behavior.

## 7. Implementation gate

Do not change the handler, shared RPC, schema, RLS, grants, or Production configuration until the key scope, retention, browser persistence, replay response, and storage architecture are approved.

After approval:
1. implement the smallest isolated contract;
2. add unit/route tests for key validation and hash mismatch;
3. add disposable PostgreSQL tests for replay, rollback, and concurrent same-key requests;
4. add Playwright response-loss retry coverage that expects one persisted offer and the same ID;
5. run the complete CI and CodeQL workflows;
6. obtain review before any Production migration or deployment.

## 8. Safety boundary

- QA340 is a synthetic characterization of the current handler and fixture, not a confirmed Production duplicate or vulnerability.
- No Supabase Production data, schema, migration, RLS policy, grant, secret, or persistent configuration was changed.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
