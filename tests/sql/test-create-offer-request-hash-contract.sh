#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$RUNTIME" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required request-hash contract file is missing: $file"
done

hash_block_count="$(grep -Fc 'v_hash := md5(jsonb_build_object(' "$MIGRATION" || true)"
[[ "$hash_block_count" -eq 1 ]] ||
  fail "CREATE_OFFER migration must contain exactly one effective request-hash block, found $hash_block_count"

HASH_BLOCK="$(sed -n '/v_hash := md5(jsonb_build_object(/,/  )::text);/p' "$MIGRATION")"
[[ -n "$HASH_BLOCK" ]] || fail "could not extract the complete CREATE_OFFER request-hash block"

assert_pair() {
  local key="$1"
  local expression="$2"
  local needle="'$key', $expression"
  local count
  count="$(grep -Fc -- "$needle" <<< "$HASH_BLOCK" || true)"
  [[ "$count" -eq 1 ]] ||
    fail "request hash must include exactly one mapping for $key -> $expression (found $count)"
}

for pair in \
  'input|p_input' \
  'name|p_name' \
  'demandId|p_demand_id' \
  'productMasterId|p_product_master_id' \
  'providerActorId|p_provider_actor_id' \
  'quantity|p_quantity' \
  'price|p_price' \
  'currency|p_currency' \
  'conditions|p_conditions' \
  'market|p_market' \
  'geography|p_geography' \
  "attributes|coalesce(p_attributes, '{}'::jsonb)" \
  'documentationStatus|p_documentation_status' \
  'lifecycle|p_lifecycle' \
  'offerType|p_offer_type' \
  'pricingModel|p_pricing_model'; do
  IFS='|' read -r key expression <<< "$pair"
  assert_pair "$key" "$expression"
done

if grep -Eq 'p_tenant_id|p_idempotency_key' <<< "$HASH_BLOCK"; then
  fail "tenant and idempotency key scope must remain outside the business-payload hash"
fi

for parameter in \
  p_input p_name p_demand_id p_product_master_id p_provider_actor_id \
  p_quantity p_price p_currency p_conditions p_market p_geography \
  p_attributes p_documentation_status p_lifecycle p_offer_type p_pricing_model; do
  grep -Fq -- "$parameter" "$RUNTIME" ||
    fail "existing disposable runtime characterization no longer references $parameter"
done

grep -Fq 'IDEMPOTENCY_KEY_REUSE' "$RUNTIME" ||
  fail "runtime must retain changed-payload idempotency rejection assertions"
grep -Fq 'fixture-same-key-two-tenants' "$RUNTIME" ||
  fail "runtime must retain the same-key cross-tenant scope characterization"
grep -Fq 'count(DISTINCT request_hash)' "$RUNTIME" ||
  fail "runtime must retain the request-hash scope assertion"

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-request-hash-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify job must execute the request-hash field-coverage contract exactly once"

echo "QA382 PASS: the effective CREATE_OFFER request hash maps all 16 business inputs exactly once, keeps tenant/idempotency scope separate, and retains the existing disposable replay assertions."
