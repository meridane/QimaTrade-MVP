#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)"
fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for entry in \
  "410:attributes" \
  "411:conditions" \
  "412:market" \
  "413:geography"; do
  qa="${entry%%:*}"
  parameter="${entry#*:}"
  contract="$ROOT/tests/sql/test-create-offer-${parameter}-default-replay-contract.sh"
  [[ -f "$contract" ]] || fail "QA${qa} diagnostic contract is missing: $contract"

  grep -Fq "runtime is missing the QA${qa} ${parameter}-default replay block" "$contract" ||
    fail "QA${qa} must identify its own ${parameter}-default replay block in the missing-block diagnostic"
  grep -Fq "all non-${parameter} effective parameters must remain identical across both calls" "$contract" ||
    fail "QA${qa} must name ${parameter} as the only parameter allowed to differ"
done

qa413_contract="$ROOT/tests/sql/test-create-offer-geography-default-replay-contract.sh"
block_guard_line="$(grep -nF '[[ -n "$BLOCK" ]] || fail "runtime is missing the QA413 geography-default replay block"' "$qa413_contract" | cut -d: -f1)"
input_line="$(grep -nF 'INPUT_LINE=' "$qa413_contract" | head -n 1 | cut -d: -f1)"
[[ -n "$block_guard_line" && -n "$input_line" && "$block_guard_line" -lt "$input_line" ]] ||
  fail "QA413 must reject a missing runtime block before attempting to inspect its input fixture"

if grep -Fq 'runtime is missing the QA413 market-default replay block' "$qa413_contract"; then
  fail "QA413 missing-block diagnostic must not identify the QA412 market parameter"
fi
if grep -Fq 'all non-market effective parameters must remain identical across both calls' "$qa413_contract"; then
  fail "QA413 parameter-mismatch diagnostic must identify geography, not market"
fi

echo "QA426 static contract PASS: QA410-QA413 default-replay diagnostics identify the correct parameter, and QA413 validates block presence before parsing its fixture."
