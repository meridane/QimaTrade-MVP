#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$RUNTIME" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required tenant-scoped idempotency contract file is missing: $file"
done

SIGNATURE="$(awk '
  /^CREATE OR REPLACE FUNCTION public.execute_create_offer_v1\(/ { inside = 1 }
  inside { print }
  inside && /^\)/ { exit }
' "$MIGRATION")"

actual_signature="$(grep -Eo 'p_[a-z_]+' <<< "$SIGNATURE" | paste -sd' ' -)"
expected_signature="p_tenant_id p_idempotency_key p_input p_name p_demand_id p_product_master_id p_provider_actor_id p_quantity p_price p_currency p_conditions p_market p_geography p_attributes p_documentation_status p_lifecycle p_offer_type p_pricing_model"

[[ "$actual_signature" == "$expected_signature" ]] ||
  fail "CREATE_OFFER tenant/key and business parameter signature/order changed: $actual_signature"

FUNCTION_BODY="$(sed -n '/AS \$function\$/,/^\$function\$;/p' "$MIGRATION")"
[[ -n "$FUNCTION_BODY" ]] || fail "could not extract execute_create_offer_v1 function body"

lock_count="$(grep -Fc 'PERFORM pg_advisory_xact_lock(' <<< "$FUNCTION_BODY" || true)"
hash_count="$(grep -Fc 'hashtextextended(' <<< "$FUNCTION_BODY" || true)"
lookup_count="$(grep -Fc 'SELECT * INTO v_existing' <<< "$FUNCTION_BODY" || true)"
[[ "$lock_count" -eq 1 ]] || fail "function must serialize tenant/key attempts with exactly one advisory transaction lock"
[[ "$hash_count" -eq 1 ]] || fail "function must compute exactly one tenant/key advisory lock hash"
[[ "$lookup_count" -eq 1 ]] || fail "function must perform exactly one existing idempotency-row lookup"

LOCK_BLOCK="$(sed -n '/PERFORM pg_advisory_xact_lock(/,/);/p' <<< "$FUNCTION_BODY")"
grep -Fq "hashtextextended(p_tenant_id::text || ':' || p_idempotency_key, 0)" <<< "$LOCK_BLOCK" ||
  fail "advisory lock must include both tenant ID and idempotency key"

lock_line="$(grep -nF 'PERFORM pg_advisory_xact_lock(' <<< "$FUNCTION_BODY" | cut -d: -f1)"
lookup_line="$(grep -nF 'SELECT * INTO v_existing' <<< "$FUNCTION_BODY" | cut -d: -f1)"
[[ -n "$lock_line" && -n "$lookup_line" ]] || fail "tenant/key lock or lookup line is missing"
(( lock_line < lookup_line )) || fail "tenant/key advisory lock must run before the idempotency-row lookup"

LOOKUP_BLOCK="$(sed -n '/SELECT \* INTO v_existing/,/FOR UPDATE/p' <<< "$FUNCTION_BODY")"
grep -Fq 'FROM public.idempotency_keys' <<< "$LOOKUP_BLOCK" ||
  fail "existing idempotency lookup must remain schema-qualified"
grep -Fq 'WHERE tenant_id = p_tenant_id AND key = p_idempotency_key' <<< "$LOOKUP_BLOCK" ||
  fail "existing idempotency lookup must match both tenant_id and key"
grep -Fq 'FOR UPDATE' <<< "$LOOKUP_BLOCK" ||
  fail "existing tenant/key idempotency row must remain locked FOR UPDATE"

grep -Fq 'IF v_existing.request_hash <> v_hash THEN' <<< "$FUNCTION_BODY" ||
  fail "existing tenant/key row must compare the stored request hash"
grep -Fq "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" <<< "$FUNCTION_BODY" ||
  fail "changed payload under an existing tenant/key must retain IDEMPOTENCY_KEY_REUSE"

IDEMPOTENCY_INSERT="$(sed -n '/INSERT INTO public.idempotency_keys(/,/);/p' <<< "$FUNCTION_BODY")"
grep -Fq 'key, action_id, actor_id, request_hash, execution_id,' <<< "$IDEMPOTENCY_INSERT" ||
  fail "idempotency insert columns must retain key and request_hash"
