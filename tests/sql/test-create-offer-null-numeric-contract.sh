#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
fail() { echo "ERROR: $*" >&2; exit 1; }
for file in "$RUNTIME" "$MIGRATION" "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA390 file is missing: $file"
done
quantity_guard="IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN"
price_guard="IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN"
grep -Fq "$quantity_guard" "$MIGRATION" || fail "quantity SQL NULL guard missing"
grep -Fq "$price_guard" "$MIGRATION" || fail "price SQL NULL guard missing"
grep -Fq "RAISE EXCEPTION 'INVALID_QUANTITY';" "$MIGRATION" || fail "INVALID_QUANTITY error missing"
grep -Fq "RAISE EXCEPTION 'INVALID_PRICE';" "$MIGRATION" || fail "INVALID_PRICE error missing"
QA390_BLOCK="$(sed -n '/^DO \$qa390_null_numeric_values\$$/,/^\$qa390_null_numeric_values\$;/p' "$RUNTIME")"
[[ -n "$QA390_BLOCK" ]] || fail "runtime is missing the QA390 NULL-numeric block"
for required in \
  "('null-quantity', NULL::numeric, 12::numeric, 'INVALID_QUANTITY'::text" \
  "('null-price', 1::numeric, NULL::numeric, 'INVALID_PRICE'::text" \
  "p_quantity => v_case.quantity_value," "p_price => v_case.price_value," \
  "IF v_error IS DISTINCT FROM v_case.expected_error THEN" \
  "FROM public.idempotency_keys" "FROM public.action_executions" \
  "FROM public.offers" "FROM public.action_events" "IS DISTINCT FROM" \
  "QA390 PASS: NULL quantity and NULL price are rejected with exact domain errors before idempotency, execution, offer or action-event persistence"; do
  grep -Fq -- "$required" <<< "$QA390_BLOCK" || fail "QA390 assertion missing: $required"
done
[[ "$(grep -Fc 'DO $qa390_null_numeric_values$' "$RUNTIME" || true)" -eq 1 ]] || fail "QA390 block must appear once"
[[ "$(grep -Fc 'QA390 PASS:' "$RUNTIME" || true)" -eq 1 ]] || fail "QA390 marker must appear once"
job_section() {
  local target="$1"
  awk -v target="$target" '$0 == "  " target ":" { inside=1; next } inside && /^  [[:alnum:]_-]+:$/ { exit } inside { print }' "$WORKFLOW"
}
verify_job="$(job_section verify)"
pg16_job="$(job_section postgres-integration)"
pg17_job="$(job_section postgres17-create-offer-compatibility)"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-null-numeric-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] || fail "Verify must execute QA390 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] || fail "PostgreSQL 16 runtime wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] || fail "PostgreSQL 17.6 runtime wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 image missing"
echo "QA390 PASS: SQL NULL quantity and price retain exact domain errors and four-table no-side-effect assertions on PostgreSQL 16 and 17.6."
