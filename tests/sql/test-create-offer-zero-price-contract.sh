#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA391 file is missing: $file"
done

price_guard="IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN"
[[ "$(grep -Fc "$price_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing non-negative price guard must remain unchanged"
grep -Fq "RAISE EXCEPTION 'INVALID_PRICE';" "$MIGRATION" ||
  fail "the price guard must retain INVALID_PRICE"

QA391_BLOCK="$(sed -n '/^DO \$qa391_zero_price_success\$$/,/^\$qa391_zero_price_success\$;/p' "$RUNTIME")"
[[ -n "$QA391_BLOCK" ]] || fail "runtime is missing the QA391 zero-price block"

for required in \
  "v_key text := 'fixture-qa391-zero-price';" \
  "v_offer_name text := 'QA391 Zero Price Offer';" \
  "v_first_result := public.execute_create_offer_v1(" \
  "v_replay_result := public.execute_create_offer_v1(" \
  "p_quantity => 1::numeric," \
  "p_price => 0::numeric," \
  "v_first_result->>'status' IS DISTINCT FROM 'succeeded'" \
  "v_first_result->>'objectType' IS DISTINCT FROM 'Offer'" \
  "AND price = 0::numeric" \
  "AND status = 'COMPLETED'" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "IS DISTINCT FROM ROW(" \
  "v_replay_result IS DISTINCT FROM v_first_result" \
  "QA391 PASS: zero price is accepted by the existing non-negative SQL contract, persisted as zero, and exactly replayed without duplicate rows"; do
  grep -Fq -- "$required" <<< "$QA391_BLOCK" ||
    fail "QA391 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc 'p_price => 0::numeric,' <<< "$QA391_BLOCK" || true)" -eq 2 ]] ||
  fail "QA391 must use zero price for both the initial request and exact replay"
[[ "$(grep -Fc 'DO $qa391_zero_price_success$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA391 runtime block must appear exactly once"
[[ "$(grep -Fc 'QA391 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA391 marker must appear exactly once"

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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-zero-price-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA391 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 shared runtime runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 shared runtime runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"

echo "QA391 PASS: zero price remains accepted by the existing non-negative SQL contract, is persisted exactly, and replays without duplicate rows on PostgreSQL 16 and 17.6."
