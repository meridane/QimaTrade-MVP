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
  [[ -f "$file" ]] || fail "required QA396 file is missing: $file"
done

input_hash_line="$(grep -nF "'input', p_input," "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
reuse_error_line="$(grep -nF "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" "$MIGRATION" | cut -d: -f1)"
execution_insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"

[[ "$(grep -Fc "'input', p_input," "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the complete request hash must include p_input exactly once"
[[ "$(grep -Fc 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing request-hash mismatch guard must remain unique"
[[ "$(grep -Fc "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the exact IDEMPOTENCY_KEY_REUSE error must remain unique"
[[ -n "$input_hash_line" && -n "$reuse_line" && -n "$reuse_error_line" && -n "$execution_insert_line" ]] ||
  fail "input hash, mismatch guard or persistence statements are missing"
(( input_hash_line < reuse_line && reuse_line < reuse_error_line && reuse_error_line < execution_insert_line )) ||
  fail "input must be hashed and mismatches rejected before new action execution persistence"

BLOCK="$(sed -n '/^DO \$qa396_input_mismatch_replay\$$/,/^\$qa396_input_mismatch_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA396 input mismatch replay block"

for required in \
  "v_key text := 'fixture-qa396-input-mismatch';" \
  "v_input jsonb := '{\"case\":\"qa396_original_input\"}'::jsonb;" \
  "v_replay_input jsonb := '{\"case\":\"qa396_changed_input\"}'::jsonb;" \
  "p_input => v_input," \
  "p_input => v_replay_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'" \
  "IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "request_hash = v_original_hash" \
  "result = v_first_result" \
  "status = 'COMPLETED'" \
  "input = v_input" \
  "quantity = 1::numeric" \
  "price = 12::numeric" \
  "currency = 'USD'" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "v_after_replay.idempotency_count" \
  "v_after_first.idempotency_count" \
  "WHERE name = v_offer_name" \
  "QA396 PASS: changing the action input on a completed request with the same tenant/key raises IDEMPOTENCY_KEY_REUSE"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA396 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc "v_replay_input jsonb :=" <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA396 must declare the changed replay input exactly once"

[[ "$(grep -Fc "p_input => v_input," <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA396 must contain exactly one original-input call"
[[ "$(grep -Fc "p_input => v_replay_input," <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA396 must contain exactly one changed-input replay call"

for expression in \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'"; do
  count="$(grep -Fc "$expression" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "QA396 must keep all non-input effective parameters identical: $expression (found $count)"
done

[[ "$(grep -Fc 'DO $qa396_input_mismatch_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA396 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa396_input_mismatch_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA396 dollar-quoted block must close with the matching input-mismatch tag"
[[ "$(grep -Fc 'QA396 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA396 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA396 must remain a function-call regression followed by read-only persisted-state assertions"
fi

job_section() {
  local target="$1"
  awk -v target="$target" '
    $0 == "  " target ":" { inside = 1; next }
    inside && /^  [[:alnum:]_-]+:$/ { exit }
    inside { print }
  ' "$WORKFLOW"
}

verify_job="$(job_section verify)"
pg16_job="$(job_section postgres-integration)"
pg17_job="$(job_section postgres17-create-offer-compatibility)"

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-input-mismatch-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA396 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 shared runtime runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 shared runtime runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"

echo "QA396 PASS: changing only p_input on a completed CREATE_OFFER request with the same tenant/key raises IDEMPOTENCY_KEY_REUSE and preserves the original four-table persisted state on PostgreSQL 16 and 17.6."
