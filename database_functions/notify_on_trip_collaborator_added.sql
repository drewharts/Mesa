-- ============================================================================
-- Function: notify_on_trip_collaborator_added
-- ============================================================================
-- This function creates a notification when a user is added as a collaborator
-- to a trip.
--
-- Who gets notified:
-- - The added collaborator (if they weren't added by themselves)
-- - No self-notification (person who added themselves doesn't get notified)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_trip_collaborator_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    actor RECORD;
    trip_info RECORD;
BEGIN
    -- Skip self-notification
    IF NEW.user_id = NEW.added_by THEN
        RETURN NEW;
    END IF;

    -- Fetch actor (person who added the collaborator)
    -- Handle both Firebase IDs and Supabase Auth IDs
    SELECT first_name, last_name, profile_photo_url
    INTO actor
    FROM users
    WHERE id = NEW.added_by
       OR supabase_uid = NEW.added_by;

    -- If no actor found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No user found for added_by: %', NEW.added_by;
        RETURN NEW;
    END IF;

    -- Fetch trip details
    SELECT id, name INTO trip_info FROM trips WHERE id = NEW.trip_id;

    -- If no trip found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No trip found for trip_id: %', NEW.trip_id;
        RETURN NEW;
    END IF;

    -- Notify the added collaborator
    INSERT INTO user_notifications (
        id, user_id, type,
        actor_id, actor_first_name, actor_last_name, actor_profile_photo_url,
        trip_id, trip_name,
        is_read, timestamp
    ) VALUES (
        gen_random_uuid(),
        NEW.user_id,
        'trip_collaborator_added',
        NEW.added_by,
        actor.first_name,
        actor.last_name,
        actor.profile_photo_url,
        NEW.trip_id,
        trip_info.name,
        false,
        NOW()
    );

    RAISE NOTICE '📬 Notified collaborator: % for trip: %',
        NEW.user_id, trip_info.name;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- Create Trigger
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_notify_on_trip_collaborator_added ON trip_collaborators;

CREATE TRIGGER trigger_notify_on_trip_collaborator_added
    AFTER INSERT ON trip_collaborators
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_trip_collaborator_added();

-- Verify trigger was created
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger created: trigger_notify_on_trip_collaborator_added';
    RAISE NOTICE 'Fires AFTER INSERT on trip_collaborators';
    RAISE NOTICE 'Notifies added collaborator when they are added to a trip';
END $$;
