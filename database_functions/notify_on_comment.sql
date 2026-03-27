-- ============================================================================
-- Function: notify_on_comment
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_comment()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Notify the review author (existing behavior)
    INSERT INTO user_notifications (
        id, user_id, type, actor_id, actor_first_name, actor_last_name,
        actor_profile_photo_url, place_id, review_id, comment_id, "timestamp", is_read
    )
    SELECT
        gen_random_uuid(),
        r.user_id,
        'comment',
        NEW.user_id,
        u.first_name,
        u.last_name,
        u.profile_photo_url,
        NEW.place_id,
        NEW.review_id,
        NEW.id,
        NEW."timestamp",
        false
    FROM reviews r
    CROSS JOIN users u
    WHERE r.id = NEW.review_id
    AND r.user_id != NEW.user_id
    AND (u.id = NEW.user_id OR u.supabase_uid = NEW.user_id);

    -- Notify the parent comment author when this is a reply
    -- Skip if replying to own comment or if parent author is the review author (already notified above)
    IF NEW.parent_comment_id IS NOT NULL THEN
        INSERT INTO user_notifications (
            id, user_id, type, actor_id, actor_first_name, actor_last_name,
            actor_profile_photo_url, place_id, review_id, comment_id, "timestamp", is_read
        )
        SELECT
            gen_random_uuid(),
            c.user_id,
            'comment_reply',
            NEW.user_id,
            u.first_name,
            u.last_name,
            u.profile_photo_url,
            NEW.place_id,
            NEW.review_id,
            NEW.id,
            NEW."timestamp",
            false
        FROM comments c
        CROSS JOIN users u
        WHERE c.id = NEW.parent_comment_id
        AND c.user_id != NEW.user_id
        AND c.user_id != (SELECT r.user_id FROM reviews r WHERE r.id = NEW.review_id)
        AND (u.id = NEW.user_id OR u.supabase_uid = NEW.user_id);
    END IF;

    RETURN NEW;
END;
$function$
