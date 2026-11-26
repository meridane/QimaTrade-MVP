#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$WORKFLOW" "$RUNNER"; do
  [[ -f "$file" ]] || fail "required QA402 file is missing: $file"
done

[[ "$(grep -Fc "'conditions', p_conditions" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the effective request hash must include p_conditions exactly once"

hash_line="$(grep -nF "'conditions', p_conditions" "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$hash_line" && -n "$reuse_line" && -n "$insert_line" ]] ||
  fail "conditions hash mapping, mismatch guard or persistence statement is missing"
(( hash_line < reuse_line && reuse_line < insert_line )) ||
  fail "p_conditions must be hashed and compared before new execution persistence"

BLOCK="$(sed -n '/^DO \$qa402_conditions_mismatch_replay\$$/,/^\$qa402_conditions_mismatch_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA402 changed-conditions replay block"

for required in \
  "v_key text := 'fixture-qa402-conditions-mismatch';" \
  "v_original_conditions text := 'qa402-original-conditions';" \
  "v_replay_conditions text := 'qa402-changed-conditions';" \
  "p_conditions => v_original_conditions" \
  "p_conditions => v_replay_conditions" \
  "IF SQLERRM <> 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "v_replay_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE'" \
  "v_offer_conditions IS DISTINCT FROM v_original_conditions" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_input IS DISTINCT FROM v_input" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA402 PASS: changing only p_conditions with the same tenant/idempotency key raises IDEMPOTENCY_KEY_REUSE and preserves the original hash, result, execution, offer and success event"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA402 runtime block is missing required assertion: $required"
done

for parameter in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'," \
  "p_market => NULL," \
  "p_geography => NULL," \
  "p_attributes => '{}'::jsonb," \
  "p_documentation_status => NULL," \
  "p_lifecycle => NULL," \
  "p_offer_type => NULL," \
  "p_pricing_model => NULL"; do
  count="$(grep -Fc -- "$parameter" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "QA402 must keep all non-conditions effective parameters identical: $parameter (found $count)"
done

[[ "$(grep -Fc 'p_conditions => v_original_conditions,' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA402 must pass the original conditions exactly once"
[[ "$(grep -Fc 'p_conditions => v_replay_conditions,' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA402 must pass the changed conditions exactly once"
[[ "$(grep -Fc 'public.execute_create_offer_v1(' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA402 must contain exactly one initial call and one changed-conditions replay"
[[ "$(grep -Fc 'DO $qa402_conditions_mismatch_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA402 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa402_conditions_mismatch_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA402 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA402 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA402 runtime marker must appear exactly once"

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA402 must assert exactly one original row in each persistence table: $required"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA402 must remain a function-call regression followed by read-only persisted-state assertions"
fi

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-conditions-mismatch-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA402 exactly once"

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

echo "QA402 static contract PASS: changing only p_conditions with the same tenant/idempotency key is rejected before persistence and preserves the original state on PostgreSQL 16 and 17.6."
