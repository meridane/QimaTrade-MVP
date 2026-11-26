#!/usr/bin/env sh
set -eu

# Disposable standalone PostgreSQL fixture only; this script never contacts Supabase Cloud.
COMPOSE_FILE="docker-compose.qima-security.yml"
COMPOSE_PROJECT_NAME="qima-security-fixture-$$"

compose() {
  docker compose --project-name "$COMPOSE_PROJECT_NAME" --file "$COMPOSE_FILE" "$@"
}

command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required." >&2; exit 2; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: Docker Compose plugin is required." >&2; exit 2; }
[ -f "$COMPOSE_FILE" ] || { echo "ERROR: $COMPOSE_FILE not found; run from repository root." >&2; exit 2; }
[ -f "supabase/fixtures/qima_security_contract.sql" ] || { echo "ERROR: security fixture SQL is missing." >&2; exit 2; }
[ -f "supabase/fixtures/qima_security_contract_tests.sql" ] || { echo "ERROR: security fixture assertions are missing." >&2; exit 2; }

cleanup() {
  original_status=$?
  trap - 0 INT TERM
  cleanup_failed=0

  if ! compose down -v --remove-orphans >/dev/null; then
    echo "ERROR: Docker Compose cleanup failed for $COMPOSE_PROJECT_NAME." >&2
    cleanup_failed=1
  fi

  remaining_containers="$(compose ps -q 2>/dev/null || printf 'CHECK_FAILED')"
  remaining_volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" 2>/dev/null || printf 'CHECK_FAILED')"
  if [ -n "$remaining_containers" ] || [ -n "$remaining_volumes" ]; then
    echo "ERROR: disposable fixture resources remain after cleanup for $COMPOSE_PROJECT_NAME." >&2
    cleanup_failed=1
  fi

  if [ "$cleanup_failed" -ne 0 ] && [ "$original_status" -eq 0 ]; then
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

compose up -d --wait qima-security-db

compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_security_contract.sql
compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_security_contract_tests.sql

compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_product_request_publish_rpc.sql
compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/migrations/20261127100000_harden_product_request_publish_tenant_membership.sql
compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_product_request_publish_rpc_tests.sql

sh tests/sql/test-product-request-publish-membership-contract.sh

echo "PASS: local QIMA security-contract fixture assertions completed."
echo "The isolated Compose project and its named volume will be removed and checked automatically."
