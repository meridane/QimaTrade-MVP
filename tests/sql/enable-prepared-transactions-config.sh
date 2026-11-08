#!/usr/bin/env bash
set -euo pipefail

DATABASE_URL="${DATABASE_URL-}"
GITHUB_OUTPUT="${GITHUB_OUTPUT-}"

# This mutates and restarts PostgreSQL; fail closed outside the dedicated CI database.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing prepared-transaction setup: DATABASE_URL must target qima_test on loopback port 5432." >&2
  exit 2
fi

if [[ -z "$GITHUB_OUTPUT" || ! -f "$GITHUB_OUTPUT" ]]; then
  echo "::error::GITHUB_OUTPUT must name the active GitHub Actions step-output file." >&2
  exit 2
fi

REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]] || ! command -v docker >/dev/null 2>&1 || ! command -v pg_isready >/dev/null 2>&1; then
  echo "::error::psql, docker, and pg_isready are required for disposable PostgreSQL setup." >&2
  exit 127
fi

mapfile -t postgres_containers < <(docker ps --filter 'ancestor=postgres:16' --format '{{.ID}}')
if [[ "${#postgres_containers[@]}" -ne 1 ]]; then
  echo "::error::Expected exactly one PostgreSQL 16 service container; found ${#postgres_containers[@]}." >&2
  exit 1
fi
container_id="${postgres_containers[0]}"

if baseline="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc "SHOW max_prepared_transactions")"; then
  :
else
  baseline_status=$?
  echo "::error::Could not capture the disposable PostgreSQL baseline (psql exit $baseline_status); no configuration change was attempted." >&2
  exit "$baseline_status"
fi

if [[ "$baseline" != "0" ]]; then
  echo "::error::Expected the pristine disposable PostgreSQL baseline to be 0; found $baseline. No configuration change was attempted." >&2
  exit 1
fi

# Publish the restoration intent BEFORE the first mutating command. The workflow's
# if: always() cleanup step can therefore restore even after a partial setup failure.
if ! printf 'baseline=%s\nrestore_required=true\n' "$baseline" >> "$GITHUB_OUTPUT"; then
  echo "::error::Could not persist PostgreSQL restoration intent; no configuration change was attempted." >&2
  exit 1
fi

if docker exec "$container_id" psql -U postgres -d qima_test -v ON_ERROR_STOP=1 \
  -c "ALTER SYSTEM SET max_prepared_transactions = '10'"; then
  :
else
  set_status=$?
  echo "::error::ALTER SYSTEM SET max_prepared_transactions failed (docker exec exit $set_status); restoration remains required." >&2
  exit "$set_status"
fi

if docker restart "$container_id" >/dev/null; then
  :
else
  restart_status=$?
  echo "::error::PostgreSQL setup restart failed (docker restart exit $restart_status); restoration remains required." >&2
  exit "$restart_status"
fi

for attempt in {1..60}; do
  if pg_isready -h 127.0.0.1 -p 5432 -U postgres -d qima_test >/dev/null 2>&1; then
    if configured="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc "SHOW max_prepared_transactions")"; then
      :
    else
      show_status=$?
      echo "::error::Could not verify prepared-transaction setup (psql exit $show_status); restoration remains required." >&2
      exit "$show_status"
    fi
    if [[ "$configured" == "10" ]]; then
      echo "Disposable PostgreSQL service restarted with max_prepared_transactions=10 (captured baseline=$baseline)."
      exit 0
    fi
  fi
  sleep 1
done

echo "::error::PostgreSQL did not become ready with max_prepared_transactions=10; restoration remains required." >&2
exit 1
