#!/usr/bin/env sh
set -eu

# Concurrency regression for the SECURITY DEFINER publish RPC.
# Runs only against the disposable qima-security-db container.
: "${QIMA_SECURITY_COMPOSE_PROJECT_NAME:?disposable Compose project is required}"
COMPOSE_FILE="${QIMA_SECURITY_COMPOSE_FILE:-docker-compose.qima-security.yml}"

compose() {
  docker compose --project-name "$QIMA_SECURITY_COMPOSE_PROJECT_NAME" --file "$COMPOSE_FILE" "$@"
}

user_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
request_id="55555555-5555-4555-8555-555555555555"
tenant_id="11111111-1111-4111-8111-111111111111"
holder_log="$(mktemp)"
delete_log="$(mktemp)"
holder_pid=""

cleanup() {
  if [ -n "$holder_pid" ] && kill -0 "$holder_pid" 2>/dev/null; then
    kill "$holder_pid" 2>/dev/null || true
    wait "$holder_pid" 2>/dev/null || true
  fi
  rm -f "$holder_log" "$delete_log"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

# The RPC takes FOR KEY SHARE on the exact membership row. Keep the outer
# transaction open after the RPC returns so a concurrent DELETE must wait.
compose exec -T -e PGAPPNAME=qima-membership-lock-holder qima-security-db \
  psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test \
  -c "select set_config('request.jwt.claim.sub', '$user_id', false)" \
  -c "set role authenticated" \
  -c "begin" \
  -c "select public.dt_publish_product_request('$request_id', '$user_id')" \
  -c "select pg_sleep(15)" \
  -c "commit" >"$holder_log" 2>&1 &
holder_pid=$!

# Wait until the holder is inside pg_sleep, which proves the RPC has returned
# while its transaction (and membership row lock) is still open.
active="0"
attempt=0
while [ "$attempt" -lt 40 ]; do
  active="$(compose exec -T qima-security-db psql -At -U postgres -d qima_security_test \
    -c "select count(*) from pg_stat_activity where application_name = 'qima-membership-lock-holder' and state = 'active' and query like '%pg_sleep%';" \
    | tr -d '[:space:]')"
  [ "$active" = "1" ] && break
  if ! kill -0 "$holder_pid" 2>/dev/null; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 0.2
done

if [ "$active" != "1" ]; then
  echo "FAIL: publish transaction did not reach the lock-holding phase." >&2
  cat "$holder_log" >&2
  exit 1
fi

# A privileged membership revocation must time out while the publish
# transaction holds FOR KEY SHARE. A successful DELETE would expose a race.
if compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -v VERBOSITY=verbose \
  -U postgres -d qima_security_test \
  -c "set lock_timeout = '750ms'" \
  -c "delete from public.dt_memberships where tenant_id = '$tenant_id' and user_id = '$user_id'" \
  >"$delete_log" 2>&1; then
  echo "FAIL: membership DELETE was not blocked by the publish transaction." >&2
  cat "$delete_log" >&2
  exit 1
fi

if ! grep -Fq "canceling statement due to lock timeout" "$delete_log"; then
  echo "FAIL: membership DELETE failed for a reason other than the expected lock timeout." >&2
  cat "$delete_log" >&2
  exit 1
fi

if wait "$holder_pid"; then
  holder_status=0
else
  holder_status=$?
fi
holder_pid=""
if [ "$holder_status" -ne 0 ]; then
  echo "FAIL: publish lock-holder transaction failed (status $holder_status)." >&2
  cat "$holder_log" >&2
  exit 1
fi

membership_count="$(compose exec -T qima-security-db psql -At -U postgres -d qima_security_test \
  -c "select count(*) from public.dt_memberships where tenant_id = '$tenant_id' and user_id = '$user_id';" \
  | tr -d '[:space:]')"
[ "$membership_count" = "1" ] || {
  echo "FAIL: membership row was not preserved after the blocked concurrent DELETE." >&2
  exit 1
}

demand_count="$(compose exec -T qima-security-db psql -At -U postgres -d qima_security_test \
  -c "select count(*) from public.demands;" | tr -d '[:space:]')"
[ "$demand_count" = "1" ] || {
  echo "FAIL: idempotent publish during the lock test changed the demand count." >&2
  exit 1
}

# After the publish transaction commits, revocation must become possible.
# This distinguishes a real row-lock boundary from an accidentally permanent
# fixture lock and verifies that later calls observe the revoked membership.
if ! compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test \
  -c "delete from public.dt_memberships where tenant_id = '$tenant_id' and user_id = '$user_id'" \
  >"$delete_log" 2>&1; then
  echo "FAIL: membership DELETE remained blocked after the publish transaction committed." >&2
  cat "$delete_log" >&2
  exit 1
fi

membership_count="$(compose exec -T qima-security-db psql -At -U postgres -d qima_security_test \
  -c "select count(*) from public.dt_memberships where tenant_id = '$tenant_id' and user_id = '$user_id';" \
  | tr -d '[:space:]')"
[ "$membership_count" = "0" ] || {
  echo "FAIL: membership revocation did not persist after the publish transaction committed." >&2
  exit 1
}

# A subsequent publish call after revocation must be denied before any write.
if ! compose exec -T qima-security-db psql -v ON_ERROR_STOP=1 -U postgres -d qima_security_test \
  -c "select set_config('request.jwt.claim.sub', '$user_id', false)" \
  -c "set role authenticated" \
  -c "do \$\$ begin
    begin
      perform public.dt_publish_product_request('$request_id', '$user_id');
    exception when others then
      if sqlerrm = 'PRODUCT_REQUEST_NOT_FOUND' then
        raise notice 'PASS: publish retry is rejected after membership revocation.';
        return;
      end if;
      raise;
    end;
    raise exception 'FAIL: publish unexpectedly succeeded after membership revocation.';
  end \$\$;" >"$delete_log" 2>&1; then
  echo "FAIL: post-revocation publish did not return the expected membership denial." >&2
  cat "$delete_log" >&2
  exit 1
fi

if ! grep -Fq "PASS: publish retry is rejected after membership revocation." "$delete_log"; then
  echo "FAIL: post-revocation publish did not report the expected denial assertion." >&2
  cat "$delete_log" >&2
  exit 1
fi

demand_count="$(compose exec -T qima-security-db psql -At -U postgres -d qima_security_test \
  -c "select count(*) from public.demands;" | tr -d '[:space:]')"
[ "$demand_count" = "1" ] || {
  echo "FAIL: post-revocation publish changed the persisted demand count." >&2
  exit 1
}

published_request_count="$(compose exec -T qima-security-db psql -At -U postgres -d qima_security_test \
  -c "select count(*) from public.product_requests where id = '$request_id' and status = 'published' and demand_id is not null;" \
  | tr -d '[:space:]')"
[ "$published_request_count" = "1" ] || {
  echo "FAIL: post-revocation retry changed the already-published request." >&2
  exit 1
}

echo "PASS: concurrent membership DELETE is blocked until the publish transaction releases FOR KEY SHARE."
echo "PASS: membership revocation succeeds after commit and subsequent publish is denied without another demand write."
