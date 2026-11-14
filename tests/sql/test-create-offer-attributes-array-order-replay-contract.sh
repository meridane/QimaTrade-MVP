#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA399 file is missing: $file"
done

[[ "$(grep -Fc "'attributes', coalesce(p_attributes, '{}'::jsonb)" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the effective request hash must normalize and include p_attributes exactly once"

BLOCK="$(sed -n '/^DO \$qa399_attributes_array_order_replay\$/,/^\$qa399_attributes_array_order_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA399 array-order replay block"

QA91_BLOCK="$(sed -n '/^DO \$qa91_integrity\$/,/^\$qa91_integrity\$;/p' "$RUNTIME")"
grep -Fq 'v_before record;' <<< "$QA91_BLOCK" ||
  fail "QA91 integrity regression must retain its v_before declaration"
grep -Fq 'SELECT * INTO v_before FROM pg_temp.qa91_baseline;' <<< "$QA91_BLOCK" ||
  fail "QA91 integrity regression must retain its baseline read"

for required in \
  "v_key text := 'fixture-qa399-attributes-array-order';" \
  "v_attributes jsonb := '{\"items\":[\"alpha\",\"beta\"],\"meta\":{\"region\":\"kr\"}}'::jsonb;" \
  "v_replay_attributes jsonb := '{\"items\":[\"beta\",\"alpha\"],\"meta\":{\"region\":\"kr\"}}'::jsonb;" \
  "IF v_attributes IS NOT DISTINCT FROM v_replay_attributes THEN" \
  "IF v_attributes::text IS NOT DISTINCT FROM v_replay_attributes::text THEN" \
  "p_attributes => v_attributes" \
  "p_attributes => v_replay_attributes" \
  "IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_replay_result IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "v_offer_attributes IS DISTINCT FROM v_attributes" \
  "QA399 PASS: changing JSONB array element order in p_attributes raises IDEMPOTENCY_KEY_REUSE and preserves the original hash, result, offer, execution and event without duplicate persisted rows"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA399 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc "v_replay_attributes jsonb :=" <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA399 replay attributes must be declared exactly once"
[[ "$(grep -Fc "p_attributes => v_attributes" <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA399 original attributes must be passed exactly once"
[[ "$(grep -Fc "p_attributes => v_replay_attributes" <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA399 replay attributes must be passed exactly once"
[[ "$(grep -Fc 'DO $qa399_attributes_array_order_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA399 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa399_attributes_array_order_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA399 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA399 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA399 runtime marker must appear exactly once"

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA399 must assert exactly one original row in each scoped persistence table: $required"
done
if grep -Fq 'v_before' <<< "$BLOCK"; then
  fail "QA399 must not compare scoped post-call row counts with unrelated global pre-call counts"
fi

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
    fail "QA399 must keep all non-attributes effective parameters identical: $expression (found $count)"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA399 must remain a function-call regression followed by read-only persisted-state assertions"
fi

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-attributes-array-order-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA399 exactly once"

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

echo "QA399 static contract PASS: JSONB array element order remains significant in p_attributes; changing only array order is rejected and the original persisted state is preserved on PostgreSQL 16 and 17.6."
