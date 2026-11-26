#!/usr/bin/env sh
set -eu

migration="supabase/migrations/20261127100000_harden_product_request_publish_tenant_membership.sql"
[ -f "$migration" ] || { echo "FAIL: tenant-membership hardening migration is missing"; exit 1; }

function_body="$(sed -n '/create or replace function public.dt_publish_product_request/,/^\$\$;/p' "$migration")"
[ -n "$function_body" ] || { echo "FAIL: publish RPC definition was not found"; exit 1; }

printf '%s\n' "$function_body" | grep -Fq "from public.dt_memberships m" || {
  echo "FAIL: publish RPC does not consult dt_memberships"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "m.tenant_id = v_request.tenant_id" || {
  echo "FAIL: publish RPC membership check is not scoped to the request tenant"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "m.user_id = p_user_id" || {
  echo "FAIL: publish RPC membership check is not scoped to the authenticated user"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "for key share" || {
  echo "FAIL: publish RPC does not hold the membership row against concurrent removal"; exit 1;
}
printf '%s\n' "$function_body" | grep -Fq "if not found then raise exception 'PRODUCT_REQUEST_NOT_FOUND'; end if;" || {
  echo "FAIL: missing tenant membership does not fail closed with the non-disclosing request code"; exit 1;
}

echo "PASS: product-request publish RPC enforces current membership for the exact request tenant."