grep -Fq 'status, result, tenant_id' <<< "$IDEMPOTENCY_INSERT" ||
  fail "idempotency insert must persist tenant_id"
grep -Fq 'p_idempotency_key, v_action_id, v_actor_id, v_hash, v_execution_id,' <<< "$IDEMPOTENCY_INSERT" ||
  fail "idempotency insert values must bind the caller key and computed request hash"
grep -Fq "'IN_PROGRESS', NULL, p_tenant_id" <<< "$IDEMPOTENCY_INSERT" ||
  fail "idempotency insert values must persist the caller tenant"

ACTION_INSERT="$(sed -n '/INSERT INTO public.action_executions(/,/RETURNING id INTO v_execution_id;/p' <<< "$FUNCTION_BODY")"
grep -Fq 'correlation_id, idempotency_key, status, input, tenant_id' <<< "$ACTION_INSERT" ||
  fail "action execution insert must persist idempotency key and tenant"
grep -Fq "v_correlation_id, p_idempotency_key, 'RUNNING', p_input, p_tenant_id" <<< "$ACTION_INSERT" ||
  fail "action execution insert values must bind the caller key and tenant"

IDEMPOTENCY_UPDATE="$(sed -n '/UPDATE public.idempotency_keys/,/;/p' <<< "$FUNCTION_BODY")"
grep -Fq 'WHERE tenant_id = p_tenant_id AND key = p_idempotency_key' <<< "$IDEMPOTENCY_UPDATE" ||
  fail "completion update must remain scoped by both tenant_id and key"

CREATE_OFFER_CALL="$(sed -n '/v_offer_id := public.create_offer_v1(/,/);/p' <<< "$FUNCTION_BODY")"
actual_call="$(grep -Eo 'p_[a-z_]+' <<< "$CREATE_OFFER_CALL" | paste -sd' ' -)"
expected_call="p_name p_demand_id p_product_master_id p_provider_actor_id p_quantity p_price p_currency p_conditions p_market p_geography p_attributes p_documentation_status p_lifecycle p_offer_type p_pricing_model"
[[ "$actual_call" == "$expected_call" ]] ||
  fail "create_offer_v1 arguments must preserve the 15 business-parameter mapping/order: $actual_call"

qima_block_count="$(grep -Fc 'DO $qima$' "$RUNTIME" || true)"
[[ "$qima_block_count" -eq 1 ]] || fail "runtime must retain exactly one tenant-scoped idempotency DO block"
CROSS_TENANT_BLOCK="$(sed -n '/^DO \$qima\$$/,/^\$qima\$;/p' "$RUNTIME")"
[[ -n "$CROSS_TENANT_BLOCK" ]] || fail "could not extract the tenant-scoped runtime characterization"

for required in \
  "'fixture-same-key-two-tenants'" \
  "10000000-0000-4000-8000-000000000001" \
  "10000000-0000-4000-8000-000000000002" \
  "tenant_a_result->>'executionId' = tenant_b_result->>'executionId'" \
  "tenant_a_result->>'objectId' = tenant_b_result->>'objectId'" \
  'count(DISTINCT request_hash)' \
  'tenant_a_retry IS DISTINCT FROM tenant_a_result' \
  'tenant_b_retry IS DISTINCT FROM tenant_b_result' \
  'IDEMPOTENCY_KEY_REUSE' \
  'Tenant B replay was affected by tenant A rejection'; do
  grep -Fq -- "$required" <<< "$CROSS_TENANT_BLOCK" ||
    fail "tenant-scoped runtime characterization is missing: $required"
done

same_key_count="$(grep -Fc "'fixture-same-key-two-tenants'" <<< "$CROSS_TENANT_BLOCK" || true)"
[[ "$same_key_count" -ge 6 ]] ||
  fail "runtime must retain both tenant creations, both replays and the changed-payload retry"

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-tenant-idempotency-scope-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify job must execute the tenant-scoped idempotency contract exactly once"

echo "QA383 PASS: CREATE_OFFER preserves tenant/key advisory locking, row lookup, persistence and update scope; the existing disposable two-tenant replay regression remains intact."
