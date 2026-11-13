#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA386 file is missing: $file"
done

quantity_guard="IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN"
[[ "$(grep -Fc "$quantity_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing strictly-positive quantity guard must remain unchanged"
grep -Fq "RAISE EXCEPTION 'INVALID_QUANTITY';" "$MIGRATION" ||
  fail "the quantity guard must retain INVALID_QUANTITY"

QA386_BLOCK="$(sed -n '/^DO \$qa386_negative_quantity\$$/,/^\$qa386_negative_quantity\$;/p' "$RUNTIME")"
[[ -n "$QA386_BLOCK" ]] || fail "runtime is missing the QA386 negative-quantity block"

for required in \
  "v_key text := 'fixture-qa386-negative-quantity';" \
  "p_quantity => -1::numeric," \
  "p_price => 12::numeric," \
  "GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;" \
  "IF v_error IS DISTINCT FROM 'INVALID_QUANTITY' THEN" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "IS DISTINCT FROM ROW(" \
  "QA386 PASS: finite negative quantity is rejected as INVALID_QUANTITY before idempotency, execution, offer or action-event persistence"; do
  grep -Fq -- "$required" <<< "$QA386_BLOCK" ||
    fail "QA386 block is missing required case/assertion: $required"
done

[[ "$(grep -Fc 'DO $qa386_negative_quantity$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA386 negative-quantity runtime block must appear exactly once"
[[ "$(grep -Fc 'QA386 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA386 runtime success marker must appear exactly once"

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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-negative-quantity-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute the QA386 negative-quantity contract exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute the shared runtime fixture exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute the shared runtime fixture exactly once"

echo "QA386 PASS: the existing positive-quantity boundary is protected by a disposable finite negative-quantity rejection test with exact error and four-table no-side-effect assertions on PostgreSQL 16 and 17.6."
