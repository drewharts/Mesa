-- ============================================================================
-- Function: notify_on_trip_updated
-- ============================================================================
-- This function creates notifications when a trip's name, start_date, or
-- end_date is changed.
--
-- Who gets notified:
-- - All collaborators (excluding the trip owner who made the change)
-- - Only fires when name, start_date, or end_date actually changed
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_trip_updated()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    recipient RECORD;
    actor RECORD;
BEGIN
    -- Only trigger when name, start_date, or end_date actually changed
    IF OLD.name IS NOT DISTINCT FROM NEW.name
       AND OLD.start_date IS NOT DISTINCT FROM NEW.start_date
       AND OLD.end_date IS NOT DISTINCT FROM NEW.end_date THEN
        RETURN NEW;
    END IF;

    -- Fetch actor (trip owner who made the update)
    -- Handle both Firebase IDs and Supabase Auth IDs
    SELECT first_name, last_name, profile_photo_url
    INTO actor
    FROM users
    WHERE id = NEW.owner_id
       OR supabase_uid = NEW.owner_id;

    -- If no actor found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No user found for owner_id: %', NEW.owner_id;
        RETURN NEW;
    END IF;

    -- Notify all collaborators (excluding the trip owner)
    FOR recipient IN
        SELECT tc.user_id
        FROM trip_collaborators tc
        WHERE tc.trip_id = NEW.id
          AND tc.user_id != NEW.owner_id
    LOOP
        INSERT INTO user_notifications (
            id, user_id, type,
            actor_id, actor_first_name, actor_last_name, actor_profile_photo_url,
            trip_id, trip_name,
            is_read, timestamp
        ) VALUES (
            gen_random_uuid(),
            recipient.user_id,
            'trip_updated',
            NEW.owner_id,
            actor.first_name,
            actor.last_name,
            actor.profile_photo_url,
            NEW.id,
            NEW.name,
            false,
            NOW()
        );

        RAISE NOTICE '📬 Notified collaborator: % for trip update: %',
            recipient.user_id, NEW.name;
    END LOOP;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- Create Trigger
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_notify_on_trip_updated ON trips;

CREATE TRIGGER trigger_notify_on_trip_updated
    AFTER UPDATE ON trips
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_trip_updated();

-- Verify trigger was created
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger created: trigger_notify_on_trip_updated';
    RAISE NOTICE 'Fires AFTER UPDATE on trips';
    RAISE NOTICE 'Notifies collaborators when trip name or dates change';
END $$;
