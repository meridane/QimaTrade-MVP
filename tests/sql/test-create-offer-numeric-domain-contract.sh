#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$RUNTIME" "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required numeric-domain contract file is missing: $file"
done

quantity_guard="IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN"
price_guard="IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN"

[[ "$(grep -Fc "$quantity_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "quantity must retain NULL, NaN, both infinity and positive-only validation"
[[ "$(grep -Fc "$price_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "price must retain NULL, NaN, both infinity and non-negative validation"
grep -Fq "RAISE EXCEPTION 'INVALID_QUANTITY';" "$MIGRATION" ||
  fail "quantity domain guard must retain INVALID_QUANTITY"
grep -Fq "RAISE EXCEPTION 'INVALID_PRICE';" "$MIGRATION" ||
  fail "price domain guard must retain INVALID_PRICE"

QA384_BLOCK="$(sed -n '/^DO \$qa384_numeric_domain\$$/,/^\$qa384_numeric_domain\$;/p' "$RUNTIME")"
[[ -n "$QA384_BLOCK" ]] || fail "runtime is missing the QA384 numeric-domain matrix"

for required in \
  "('negative-infinity-quantity', '-Infinity'::numeric, 12::numeric, 'INVALID_QUANTITY'::text," \
  "('nan-price', 1::numeric, 'NaN'::numeric, 'INVALID_PRICE'::text," \
  "('negative-infinity-price', 1::numeric, '-Infinity'::numeric, 'INVALID_PRICE'::text," \
  'GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;' \
  'IF v_error IS DISTINCT FROM v_case.expected_error THEN' \
  'FROM public.idempotency_keys' \
  'FROM public.action_executions' \
  'FROM public.offers' \
  'QA384 PASS: CREATE_OFFER rejects negative Infinity quantity, NaN price, and negative Infinity price without persisted side effects'; do
  grep -Fq -- "$required" <<< "$QA384_BLOCK" ||
    fail "QA384 runtime matrix is missing required case/assertion: $required"
done

for key in negative-infinity-quantity nan-price negative-infinity-price; do
  [[ "$(grep -Fc "'$key'" <<< "$QA384_BLOCK" || true)" -eq 1 ]] ||
    fail "QA384 must characterize $key exactly once"
done

[[ "$(grep -Fc 'create-offer-runtime.sql' "$RUNNER" || true)" -eq 1 ]] ||
  fail "the shared disposable integration runner must execute create-offer-runtime.sql exactly once"

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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-numeric-domain-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute the QA384 numeric-domain contract exactly once"

[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute the shared runtime fixture exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image is missing"

[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute the shared runtime fixture exactly once"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image is missing"

echo "QA384 PASS: CREATE_OFFER retains finite positive-quantity/non-negative-price guards and runtime coverage for the missing negative-Infinity/NaN numeric cases."
