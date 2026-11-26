#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
SQL="$ROOT/tests/sql/create-offer-supported-currency-acceptance.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$SQL" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA423 file is missing: $file"
done

line_of() {
  local needle="$1"
  local line
  line="$(grep -nF -- "$needle" "$MIGRATION" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "migration is missing the supported-currency contract: $needle"
  printf '%s\n' "$line"
}

currency_guard_line="$(line_of "IF nullif(trim(p_currency), '') IS NULL OR p_currency NOT IN ('USD', 'EUR', 'KRW', 'MAD', 'CNY') THEN")"
currency_error_line="$(line_of "RAISE EXCEPTION 'INVALID_CURRENCY';")"
hash_line="$(line_of "v_hash := md5(jsonb_build_object(")"
lock_line="$(line_of "PERFORM pg_advisory_xact_lock(")"
insert_line="$(line_of "INSERT INTO public.action_executions(")"

(( currency_guard_line < currency_error_line && currency_error_line < hash_line && hash_line < lock_line && lock_line < insert_line )) ||
  fail "supported-currency guard must precede hash, idempotency lock and persistence"

for required in \
  "('USD'::text, 'QA423 USD Supported Currency Offer'::text)" \
  "('EUR'::text, 'QA423 EUR Supported Currency Offer'::text)" \
  "('KRW'::text, 'QA423 KRW Supported Currency Offer'::text)" \
  "('MAD'::text, 'QA423 MAD Supported Currency Offer'::text)" \
  "('CNY'::text, 'QA423 CNY Supported Currency Offer'::text)" \
  "p_currency => v_case.currency_code" \
  "v_first_result->>'status' IS DISTINCT FROM 'succeeded'" \
  "v_stored_currency IS DISTINCT FROM v_case.currency_code" \
  "v_replay_result IS DISTINCT FROM v_first_result" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_after_first.idempotency_count" \
  "v_after_first.execution_count" \
  "v_after_first.offer_count" \
  "v_after_first.event_count" \
  "v_after_replay.idempotency_count" \
  "v_after_replay.execution_count" \
  "v_after_replay.offer_count" \
  "v_after_replay.event_count" \
  "QA423 PASS: USD, EUR, KRW, MAD and CNY are accepted, persisted exactly and replayed without duplicate rows"; do
  grep -Fq -- "$required" "$SQL" || fail "QA423 SQL is missing required acceptance/replay assertion: $required"
done

for currency in USD EUR KRW MAD CNY; do
  [[ "$(grep -Fc "('$currency'::text," "$SQL" || true)" -eq 1 ]] ||
    fail "QA423 must characterize $currency exactly once"
done

[[ "$(grep -Fc 'public.execute_create_offer_v1(' "$SQL" || true)" -eq 2 ]] ||
  fail "QA423 must contain exactly one creation call and one exact replay call"
[[ "$(grep -Fc 'QA423 PASS:' "$SQL" || true)" -eq 1 ]] ||
  fail "QA423 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' "$SQL"; then
  fail "QA423 SQL must use the RPC and read-only assertions, not direct DML or schema changes"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-supported-currency-acceptance-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA423 static contract exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-supported-currency-acceptance.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute QA423 runtime exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-supported-currency-acceptance.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute QA423 runtime exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image is missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image is missing"

echo "QA423 static contract PASS: all five migration-whitelisted currencies are accepted, persisted exactly and exactly replayed on PostgreSQL 16 and 17.6."
