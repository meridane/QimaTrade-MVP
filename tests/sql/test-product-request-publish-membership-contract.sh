#!/usr/bin/env sh
set -eu

migration="supabase/migrations/20261127100000_harden_product_request_publish_tenant_membership.sql"
[ -f "$migration" ] || { echo "FAIL: tenant-membership hardening migration is missing"; exit 1; }

membership_migration="supabase/migrations/20260829090000_create_decision_tree_v1.sql"
request_migration="supabase/migrations/20260829100000_product_requests_v1.sql"
access_migration="supabase/migrations/20260829102000_grant_authenticated_v1_decision_tree_access.sql"
for source in "$membership_migration" "$request_migration" "$access_migration"; do
  [ -f "$source" ] || { echo "FAIL: source RLS migration $source is missing"; exit 1; }
done

grep -Fq "alter table public.dt_memberships enable row level security" "$membership_migration" || {
  echo "FAIL: dt_memberships RLS is not enabled in the source migration"; exit 1;
}
grep -Fq "create policy dt_memberships_select on public.dt_memberships for select to authenticated" "$membership_migration" || {
  echo "FAIL: authenticated dt_memberships self-read policy is missing"; exit 1;
}
grep -Fq "using (user_id = auth.uid())" "$membership_migration" || {
  echo "FAIL: dt_memberships source policy is not restricted to auth.uid()"; exit 1;
}
grep -Fq "alter table public.product_requests enable row level security" "$request_migration" || {
  echo "FAIL: product_requests RLS is not enabled in the source migration"; exit 1;
}
grep -Fq 'create policy "product_requests_select_own_tenant" on public.product_requests' "$request_migration" || {
  echo "FAIL: product_requests tenant SELECT policy is missing"; exit 1;
}
grep -Fq "m.tenant_id = product_requests.tenant_id" "$request_migration" || {
  echo "FAIL: product_requests SELECT policy is not scoped to the request tenant"; exit 1;
}
grep -Fq "m.user_id = auth.uid()" "$request_migration" || {
  echo "FAIL: product_requests SELECT policy is not scoped to the authenticated user"; exit 1;
}
grep -Fq "grant select on public.dt_tenants, public.dt_memberships" "$access_migration" || {
  echo "FAIL: authenticated source SELECT grants for tenant membership are missing"; exit 1;
}
grep -Fq "public.product_requests to authenticated" "$access_migration" || {
  echo "FAIL: authenticated source SELECT grant for product_requests is missing"; exit 1;
}

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

printf '%s\n' "$function_body" | grep -Eiq 'auth\.uid\(\)[[:space:]]+is[[:space:]]+null' || {
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
