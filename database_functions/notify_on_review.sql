-- ============================================================================
-- Function: notify_on_review
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================
-- Notifies users when someone reviews a place they have:
-- 1. In their favorites
-- 2. In any of their place lists
-- Avoids duplicate notifications if a user has the place in both favorites and lists
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_review()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    -- Notify users who have this place in their favorites
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, actor_first_name, actor_last_name, 
        actor_profile_photo_url, place_id, place_name, review_id, "timestamp", is_read
    )
    SELECT 
        gen_random_uuid(),
        f.user_id,
        'review',
        NEW.user_id,
        NEW.user_first_name,
        NEW.user_last_name,
        NEW.profile_photo_url,
        NEW.place_id,
        NEW.place_name,
        NEW.id,
        NEW."timestamp",
        false
    FROM favorites f
    WHERE f.place_id = NEW.place_id
    AND f.user_id != NEW.user_id;
    
    -- Notify users who have this place in any of their lists
    -- Use DISTINCT ON to avoid duplicates if a user has the place in multiple lists
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, actor_first_name, actor_last_name, 
        actor_profile_photo_url, place_id, place_name, review_id, "timestamp", is_read
    )
    SELECT DISTINCT ON (pl.user_id)
        gen_random_uuid(),
        pl.user_id,
        'review',
        NEW.user_id,
        NEW.user_first_name,
        NEW.user_last_name,
        NEW.profile_photo_url,
        NEW.place_id,
        NEW.place_name,
        NEW.id,
        NEW."timestamp",
        false
    FROM place_list_items pli
    INNER JOIN place_lists pl ON pli.list_id = pl.id
    WHERE pli.place_id = NEW.place_id
    AND pl.user_id != NEW.user_id
    -- Avoid duplicate notifications if user also has it in favorites
    AND NOT EXISTS (
        SELECT 1 FROM favorites f 
        WHERE f.user_id = pl.user_id 
        AND f.place_id = NEW.place_id
    );
    
    RETURN NEW;
END;
$function$
