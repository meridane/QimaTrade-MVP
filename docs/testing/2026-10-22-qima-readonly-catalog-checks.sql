-- QIMA read-only catalog diagnostics.
-- Safe to review; intended for a LOCAL database or read-only SQL session.
-- This script performs SELECTs only. It does not alter schema or data.
-- Do NOT use it as proof of runtime tenant isolation.

-- 1) RLS status and forced-RLS flag for important tables.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and (
    c.relname like 'dt_%'
    or c.relname = 'product_requests'
    or c.relname in ('attribute_options', 'attribute_units')
  )
order by c.relname;

-- 2) Policies and their commands/conditions.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and (
    tablename like 'dt_%'
    or tablename = 'product_requests'
    or tablename in ('attribute_options', 'attribute_units')
  )
order by tablename, policyname;

-- 3) Effective table grants visible to the current database role catalog.
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'dt_sessions',
    'dt_observations',
    'dt_transitions',
    'product_requests',
    'attribute_options',
    'attribute_units'
  )
  and grantee in ('anon', 'authenticated', 'service_role')
order by table_name, grantee, privilege_type;

-- 4) SECURITY DEFINER functions: definition metadata and configured search_path.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_userbyid(p.proowner) as owner_name,
  p.prosecdef as security_definer,
  p.proconfig as function_settings,
  pg_get_function_identity_arguments(p.oid) as identity_arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and (
    p.proname like 'dt_%'
    or p.proname like '%action%'
    or p.proname in ('current_actor_id', 'current_profile_actor_id', 'get_action_definition_v1')
  )
order by p.proname, identity_arguments;

-- 5) Execution grants for sensitive functions.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  grantee.rolname as grantee,
  has_function_privilege(grantee.oid, p.oid, 'EXECUTE') as can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join pg_roles grantee
where n.nspname = 'public'
  and p.prosecdef
  and grantee.rolname in ('anon', 'authenticated', 'service_role')
  and (
    p.proname like 'dt_%'
    or p.proname like '%action%'
    or p.proname in ('current_actor_id', 'current_profile_actor_id', 'get_action_definition_v1')
  )
order by p.proname, identity_arguments, grantee.rolname;
