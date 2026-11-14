#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
FIXTURE="$ROOT/tests/sql/fixtures/create-offer-schema.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$FIXTURE" "$WORKFLOW" "$RUNNER"; do
  [[ -f "$file" ]] || fail "required QA407 file is missing: $file"
done

[[ "$(grep -Fc "'offerType', p_offer_type" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the effective request hash must include p_offer_type exactly once"
grep -Fq 'offer_type text' "$FIXTURE" ||
  fail "disposable offers fixture must expose offer_type text"
grep -Fq 'p_attributes, p_documentation_status, p_lifecycle, p_offer_type, p_pricing_model' "$MIGRATION" ||
  fail "p_offer_type must be forwarded to the low-level create_offer_v1 call"

hash_line="$(grep -nF "'offerType', p_offer_type" "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$hash_line" && -n "$reuse_line" && -n "$insert_line" ]] ||
  fail "offer-type hash mapping, mismatch guard or persistence statement is missing"
(( hash_line < reuse_line && reuse_line < insert_line )) ||
  fail "p_offer_type must be hashed and compared before new execution persistence"

BLOCK="$(sed -n '/^DO \$qa407_offer_type_mismatch_replay\$$/,/^\$qa407_offer_type_mismatch_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA407 changed-offer-type replay block"

for required in \
  "v_key text := 'fixture-qa407-offer-type-mismatch';" \
  "v_original_offer_type text := 'fixture-offer-type-original';" \
  "v_replay_offer_type text := 'fixture-offer-type-replay';" \
  "p_offer_type => v_original_offer_type" \
  "p_offer_type => v_replay_offer_type" \
  "p_lifecycle => NULL," \
  "p_market => 'fixture-market-stable'," \
  "IF SQLERRM <> 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "v_replay_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE'" \
  "v_offer_type IS DISTINCT FROM v_original_offer_type" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_input IS DISTINCT FROM v_input" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA407 PASS: changing only p_offer_type with the same tenant/idempotency key raises IDEMPOTENCY_KEY_REUSE and preserves the original hash, result, execution, offer and success event"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA407 runtime block is missing required assertion: $required"
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
  "p_lifecycle => NULL," \
  "p_market => 'fixture-market-stable'," \
  "p_geography => NULL," \
  "p_attributes => '{}'::jsonb," \
  "p_documentation_status => NULL," \
  "p_pricing_model => NULL"; do
  count="$(grep -Fc -- "$parameter" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "QA407 must keep all non-offer-type effective parameters identical: $parameter (found $count)"
done

[[ "$(grep -Fc 'p_offer_type => v_original_offer_type,' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA407 must pass the original offer type exactly once"
[[ "$(grep -Fc 'p_offer_type => v_replay_offer_type,' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA407 must pass the changed offer type exactly once"
[[ "$(grep -Fc 'p_offer_type =>' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA407 must pass offer type exactly once in each call"
[[ "$(grep -Fc 'p_offer_type => NULL,' <<< "$BLOCK" || true)" -eq 0 ]] ||
  fail "QA407 must not retain an additional NULL offer type argument"
[[ "$(grep -Fc 'p_lifecycle => NULL,' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA407 must keep p_lifecycle identical in both calls"
[[ "$(grep -Fc 'p_market =>' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA407 must keep exactly one stable market argument in each call"
[[ "$(grep -Fc 'public.execute_create_offer_v1(' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA407 must contain exactly one initial call and one changed-offer-type replay"
[[ "$(grep -Fc 'DO $qa407_offer_type_mismatch_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA407 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa407_offer_type_mismatch_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA407 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA407 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA407 runtime marker must appear exactly once"

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA407 must assert exactly one original row in each persistence table: $required"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA407 must remain a function-call regression followed by read-only persisted-state assertions"
fi

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-offer-type-mismatch-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA407 exactly once"

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

echo "QA407 static contract PASS: changing only p_offer_type with the same tenant/idempotency key is rejected before persistence and preserves the original state on PostgreSQL 16 and 17.6."
