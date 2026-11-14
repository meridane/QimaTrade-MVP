#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
SQL_FILE="$ROOT/tests/sql/idempotency-numeric-lexical-characterization.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNNER" "$SQL_FILE" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required characterization contract file is missing: $file"
done

line_number() {
  local file="$1"
  local needle="$2"
  local line
  line="$(grep -nF -- "$needle" "$file" | head -n 1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "required runner step was not found: $needle"
  printf '%s' "$line"
}

guard_line="$(line_number "$RUNNER" 'if [[ ! "$DATABASE_URL" =~')"
first_psql_line="$(line_number "$RUNNER" '"${PSQL[@]}" -f "$ROOT/tests/sql/fixtures/create-offer-schema.sql"')"
runtime_line="$(line_number "$RUNNER" '"${PSQL[@]}" -f "$ROOT/tests/sql/create-offer-runtime.sql"')"
qa315_call='"${PSQL[@]}" -f "$ROOT/tests/sql/idempotency-numeric-lexical-characterization.sql"'
qa315_line="$(line_number "$RUNNER" "$qa315_call")"
concurrency_line="$(line_number "$RUNNER" '# Race two first-time requests with the same tenant/key.')"

[[ "$(grep -Fc -- "$qa315_call" "$RUNNER")" -eq 1 ]] ||
  fail "the QA315 SQL characterization must be invoked exactly once by the integration runner"

if ! (( guard_line < first_psql_line &&
        first_psql_line < runtime_line &&
        runtime_line < qa315_line &&
        qa315_line < concurrency_line )); then
  fail "runner ordering changed: URL guard, fixture, runtime, QA315, and concurrency must remain in that order"
fi

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|COPY|EXECUTE|PERFORM|COMMIT|ROLLBACK|SAVEPOINT|SET|RESET)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' "$SQL_FILE"); then
  fail "QA315 SQL contains a statement outside its read-only characterization contract"
fi

if awk '
  /^[[:space:]]*--/ { next }
  {
    line = tolower($0)
    if (match(line, /^[[:space:]]*from[[:space:]]+/)) {
      source = substr(line, RSTART + RLENGTH)
      if (source !~ /^unnest[[:space:]]*\(/) {
        print NR ":" $0
        bad = 1
      }
    }
  }
  END { exit bad ? 0 : 1 }
' "$SQL_FILE"; then
  fail "QA315 SQL must not read database tables; only local-array unnest() sources are allowed"
fi

[[ "$(grep -Ec '^[[:space:]]*DO[[:space:]]+\$qa315\$' "$SQL_FILE")" -eq 1 ]] ||
  fail "QA315 must remain one local DO block"
[[ "$(grep -Ec '^\$qa315\$;' "$SQL_FILE")" -eq 1 ]] ||
  fail "QA315 DO block terminator is missing or duplicated"
[[ "$(grep -Ec '^[[:space:]]*FROM[[:space:]]+unnest\(' "$SQL_FILE")" -eq 8 ]] ||
  fail "QA315 must retain its eight local-array aggregation reads"

for value in 1 1.0 1.00 1e0 10e-1 100e-2; do
  grep -Fq "'$value'::numeric" "$SQL_FILE" ||
    fail "QA315 typed numeric lexical form is missing: $value"
  grep -Fq "'$value'::jsonb" "$SQL_FILE" ||
    fail "QA315 JSONB lexical form is missing: $value"
done

grep -Fq "jsonb_build_object('amount', v_json)" "$SQL_FILE" ||
  fail "QA315 nested JSONB object characterization is missing"
grep -Fq "jsonb_build_array(v_object)" "$SQL_FILE" ||
  fail "QA315 nested JSONB array characterization is missing"
grep -Fq "QA315 numeric scale and exponent lexical-form characterization PASS" "$SQL_FILE" ||
  fail "QA315 success marker is missing"

job_section() {
  local job="$1"
  awk -v target="$job" '
    $0 == "  " target ":" { inside = 1; next }
    inside && /^  [[:alnum:]_-]+:$/ { exit }
    inside { print }
  ' "$WORKFLOW"
}

verify_job="$(job_section verify)"
pg16_job="$(job_section postgres-integration)"
pg17_job="$(job_section postgres17-create-offer-compatibility)"

grep -Fq 'run: bash tests/sql/test-idempotency-numeric-characterization-contract.sh' <<< "$verify_job" ||
  fail "Verify job does not run the QA315 read-only/wiring contract test"

[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job")" -eq 1 ]] ||
  fail "PostgreSQL 16 job must invoke the shared CREATE_OFFER integration runner exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 job image is missing"

[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job")" -eq 1 ]] ||
  fail "PostgreSQL 17.6 job must invoke the shared CREATE_OFFER integration runner exactly once"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 job image is missing"

pg17_guard_line="$(grep -nF 'bash tests/sql/assert-postgres-17-6-version.sh "$version_num"' <<< "$pg17_job" | head -n 1 | cut -d: -f1 || true)"
pg17_runner_line="$(grep -nF 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" | head -n 1 | cut -d: -f1 || true)"
[[ -n "$pg17_guard_line" && -n "$pg17_runner_line" ]] ||
  fail "PostgreSQL 17.6 version guard or integration runner invocation is missing"
if ! (( pg17_guard_line < pg17_runner_line )); then
  fail "PostgreSQL 17.6 exact-version guard must run before the shared integration runner"
fi

echo "QA360 PASS: QA315 remains a read-only local-array characterization, is invoked once after the runtime fixture and before concurrency, and is covered by both guarded PostgreSQL 16 and PostgreSQL 17.6 CI jobs."
