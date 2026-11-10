#!/usr/bin/env bash
set -euo pipefail

workflow_path="${1:-.github/workflows/ci.yml}"
if [[ ! -f "$workflow_path" ]]; then
  echo "ERROR: workflow file not found: $workflow_path" >&2
  exit 1
fi

concurrency_block="$(awk '
  /^concurrency:[[:space:]]*$/ { in_concurrency = 1; print; next }
  in_concurrency && /^[^[:space:]#]/ { exit }
  in_concurrency { print }
' "$workflow_path")"

expected_group='  group: qima-ci-${{ github.event_name }}-${{ github.ref }}'
expected_cancel="  cancel-in-progress: ${{ github.event_name != 'pull_request' }}"

if [[ "$(grep -Fxc -- "$expected_group" <<< "$concurrency_block" || true)" -ne 1 ]]; then
  echo "ERROR: concurrency group must isolate each event name and ref." >&2
  printf '%s\n' "$concurrency_block" >&2
  exit 1
fi

if [[ "$(grep -Fxc -- "$expected_cancel" <<< "$concurrency_block" || true)" -ne 1 ]]; then
  echo "ERROR: PR runs must remain non-cancelling while non-PR runs retain stale-run cancellation." >&2
  printf '%s\n' "$concurrency_block" >&2
  exit 1
fi

if grep -Fq '  group: qima-ci-${{ github.ref }}' <<< "$concurrency_block"; then
  echo "ERROR: event types still share a concurrency group." >&2
  exit 1
fi

echo "Workflow concurrency regression passed: PR, push, schedule, and workflow_dispatch runs use separate event/ref groups; only non-PR runs cancel stale active runs."
