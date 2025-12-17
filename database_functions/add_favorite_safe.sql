-- ============================================================================
-- Function: add_favorite_safe
-- ============================================================================
-- Safely adds a favorite with server-side validation:
-- 1. Checks if user already has 6 favorites (max limit)
-- 2. Checks if place is already favorited (prevent duplicates)
-- 3. Atomically inserts if both checks pass
-- 
-- Returns:
--   'success' - Favorite added successfully
--   'max_limit' - User already has 6 favorites
--   'duplicate' - Place is already favorited
--   'error' - Database error occurred
-- ============================================================================

CREATE OR REPLACE FUNCTION public.add_favorite_safe(
    p_user_id TEXT,
    p_place_id TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
    v_exists BOOLEAN;
BEGIN
    -- Check current favorite count
    SELECT COUNT(*) INTO v_count
    FROM favorites
    WHERE user_id = p_user_id;
    
    IF v_count >= 6 THEN
        RETURN 'max_limit';
    END IF;
    
    -- Check if already favorited
    SELECT EXISTS(
        SELECT 1 FROM favorites
        WHERE user_id = p_user_id AND place_id = p_place_id
    ) INTO v_exists;
    
    IF v_exists THEN
        RETURN 'duplicate';
    END IF;
    
    -- Insert the favorite
    INSERT INTO favorites (id, user_id, place_id, timestamp)
    VALUES (
        gen_random_uuid()::text,
        p_user_id,
        p_place_id,
        NOW()
    );
    
    RETURN 'success';
    
EXCEPTION WHEN OTHERS THEN
    RETURN 'error';
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.add_favorite_safe(TEXT, TEXT) TO authenticated;

