#!/usr/bin/env bash
set -euo pipefail

if [[ "${RESTORE_REQUIRED-}" != "true" ]]; then
  echo "Prepared-transaction configuration was not changed; restoration is not required."
  exit 0
fi

DATABASE_URL="${DATABASE_URL-}"
BASELINE="${BASELINE_MAX_PREPARED_TRANSACTIONS-}"

# This script restarts PostgreSQL and must fail closed outside the dedicated CI database.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing PostgreSQL configuration restoration: DATABASE_URL must target qima_test on loopback port 5432." >&2
  exit 2
fi

if [[ "$BASELINE" != "0" ]]; then
  echo "::error::Expected the captured disposable-service baseline to be 0; refusing an unverified restoration target." >&2
  exit 2
fi

REAL_PSQL="$(type -P psql || true)"
if [[ -z "$REAL_PSQL" ]] || ! command -v docker >/dev/null 2>&1 || ! command -v pg_isready >/dev/null 2>&1; then
  echo "::error::psql, docker, and pg_isready are required to restore the disposable PostgreSQL service." >&2
  exit 127
fi

mapfile -t postgres_containers < <(docker ps --filter 'ancestor=postgres:16' --format '{{.ID}}')
if [[ "${#postgres_containers[@]}" -ne 1 ]]; then
  echo "::error::Expected exactly one PostgreSQL 16 service container during restoration; found ${#postgres_containers[@]}." >&2
  exit 1
fi
container_id="${postgres_containers[0]}"

# Wait for the disposable service before issuing ALTER SYSTEM RESET. This also
# covers the always() path when the preceding setup step failed during a restart.
service_ready=false
for attempt in {1..60}; do
  if pg_isready -h 127.0.0.1 -p 5432 -U postgres -d qima_test >/dev/null 2>&1; then
    service_ready=true
    break
  fi
  sleep 1
done
if [[ "$service_ready" != true ]]; then
  echo "::error::The disposable PostgreSQL service did not become ready before configuration restoration." >&2
  exit 1
fi

# RESET removes only the ALTER SYSTEM override created by the preceding CI setup step.
# Report each failure explicitly and preserve the command's exit status; never
# continue to the verification loop or claim restoration after a failed step.
if docker exec "$container_id" psql -U postgres -d qima_test -v ON_ERROR_STOP=1 \
  -c "ALTER SYSTEM RESET max_prepared_transactions"; then
  :
else
  reset_status=$?
  echo "::error::ALTER SYSTEM RESET max_prepared_transactions failed (docker exec exit $reset_status); configuration restoration is not confirmed." >&2
  exit "$reset_status"
fi

if docker restart "$container_id" >/dev/null; then
  :
else
  restart_status=$?
  echo "::error::PostgreSQL service restart failed (docker restart exit $restart_status); configuration restoration is not confirmed." >&2
  exit "$restart_status"
fi

restored=false
for attempt in {1..60}; do
  if pg_isready -h 127.0.0.1 -p 5432 -U postgres -d qima_test >/dev/null 2>&1; then
    configured="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc "SHOW max_prepared_transactions")"
    if [[ "$configured" == "$BASELINE" ]]; then
      restored=true
      break
    fi
  fi
  sleep 1
done

if [[ "$restored" != true ]]; then
  echo "::error::PostgreSQL did not return to max_prepared_transactions=$BASELINE after ALTER SYSTEM RESET and restart." >&2
  exit 1
fi

prepared_count="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
  "SELECT count(*) FROM pg_prepared_xacts WHERE gid = 'qa266_prepared_cleanup_blocker'")"
database_count="$("$REAL_PSQL" "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -Atqc \
  "SELECT count(*) FROM pg_database WHERE datname = 'qima_message_migration_test'")"

if [[ "$prepared_count" != "0" || "$database_count" != "0" ]]; then
  echo "::error::PostgreSQL configuration was restored, but disposable QA266 resources remain (prepared=$prepared_count database=$database_count)." >&2
  exit 1
fi

echo "QA267 passed: ALTER SYSTEM RESET was followed by a PostgreSQL restart; max_prepared_transactions returned to baseline 0, and no QA266 prepared transaction or disposable database remained."
