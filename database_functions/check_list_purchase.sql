-- ============================================================================
-- Function: check_list_purchase
-- ============================================================================
-- Returns true if the user owns the list OR has purchased it.
-- Used to gate access to paid list content.
-- ============================================================================

CREATE OR REPLACE FUNCTION check_list_purchase(
    p_user_id TEXT,
    p_list_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    has_access BOOLEAN;
BEGIN
    SELECT EXISTS(
        -- User is the list owner
        SELECT 1 FROM place_lists
        WHERE id = p_list_id::UUID AND user_id = p_user_id
        UNION ALL
        -- User is a collaborator
        SELECT 1 FROM place_list_collaborators
        WHERE list_id = p_list_id::UUID AND user_id = p_user_id
        UNION ALL
        -- User has purchased the list
        SELECT 1 FROM list_purchases
        WHERE list_id = p_list_id::UUID AND user_id = p_user_id
    ) INTO has_access;

    RETURN has_access;
END;
$function$;

GRANT EXECUTE ON FUNCTION check_list_purchase(TEXT, TEXT) TO authenticated;
