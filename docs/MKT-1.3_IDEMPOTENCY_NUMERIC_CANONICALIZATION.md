# QIMA MKT-1.3 — Idempotency numeric canonicalization

Date: 2026-11-11 (KST)  
Status: **CHARACTERIZATION / DECISION REQUIRED — NOT APPROVED**  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch under review: `fix/create-offer-status-contract`  
Related proposal: [MKT-1.2 — Independent legacy draft idempotency contract](./MKT-1.2_LEGACY_DRAFT_IDEMPOTENCY_CONTRACT.md)

## 1. Executive finding

The current branch's `execute_create_offer_v1` request hash is computed from the textual serialization of a JSONB object:

```sql
md5(jsonb_build_object(
  'input', p_input,
  'quantity', p_quantity,
  'price', p_price,
  'attributes', coalesce(p_attributes, '{}'::jsonb),
  ...
)::text)
```

PostgreSQL JSONB equality treats numerically equal values such as `1` and `1.0` as equal, but JSONB text serialization preserves their numeric scale. The existing disposable PostgreSQL regression suite explicitly characterizes that distinction for top-level input, typed numeric arguments, and nested attributes.

This is a serialization/canonicalization contract question. The characterization does **not** establish a Production defect, vulnerability, or duplicate-offer incident.

## 2. Existing disposable-test evidence

The following tests are present in `tests/sql/create-offer-runtime.sql` on the PR branch:

| Test | Input variation | Current characterized result |
|---|---|---|
| OFFER-QA-73 | `p_input` JSONB number `1` vs `1.0` | JSONB values compare equal; text and MD5 differ; same-key replay raises `IDEMPOTENCY_KEY_REUSE` |
| OFFER-QA-74 | Typed `p_quantity` `2` vs `2.0` | Effective JSONB values compare equal; serialized text/hash differ; replay is rejected |
| OFFER-QA-74 | Typed `p_price` `12` vs `12.0` | Effective JSONB values compare equal; serialized text/hash differ; replay is rejected |
| OFFER-QA-75 | Nested `p_attributes` number `1` vs `1.0` | JSONB values compare equal; text/hash differ; replay is rejected |

These are deliberate characterization assertions in the disposable PostgreSQL fixture. They document current branch behavior; they do not declare that behavior to be the desired business contract.

Related coverage also verifies JSONB object-key reordering, significant array ordering, SQL NULL/default behavior, empty strings, and independent participation of optional parameters. See [the SQL regression suite](../tests/sql/create-offer-runtime.sql#L4174-L5588) and its later optional-parameter coverage.

## 3. Why this matters to MKT-1.2

MKT-1.2 requires a server-side canonical request hash so that the same operation key can be safely replayed after an ambiguous network response.

"Canonical" must be defined beyond object-key ordering. It must also state whether semantically equal numeric values are the same effective request.

For example, if quantity and price are PostgreSQL `numeric` values, then `2` and `2.0` compare equal as database numerics. If their textual scale is retained in the hash, a retry that changes only formatting can be rejected even though the persisted business value is equal.

For JSONB fields, the same issue can occur recursively inside `p_input` and `p_attributes`.

## 4. Decisions required before changing the hash

No normalization policy is selected here. The product/data contract must decide:

1. **Typed quantity:** whether `2`, `2.0`, and `2.000` are equivalent, and what precision/scale is permitted.
2. **Typed price:** whether formatting-only scale changes are equivalent, including currencies whose commercial precision differs.
3. **JSONB numeric values:** whether nested numbers with different scales are semantically equivalent throughout `p_input` and `p_attributes`.
4. **Text and null semantics:** which distinctions between SQL NULL, JSON null, empty text, and omitted/defaulted values remain meaningful. Existing QA-77/79/80/286 coverage must not be weakened accidentally.
5. **Arrays:** whether array order remains significant. Existing QA-72 coverage treats array order as significant while object-key order is not.
6. **Hash version compatibility:** how a new canonicalization version will coexist with idempotency rows written using the current serialization. Do not silently change the hash and cause an otherwise valid retry to be treated as key reuse.

A hash-algorithm change and a payload-canonicalization change are separate decisions. This note does not recommend changing MD5 to another digest or changing stored hashes without a compatibility plan.

## 5. Proposed acceptance matrix after approval

Run only against disposable PostgreSQL until the contract is approved.

| Case | Expected result to define |
|---|---|
| Same typed quantity, different scale | Replay or conflict according to approved quantity semantics |
| Same typed price, different scale | Replay or conflict according to approved price semantics |
| Same nested JSONB number, different scale | Replay or conflict according to approved JSON-number semantics |
| Reordered object keys | Preserve existing semantic replay behavior |
| Reordered array elements | Preserve existing array-order distinction unless explicitly changed |
| SQL NULL vs empty text | Preserve the approved field-specific distinction |
| SQL NULL vs JSON null vs empty object | Preserve the approved JSON/SQL null contract |
| Same key, genuinely changed business value | Reject with the existing stable key-reuse contract |
| Distinct keys, identical effective values | Represent distinct user operations; do not content-deduplicate |

Tests must assert the returned result, stored request hash/version, execution, offer, event count, and unchanged state after rejected replays.

## 6. Safe implementation gate

Before modifying the current RPC or the proposed independent-draft operation:

1. approve quantity and price precision/scale rules;
2. approve numeric normalization inside JSONB;
3. specify SQL NULL / JSON null / empty-value semantics;
4. specify compatibility for existing idempotency rows;
5. add disposable regression cases for both normalized replay and genuine mismatch;
6. run PostgreSQL 16 and 17.6 integration, full Playwright, TypeScript, build, npm audit, and CodeQL;
7. obtain review before any Production migration or deployment.

Until then, retain the current characterization tests and do not silently normalize request hashes.

## 7. Safety boundary

- This note documents existing synthetic test behavior; it does not report a confirmed Production vulnerability or incident.
- No application code, SQL function, migration, schema, RLS policy, grant, secret, or Production configuration was changed.
- No Supabase Production data was read or modified in this task.
- No Production deployment, PR merge, force update, or branch-protection change was performed.
