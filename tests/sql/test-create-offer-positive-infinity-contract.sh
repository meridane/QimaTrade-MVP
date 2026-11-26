#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA388 file is missing: $file"
done

quantity_guard="IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN"
price_guard="IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN"
[[ "$(grep -Fc "$quantity_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "quantity must continue rejecting NULL, NaN and both infinities"
[[ "$(grep -Fc "$price_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "price must continue rejecting NULL, NaN and both infinities"
grep -Fq "RAISE EXCEPTION 'INVALID_QUANTITY';" "$MIGRATION" ||
  fail "quantity guard must retain INVALID_QUANTITY"
grep -Fq "RAISE EXCEPTION 'INVALID_PRICE';" "$MIGRATION" ||
  fail "price guard must retain INVALID_PRICE"

QA388_BLOCK="$(sed -n '/^DO \$qa388_positive_infinity\$$/,/^\$qa388_positive_infinity\$;/p' "$RUNTIME")"
[[ -n "$QA388_BLOCK" ]] || fail "runtime is missing the QA388 positive-Infinity matrix"

for required in \
  "('positive-infinity-quantity', 'Infinity'::numeric, 12::numeric, 'INVALID_QUANTITY'::text," \
  "('positive-infinity-price', 1::numeric, 'Infinity'::numeric, 'INVALID_PRICE'::text," \
  "GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;" \
  "IF v_error IS DISTINCT FROM v_case.expected_error THEN" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "IS DISTINCT FROM ROW(" \
  "QA388 PASS: positive Infinity quantity and price are rejected with exact domain errors before idempotency, execution, offer or action-event persistence"; do
  grep -Fq -- "$required" <<< "$QA388_BLOCK" ||
    fail "QA388 matrix is missing required assertion: $required"
done

for key in positive-infinity-quantity positive-infinity-price; do
  [[ "$(grep -Fc "'$key'" <<< "$QA388_BLOCK" || true)" -eq 1 ]] ||
    fail "QA388 must characterize $key exactly once"
done

[[ "$(grep -Fc 'DO $qa388_positive_infinity$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA388 block must appear exactly once"
[[ "$(grep -Fc 'QA388 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA388 marker must appear exactly once"

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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-positive-infinity-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA388 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 shared runtime runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 shared runtime runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"

echo "QA388 PASS: positive Infinity quantity and price retain exact domain errors and four-table no-side-effect assertions on PostgreSQL 16 and 17.6."
