#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
SQL="$ROOT/tests/sql/create-offer-currency-rejection-no-writes.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$SQL" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA422 file is missing: $file"
done

line_of() {
  local needle="$1"
  local line
  line="$(grep -nF -- "$needle" "$MIGRATION" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "migration is missing required currency guard: $needle"
  printf '%s\n' "$line"
}

currency_guard_line="$(line_of "IF nullif(trim(p_currency), '') IS NULL OR p_currency NOT IN ('USD', 'EUR', 'KRW', 'MAD', 'CNY') THEN")"
currency_error_line="$(line_of "RAISE EXCEPTION 'INVALID_CURRENCY';")"
hash_line="$(line_of "v_hash := md5(jsonb_build_object(")"
lock_line="$(line_of "PERFORM pg_advisory_xact_lock(")"
insert_line="$(line_of "INSERT INTO public.action_executions(")"

(( currency_guard_line < currency_error_line && currency_error_line < hash_line && hash_line < lock_line && lock_line < insert_line )) ||
  fail "currency validation must reject unsupported values before hash, idempotency lock and persistence"

for required in \
  "('unsupported', 'XYZ'::text," \
  "('null', NULL::text," \
  "('blank', '   '::text," \
  "('padded', ' USD '::text," \
  "('lowercase', 'usd'::text," \
  "p_currency => v_case.currency_value" \
  "IF v_error IS DISTINCT FROM 'INVALID_CURRENCY' THEN" \
  "(SELECT count(*) FROM public.idempotency_keys)" \
  "(SELECT count(*) FROM public.action_executions)" \
  "(SELECT count(*) FROM public.offers)" \
  "(SELECT count(*) FROM public.action_events)" \
  "v_before.idempotency_count" \
  "v_before.execution_count" \
  "v_before.offer_count" \
  "v_before.event_count" \
  "v_after.idempotency_count" \
  "v_after.execution_count" \
  "v_after.offer_count" \
  "v_after.event_count" \
  "QA422 PASS: unsupported, NULL, blank, padded and lowercase currencies are rejected before all four persistence tables change"; do
  grep -Fq -- "$required" "$SQL" || fail "QA422 SQL is missing required case/assertion: $required"
done

for case_key in unsupported null blank padded lowercase; do
  [[ "$(grep -Fc "('$case_key'," "$SQL" || true)" -eq 1 ]] ||
    fail "QA422 must characterize $case_key exactly once"
done

[[ "$(grep -Fc 'QA422 PASS:' "$SQL" || true)" -eq 1 ]] ||
  fail "QA422 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' "$SQL"; then
  fail "QA422 SQL must use the RPC and read-only assertions, not direct DML or schema changes"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-currency-rejection-no-writes-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA422 static contract exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-currency-rejection-no-writes.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute QA422 runtime exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-currency-rejection-no-writes.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute QA422 runtime exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image is missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image is missing"

echo "QA422 static contract PASS: invalid currency variants are rejected before idempotency and preserve all four persistence tables on PostgreSQL 16 and 17.6."
