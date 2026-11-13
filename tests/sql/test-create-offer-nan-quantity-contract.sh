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
  [[ -f "$file" ]] || fail "required QA389 file is missing: $file"
done

quantity_guard="IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN"
[[ "$(grep -Fc "$quantity_guard" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "quantity must retain NULL, NaN, both infinity and positive-only validation"
grep -Fq "RAISE EXCEPTION 'INVALID_QUANTITY';" "$MIGRATION" ||
  fail "quantity guard must retain INVALID_QUANTITY"

QA389_BLOCK="$(sed -n '/^DO \$qa389_nan_quantity\$$/,/^\$qa389_nan_quantity\$;/p' "$RUNTIME")"
[[ -n "$QA389_BLOCK" ]] || fail "runtime is missing the QA389 NaN-quantity block"

for required in \
  "p_quantity => 'NaN'::numeric," \
  "p_price => 12::numeric" \
  "IF v_error IS DISTINCT FROM 'INVALID_QUANTITY' THEN" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "IS DISTINCT FROM ROW(" \
  "QA389 PASS: NaN quantity is rejected as INVALID_QUANTITY before idempotency, execution, offer or action-event persistence"; do
  grep -Fq -- "$required" <<< "$QA389_BLOCK" ||
    fail "QA389 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc 'DO $qa389_nan_quantity$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA389 runtime block must appear exactly once"
[[ "$(grep -Fc 'QA389 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA389 runtime marker must appear exactly once"

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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-nan-quantity-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA389 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 shared runtime runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 shared runtime runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"

echo "QA389 PASS: NaN quantity retains the exact INVALID_QUANTITY contract and four-table no-side-effect assertions on PostgreSQL 16 and 17.6."
