-- ============================================================================
-- FUNCTION: add_list_collaborator
-- Purpose: Add a collaborator to a list with proper authorization
-- Uses SECURITY DEFINER to bypass RLS and handle auth internally
-- ============================================================================

CREATE OR REPLACE FUNCTION add_list_collaborator(
    p_list_id TEXT,
    p_user_id TEXT,
    p_role TEXT DEFAULT 'editor',
    p_added_by TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_owner_id TEXT;
    v_caller_id TEXT;
    v_added_by TEXT;
    v_new_id TEXT;
BEGIN
    -- Get the authenticated user
    v_caller_id := auth.uid()::TEXT;
    
    IF v_caller_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Not authenticated'
        );
    END IF;
    
    -- Get the list owner
    SELECT user_id INTO v_owner_id
    FROM place_lists
    WHERE id = p_list_id;
    
    IF v_owner_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'List not found'
        );
    END IF;
    
    -- Check authorization: caller must be the list owner
    -- Compare case-insensitively to handle UUID case differences
    IF LOWER(v_owner_id) != LOWER(v_caller_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Not authorized - only the list owner can add collaborators'
        );
    END IF;
    
    -- Can't add yourself as collaborator
    IF LOWER(p_user_id) = LOWER(v_caller_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Cannot add yourself as a collaborator'
        );
    END IF;
    
    -- Can't add the owner as collaborator
    IF LOWER(p_user_id) = LOWER(v_owner_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Cannot add the list owner as a collaborator'
        );
    END IF;
    
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE LOWER(id) = LOWER(p_user_id)) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;
    
    -- Check if already a collaborator
    IF EXISTS (
        SELECT 1 FROM place_list_collaborators 
        WHERE LOWER(list_id) = LOWER(p_list_id) 
        AND LOWER(user_id) = LOWER(p_user_id)
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User is already a collaborator on this list'
        );
    END IF;
    
    -- Use provided added_by or default to caller
    v_added_by := COALESCE(p_added_by, v_caller_id);
    
    -- Generate new ID
    v_new_id := uuid_generate_v4()::TEXT;
    
    -- Insert the collaborator
    INSERT INTO place_list_collaborators (id, list_id, user_id, role, added_by, added_at)
    VALUES (v_new_id, p_list_id, p_user_id, p_role, v_added_by, NOW());
    
    RETURN json_build_object(
        'success', true,
        'collaborator_id', v_new_id
    );
    
EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User is already a collaborator on this list'
        );
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION add_list_collaborator(TEXT, TEXT, TEXT, TEXT) TO authenticated;

