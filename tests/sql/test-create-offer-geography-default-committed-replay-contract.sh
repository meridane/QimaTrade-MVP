#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/run-create-offer-geography-default-committed-replay.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA427 file is missing: $file"
done

grep -Fq ': "${DATABASE_URL:?DATABASE_URL is required}"' "$RUNTIME" ||
  fail "QA427 must fail clearly when DATABASE_URL is unset"

[[ "$(grep -Fc 'psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1' "$RUNTIME" || true)" -eq 2 ]] ||
  fail "QA427 must use exactly two independent psql processes"

FIRST_SESSION="$(sed -n '/^# QA427_FIRST_SESSION_BEGIN$/,/^# QA427_FIRST_SESSION_END$/p' "$RUNTIME")"
REPLAY_SESSION="$(sed -n '/^# QA427_REPLAY_SESSION_BEGIN$/,/^# QA427_REPLAY_SESSION_END$/p' "$RUNTIME")"
[[ -n "$FIRST_SESSION" && -n "$REPLAY_SESSION" ]] || fail "QA427 must delimit both committed sessions"

for session in "$FIRST_SESSION" "$REPLAY_SESSION"; do
  [[ "$(grep -Fc 'BEGIN;' <<< "$session" || true)" -eq 1 ]] ||
    fail "each QA427 session must begin one explicit transaction"
  [[ "$(grep -Fc 'COMMIT;' <<< "$session" || true)" -eq 1 ]] ||
    fail "each QA427 session must commit its transaction"
done

grep -Fq "SET application_name = 'qima-qa427-geography-default-first';" <<< "$FIRST_SESSION" ||
  fail "first QA427 session must have its own application_name"
grep -Fq "SET application_name = 'qima-qa427-geography-default-replay';" <<< "$REPLAY_SESSION" ||
  fail "replay QA427 session must have a distinct application_name"

FIRST_CALL="$(sed -n '/v_result := public.execute_create_offer_v1(/,/^  );/p' <<< "$FIRST_SESSION")"
REPLAY_CALL="$(sed -n '/v_replay_result := public.execute_create_offer_v1(/,/^  );/p' <<< "$REPLAY_SESSION")"
[[ -n "$FIRST_CALL" && -n "$REPLAY_CALL" ]] || fail "QA427 must call CREATE_OFFER once in each session"
if grep -Fq 'p_geography =>' <<< "$FIRST_CALL"; then
  fail "the first QA427 session must omit p_geography"
fi
[[ "$(grep -Fc 'p_geography => NULL' <<< "$REPLAY_CALL" || true)" -eq 1 ]] ||
  fail "the second QA427 session must explicitly replay p_geography as NULL"

for parameter in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'," \
  "p_conditions => NULL," \
  "p_market => NULL," \
  "p_attributes => '{}'::jsonb," \
  "p_documentation_status => NULL," \
  "p_lifecycle => NULL," \
  "p_offer_type => 'fixture-offer-type-stable'," \
  "p_pricing_model => 'fixture-pricing-model-stable'"; do
  count="$(grep -Fc -- "$parameter" "$RUNTIME" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "all non-geography effective parameters must match across sessions: $parameter (found $count)"
done

[[ "$(grep -Fc 'QA427 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA427 runtime marker must appear exactly once"
[[ "$(grep -Fc 'QA427 FIRST COMMITTED SESSION PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA427 first-session marker must appear exactly once"
[[ "$(grep -Fc "v_key text := 'fixture-qa427-geography-default-committed-replay';" "$RUNTIME" || true)" -eq 2 ]] ||
  fail "QA427 must declare the same unique idempotency key in both sessions"
[[ "$(grep -Fc "v_input jsonb := '{\"case\":\"qa427-geography-default-committed-replay\"}'::jsonb;" "$RUNTIME" || true)" -eq 2 ]] ||
  fail "QA427 must use the same request input in both sessions"
[[ "$(grep -Fc "v_offer_name text := 'QA427 Geography Default Committed Replay Offer';" "$RUNTIME" || true)" -eq 2 ]] ||
  fail "QA427 must use the same offer name in both sessions"
[[ "$(grep -Fc 'postgresql://postgres:postgres@localhost:5432/qima_test' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA427 must be restricted to the disposable loopback qima_test database"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' "$RUNTIME"; then
  fail "QA427 must not perform direct DML or persistent schema/privilege changes"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-geography-default-committed-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute the QA427 static contract exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-geography-default-committed-replay.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute the QA427 committed-session runtime exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-geography-default-committed-replay.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute the QA427 committed-session runtime exactly once"

pg16_runner_line="$(grep -nF 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" | cut -d: -f1)"
pg16_qa413_line="$(grep -nF 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-geography-default-replay.sql' <<< "$pg16_job" | cut -d: -f1)"
pg16_qa427_line="$(grep -nF 'run: bash tests/sql/run-create-offer-geography-default-committed-replay.sh' <<< "$pg16_job" | cut -d: -f1)"
pg16_repeat_line="$(grep -nF 'run: bash tests/sql/test-create-offer-integration-repeat-guard.sh' <<< "$pg16_job" | cut -d: -f1)"
pg17_runner_line="$(grep -nF 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" | cut -d: -f1)"
pg17_qa413_line="$(grep -nF 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-geography-default-replay.sql' <<< "$pg17_job" | cut -d: -f1)"
pg17_qa427_line="$(grep -nF 'run: bash tests/sql/run-create-offer-geography-default-committed-replay.sh' <<< "$pg17_job" | cut -d: -f1)"
pg17_repeat_line="$(grep -nF 'run: bash tests/sql/test-create-offer-integration-repeat-guard.sh' <<< "$pg17_job" | cut -d: -f1)"

[[ -n "$pg16_runner_line" && -n "$pg16_qa413_line" && -n "$pg16_qa427_line" && -n "$pg16_repeat_line" &&
   "$pg16_runner_line" -lt "$pg16_qa413_line" && "$pg16_qa413_line" -lt "$pg16_qa427_line" && "$pg16_qa427_line" -lt "$pg16_repeat_line" ]] ||
  fail "PostgreSQL 16 must initialize fixtures, run QA413, run QA427, then verify repeat-run isolation"
[[ -n "$pg17_runner_line" && -n "$pg17_qa413_line" && -n "$pg17_qa427_line" && -n "$pg17_repeat_line" &&
   "$pg17_runner_line" -lt "$pg17_qa413_line" && "$pg17_qa413_line" -lt "$pg17_qa427_line" && "$pg17_qa427_line" -lt "$pg17_repeat_line" ]] ||
  fail "PostgreSQL 17.6 must initialize fixtures, run QA413, run QA427, then verify repeat-run isolation"

grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image is missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image is missing"
grep -Fq 'DATABASE_URL: postgresql://postgres:postgres@localhost:5432/qima_test' <<< "$pg16_job" ||
  fail "PostgreSQL 16 must use the disposable loopback database"
grep -Fq 'DATABASE_URL: postgresql://postgres:postgres@localhost:5432/qima_test' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 must use the disposable loopback database"

echo "QA427 static contract PASS: omitted p_geography is committed in one PostgreSQL session and exact explicit-NULL replay is verified from a second session on PostgreSQL 16 and 17.6."
