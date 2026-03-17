-- ============================================================================
-- Function: notify_on_place_added_to_trip
-- ============================================================================
-- This function creates notifications when a place is added to a trip day.
--
-- Who gets notified:
-- - Trip owner (if they didn't add the place)
-- - All collaborators (except the person who added the place and the owner
--   to avoid duplicates)
-- - No self-notification (person who added doesn't get notified)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_place_added_to_trip()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    recipient RECORD;
    actor RECORD;
    place RECORD;
    trip_info RECORD;
    trip_day_info RECORD;
BEGIN
    -- Fetch the trip_day to get the trip_id
    SELECT trip_id INTO trip_day_info FROM trip_days WHERE id = NEW.trip_day_id;

    -- If no trip day found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No trip_day found for trip_day_id: %', NEW.trip_day_id;
        RETURN NEW;
    END IF;

    -- Fetch actor (person who added the place)
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

    -- Fetch place details
    SELECT name INTO place FROM places WHERE id = NEW.place_id;

    -- If no place found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No place found for place_id: %', NEW.place_id;
        RETURN NEW;
    END IF;

    -- Fetch trip details and owner
    SELECT id, name, owner_id INTO trip_info FROM trips WHERE id = trip_day_info.trip_id;

    -- If no trip found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No trip found for trip_id: %', trip_day_info.trip_id;
        RETURN NEW;
    END IF;

    -- Notify trip owner (if they didn't add the place)
    IF trip_info.owner_id != NEW.added_by THEN
        INSERT INTO user_notifications (
            id, user_id, type,
            actor_id, actor_first_name, actor_last_name, actor_profile_photo_url,
            place_id, place_name,
            trip_id, trip_name,
            is_read, timestamp
        ) VALUES (
            gen_random_uuid(),
            trip_info.owner_id,
            'place_added_to_trip',
            NEW.added_by,
            actor.first_name,
            actor.last_name,
            actor.profile_photo_url,
            NEW.place_id,
            place.name,
            trip_info.id,
            trip_info.name,
            false,
            NOW()
        );

        RAISE NOTICE '📬 Notified trip owner: % for place: % in trip: %',
            trip_info.owner_id, place.name, trip_info.name;
    END IF;

    -- Notify all collaborators (exclude the adder and trip owner to avoid duplicates)
    FOR recipient IN
        SELECT tc.user_id
        FROM trip_collaborators tc
        WHERE tc.trip_id = trip_info.id
          AND tc.user_id != NEW.added_by
          AND tc.user_id != trip_info.owner_id
    LOOP
        INSERT INTO user_notifications (
            id, user_id, type,
            actor_id, actor_first_name, actor_last_name, actor_profile_photo_url,
            place_id, place_name,
            trip_id, trip_name,
            is_read, timestamp
        ) VALUES (
            gen_random_uuid(),
            recipient.user_id,
            'place_added_to_trip',
            NEW.added_by,
            actor.first_name,
            actor.last_name,
            actor.profile_photo_url,
            NEW.place_id,
            place.name,
            trip_info.id,
            trip_info.name,
            false,
            NOW()
        );

        RAISE NOTICE '📬 Notified collaborator: % for place: % in trip: %',
            recipient.user_id, place.name, trip_info.name;
    END LOOP;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- Create Trigger
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_notify_on_place_added_to_trip ON trip_day_places;

CREATE TRIGGER trigger_notify_on_place_added_to_trip
    AFTER INSERT ON trip_day_places
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_place_added_to_trip();

-- Verify trigger was created
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger created: trigger_notify_on_place_added_to_trip';
    RAISE NOTICE 'Fires AFTER INSERT on trip_day_places';
    RAISE NOTICE 'Notifies trip owner and collaborators when place is added to a trip day';
END $$;
