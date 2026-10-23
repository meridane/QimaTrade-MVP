#!/usr/bin/env sh
set -eu

# Disposable local test database only. This script does not connect to Supabase cloud.
COMPOSE_FILE="docker-compose.qima-security.yml"
command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required."; exit 2; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: Docker Compose plugin is required."; exit 2; }
[ -f "$COMPOSE_FILE" ] || { echo "ERROR: $COMPOSE_FILE not found; run from repository root."; exit 2; }

cleanup() {
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker compose -f "$COMPOSE_FILE" up -d --wait qima-security-db

docker compose -f "$COMPOSE_FILE" exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_security_contract.sql
docker compose -f "$COMPOSE_FILE" exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_security_contract_tests.sql

echo "PASS: local QIMA security-contract fixture assertions completed."
echo "The disposable database volume will be removed automatically."
