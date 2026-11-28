#!/usr/bin/env sh
set -eu

migration="supabase/migrations/20261127100000_harden_product_request_publish_tenant_membership.sql"
[ -f "$migration" ] || { echo "FAIL: tenant-membership hardening migration is missing"; exit 1; }

function_body="$(sed -n '/create or replace function public.dt_publish_product_request/,/^\$\$;/p' "$migration")"
[ -n "$function_body" ] || { echo "FAIL: publish RPC definition was not found"; exit 1; }

printf '%s\n' "$function_body" | grep -Eiq '^[[:space:]]*security definer[[:space:]]*$' || {
  echo "FAIL: publish RPC must remain SECURITY DEFINER"; exit 1;
}
printf '%s\n' "$function_body" | grep -Eiq '^[[:space:]]*set search_path = public[[:space:]]*$' || {
  echo "FAIL: SECURITY DEFINER publish RPC must pin search_path to public"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "auth.uid()" || {
  echo "FAIL: publish RPC must use the schema-qualified auth.uid() helper"; exit 1;
}

printf '%s\\n' "$function_body" | grep -Eiq 'auth\\.uid\\(\\)[[:space:]]+is[[:space:]]+null' || {
  echo "FAIL: publish RPC must reject a null authenticated subject"; exit 1;
}

printf '%s\n' "$function_body" | grep -Eiq 'auth\.uid\(\)[[:space:]]*<>[[:space:]]*p_user_id' || {
  echo "FAIL: publish RPC must bind p_user_id to the authenticated subject"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "from public.dt_memberships m" || {
  echo "FAIL: publish RPC does not consult dt_memberships"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "m.tenant_id = pr.tenant_id" || {
  echo "FAIL: publish RPC membership check is not scoped to the request tenant"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "m.user_id = p_user_id" || {
  echo "FAIL: publish RPC membership check is not scoped to the authenticated user"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "and pr.user_id = p_user_id" || {
  echo "FAIL: publish RPC does not require the request owner to match p_user_id"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "for key share" || {
  echo "FAIL: publish RPC does not hold the membership row against concurrent removal"; exit 1;
}
printf '%s\n' "$function_body" | awk '
  /for key share/ {
    if (getline > 0 && $0 ~ /if not found then raise exception .PRODUCT_REQUEST_NOT_FOUND./) found = 1
  }
  END { exit !found }
' || {
  echo "FAIL: missing locked tenant membership does not fail closed"; exit 1;
}

grep -Fq "revoke all on function public.dt_publish_product_request(uuid, uuid) from public" "$migration" || {
  echo "FAIL: public execute privilege is not revoked"; exit 1;
}
grep -Fq "revoke all on function public.dt_publish_product_request(uuid, uuid) from anon" "$migration" || {
  echo "FAIL: explicit anon EXECUTE privilege is not revoked"; exit 1;
}
grep -Fq "grant execute on function public.dt_publish_product_request(uuid, uuid) to authenticated" "$migration" || {
  echo "FAIL: authenticated execute grant is missing"; exit 1;
}

echo "PASS: product-request publish RPC pins its SECURITY DEFINER context and enforces current membership for the exact request tenant."
