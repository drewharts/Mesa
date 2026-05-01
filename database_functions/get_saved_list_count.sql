-- ============================================================================
-- Function: get_saved_list_count
-- ============================================================================
-- Returns the number of users who have saved a specific list.
-- Used to display save count to list creators.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_saved_list_count(p_list_id uuid)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
    SELECT COUNT(*) FROM saved_lists WHERE list_id = p_list_id;
$function$;
