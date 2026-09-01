CREATE OR REPLACE FUNCTION public.get_action_definition_v1(p_action_key text, p_version integer)
RETURNS TABLE(action_key text, version integer, status text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ad.action_key, ad.version, ad.status
  FROM public.action_definitions ad
  WHERE ad.action_key = p_action_key
    AND ad.version = p_version
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_action_definition_v1(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_action_definition_v1(text, integer) TO authenticated;
