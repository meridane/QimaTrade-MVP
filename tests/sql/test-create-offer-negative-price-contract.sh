#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
fail() { echo "ERROR: $*" >&2; exit 1; }
for file in "$RUNTIME" "$MIGRATION" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA387 file is missing: $file"
done
price_guard="IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN"
[[ "$(grep -Fc "$price_guard" "$MIGRATION" || true)" -eq 1 ]] || fail "the existing non-negative price guard must remain unchanged"
grep -Fq "RAISE EXCEPTION 'INVALID_PRICE';" "$MIGRATION" || fail "the price guard must retain INVALID_PRICE"
QA387_BLOCK="$(sed -n '/^DO \$qa387_negative_price\$$/,/^\$qa387_negative_price\$;/p' "$RUNTIME")"
[[ -n "$QA387_BLOCK" ]] || fail "runtime is missing the QA387 negative-price block"
for required in \
  "v_key text := 'fixture-qa387-negative-price';" \
  "p_quantity => 1::numeric," \
  "p_price => -1::numeric," \
  "GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;" \
  "IF v_error IS DISTINCT FROM 'INVALID_PRICE' THEN" \
  "FROM public.idempotency_keys" "FROM public.action_executions" \
  "FROM public.offers" "FROM public.action_events" "IS DISTINCT FROM ROW(" \
  "QA387 PASS: finite negative price is rejected as INVALID_PRICE before idempotency, execution, offer or action-event persistence"; do
  grep -Fq -- "$required" <<< "$QA387_BLOCK" || fail "QA387 block is missing required assertion: $required"
done
[[ "$(grep -Fc 'DO $qa387_negative_price$' "$RUNTIME" || true)" -eq 1 ]] || fail "QA387 block must appear exactly once"
[[ "$(grep -Fc 'QA387 PASS:' "$RUNTIME" || true)" -eq 1 ]] || fail "QA387 marker must appear exactly once"
job_section() {
  local target="$1"
  awk -v target="$target" '$0 == "  " target ":" { inside=1; next } inside && /^  [[:alnum:]_-]+:$/ { exit } inside { print }' "$WORKFLOW"
}
verify_job="$(job_section verify)"
pg16_job="$(job_section postgres-integration)"
pg17_job="$(job_section postgres17-create-offer-compatibility)"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-negative-price-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] || fail "Verify must execute QA387 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] || fail "PostgreSQL 16 shared runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] || fail "PostgreSQL 17.6 shared runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image missing"
echo "QA387 PASS: the existing non-negative price boundary is protected by a disposable finite negative-price rejection test with exact error and four-table no-side-effect assertions on PostgreSQL 16 and 17.6."
