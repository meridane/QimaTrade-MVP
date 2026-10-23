#!/usr/bin/env sh
set -eu

# Disposable local test database only. This script does not connect to Supabase cloud.
command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required."; exit 2; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: Docker Compose plugin is required."; exit 2; }

cleanup() {
  docker compose down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker compose up -d --wait qima-security-db

docker compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_security_contract.sql
docker compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test -f /dev/stdin < supabase/fixtures/qima_security_contract_tests.sql

echo "PASS: local QIMA security-contract fixture assertions completed."
echo "The disposable database volume will be removed automatically."
