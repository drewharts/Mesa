-- ============================================================================
-- Function: notify_on_place_added_to_list
-- ============================================================================
-- This function creates notifications when a place is added to a list that
-- has collaborators or when someone adds a place to someone else's list.
--
-- Who gets notified:
-- - List owner (if they didn't add the place)
-- - All collaborators (except the person who added the place)
-- - No self-notification (person who added doesn't get notified)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_on_place_added_to_list()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    recipient RECORD;
    actor RECORD;
    place RECORD;
    list_info RECORD;
BEGIN
    -- Fetch actor (person who added the place)
    -- Handle both Firebase IDs and Supabase Auth IDs
    SELECT first_name, last_name, profile_photo_url
    INTO actor
    FROM users
    WHERE id = NEW.added_by
       OR supabase_uid = NEW.added_by;

    -- If no actor found, skip notification (shouldn't happen but be safe)
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

    -- Fetch list details and owner
    SELECT name, user_id INTO list_info FROM place_lists WHERE id = NEW.list_id;

    -- If no list found, skip notification
    IF NOT FOUND THEN
        RAISE NOTICE '⚠️ No list found for list_id: %', NEW.list_id;
        RETURN NEW;
    END IF;

    -- Notify list owner (if they didn't add the place)
    IF list_info.user_id != NEW.added_by THEN
        INSERT INTO user_notifications (
            id, user_id, type,
            actor_id, actor_first_name, actor_last_name, actor_profile_photo_url,
            place_id, place_name,
            list_id, list_name,
            is_read, timestamp
        ) VALUES (
            gen_random_uuid(),
            list_info.user_id,
            'place_added_to_list',
            NEW.added_by,
            actor.first_name,
            actor.last_name,
            actor.profile_photo_url,
            NEW.place_id,
            place.name,
            NEW.list_id,
            list_info.name,
            false,
            NOW()
        );

        RAISE NOTICE '📬 Notified list owner: % for place: % in list: %',
            list_info.user_id, place.name, list_info.name;
    END IF;

    -- Notify all collaborators (exclude the adder and list owner to avoid duplicates)
    FOR recipient IN
        SELECT plc.user_id
        FROM place_list_collaborators plc
        WHERE plc.list_id = NEW.list_id
          AND plc.user_id != NEW.added_by
          AND plc.user_id != list_info.user_id
    LOOP
        INSERT INTO user_notifications (
            id, user_id, type,
            actor_id, actor_first_name, actor_last_name, actor_profile_photo_url,
            place_id, place_name,
            list_id, list_name,
            is_read, timestamp
        ) VALUES (
            gen_random_uuid(),
            recipient.user_id,
            'place_added_to_list',
            NEW.added_by,
            actor.first_name,
            actor.last_name,
            actor.profile_photo_url,
            NEW.place_id,
            place.name,
            NEW.list_id,
            list_info.name,
            false,
            NOW()
        );

        RAISE NOTICE '📬 Notified collaborator: % for place: % in list: %',
            recipient.user_id, place.name, list_info.name;
    END LOOP;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- Create Trigger
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_notify_on_place_added_to_list ON place_list_items;

CREATE TRIGGER trigger_notify_on_place_added_to_list
    AFTER INSERT ON place_list_items
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_place_added_to_list();

-- Verify trigger was created
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger created: trigger_notify_on_place_added_to_list';
    RAISE NOTICE 'Fires AFTER INSERT on place_list_items';
    RAISE NOTICE 'Notifies list owner and collaborators when place is added';
END $$;
