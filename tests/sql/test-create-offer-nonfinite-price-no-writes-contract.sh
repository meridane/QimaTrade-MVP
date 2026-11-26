#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
SQL="$ROOT/tests/sql/create-offer-nonfinite-price-no-writes.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$SQL" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA424 file is missing: $file"
done

line_of() {
  local needle="$1"
  local line
  line="$(grep -nF -- "$needle" "$MIGRATION" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "migration is missing the existing price guard: $needle"
  printf '%s\n' "$line"
}

price_guard_line="$(line_of "IF p_price IS NULL OR p_price::text IN ('NaN', 'Infinity', '-Infinity') OR p_price < 0 THEN")"
price_error_line="$(line_of "RAISE EXCEPTION 'INVALID_PRICE';")"
hash_line="$(line_of "v_hash := md5(jsonb_build_object(")"
lock_line="$(line_of "PERFORM pg_advisory_xact_lock(")"
insert_line="$(line_of "INSERT INTO public.action_executions(")"

(( price_guard_line < price_error_line && price_error_line < hash_line && hash_line < lock_line && lock_line < insert_line )) ||
  fail "the non-finite/negative price guard must precede hash, idempotency lock and persistence"

for required in \
  "('nan-price'::text, 'NaN'::numeric, 'QA424 NaN Price Rejection Offer'::text)" \
  "('negative-infinity-price'::text, '-Infinity'::numeric, 'QA424 Negative Infinity Price Rejection Offer'::text)" \
  "p_price => v_case.price_value" \
  "IF v_error IS DISTINCT FROM 'INVALID_PRICE' THEN" \
  "(SELECT count(*)::integer FROM public.idempotency_keys)" \
  "(SELECT count(*)::integer FROM public.action_executions)" \
  "(SELECT count(*)::integer FROM public.offers)" \
  "(SELECT count(*)::integer FROM public.action_events)" \
  "v_before.idempotency_count" \
  "v_before.execution_count" \
  "v_before.offer_count" \
  "v_before.event_count" \
  "v_after.idempotency_count" \
  "v_after.execution_count" \
  "v_after.offer_count" \
  "v_after.event_count" \
  "JOIN public.action_executions x ON x.id = e.execution_id" \
  "QA424 PASS: NaN and negative Infinity prices are rejected as INVALID_PRICE without writes to idempotency_keys, action_executions, offers or action_events"; do
  grep -Fq -- "$required" "$SQL" || fail "QA424 SQL is missing required assertion: $required"
done

for value in "'NaN'::numeric" "'-Infinity'::numeric"; do
  [[ "$(grep -Fc -- "$value" "$SQL" || true)" -eq 1 ]] ||
    fail "QA424 must characterize $value exactly once"
done

[[ "$(grep -Fc 'public.execute_create_offer_v1(' "$SQL" || true)" -eq 1 ]] ||
  fail "QA424 must use exactly one RPC call inside its two-case matrix"
[[ "$(grep -Fc 'QA424 PASS:' "$SQL" || true)" -eq 1 ]] ||
  fail "QA424 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' "$SQL"; then
  fail "QA424 SQL must use the RPC and read-only assertions, not direct DML or schema changes"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-nonfinite-price-no-writes-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA424 static contract exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-nonfinite-price-no-writes.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute QA424 runtime exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-nonfinite-price-no-writes.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute QA424 runtime exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image is missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image is missing"

echo "QA424 static contract PASS: NaN and negative Infinity price rejection preserves all four persistence tables on PostgreSQL 16 and 17.6."
