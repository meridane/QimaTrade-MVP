#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA398 file is missing: $file"
done

[[ "$(grep -Fc "'attributes', coalesce(p_attributes, '{}'::jsonb)" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the effective request hash must normalize and include p_attributes exactly once"

hash_line="$(grep -nF "'attributes', coalesce(p_attributes, '{}'::jsonb)" "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$hash_line" && -n "$reuse_line" && -n "$insert_line" ]] ||
  fail "attributes hash, mismatch guard or persistence statement is missing"
(( hash_line < reuse_line && reuse_line < insert_line )) ||
  fail "attributes must be hashed and mismatches rejected before new execution persistence"

BLOCK="$(sed -n '/^DO \$qa398_attributes_key_order_replay\$$/,/^\$qa398_attributes_key_order_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA398 attributes key-order replay block"

for required in \
  "v_key text := 'fixture-qa398-attributes-key-order';" \
  "v_attributes jsonb := '{\"alpha\":\"one\",\"meta\":{\"x\":\"1\",\"y\":\"2\"},\"beta\":\"two\"}'::jsonb;" \
  "v_replay_attributes jsonb := '{\"beta\":\"two\",\"meta\":{\"y\":\"2\",\"x\":\"1\"},\"alpha\":\"one\"}'::jsonb;" \
  "IF v_attributes IS DISTINCT FROM v_replay_attributes THEN" \
  "IF v_attributes::text IS DISTINCT FROM v_replay_attributes::text THEN" \
  "p_attributes => v_attributes" \
  "p_attributes => v_replay_attributes" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "v_offer_attributes IS DISTINCT FROM v_attributes" \
  "QA398 PASS: semantically equivalent p_attributes JSONB objects with reordered root and nested keys replay the original result without duplicate persisted rows"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA398 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc 'v_replay_attributes jsonb :=' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA398 replay attributes must be declared exactly once"
[[ "$(grep -Fc 'p_attributes => v_attributes' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA398 original attributes must be passed exactly once"
[[ "$(grep -Fc 'p_attributes => v_replay_attributes' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA398 replay attributes must be passed exactly once"
[[ "$(grep -Fc 'DO $qa398_attributes_key_order_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA398 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa398_attributes_key_order_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA398 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA398 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA398 runtime marker must appear exactly once"

for expression in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD',"; do
  count="$(grep -Fc "$expression" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "QA398 must keep all non-attributes effective parameters identical: $expression (found $count)"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA398 must remain a function-call regression followed by read-only persisted-state assertions"
fi

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-attributes-key-order-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA398 exactly once"

pg16_job="$(awk '
  $0 == "  postgres-integration:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
pg17_job="$(awk '
  $0 == "  postgres17-create-offer-compatibility:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 integration runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 integration runner wiring missing"

echo "QA398 PASS: semantically equivalent p_attributes JSONB objects with reordered root and nested keys replay the original result without duplicate persisted rows on PostgreSQL 16 and 17.6."
