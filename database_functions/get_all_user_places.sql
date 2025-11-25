-- ============================================================================
-- Function: get_all_user_places
-- ============================================================================
-- This file contains the current state of the function in the database.
-- NOTE: This function has 2 overloaded versions.
-- ============================================================================

-- Overload 1 of 2
CREATE OR REPLACE FUNCTION public.get_all_user_places(p_user_id text)
 RETURNS TABLE(id text, name text, address text, city text, latitude double precision, longitude double precision, mapbox_id text, google_place_id text, phone text, rating double precision, user_ratings_total integer, categories text[], photo_urls text[], open_hours jsonb, price_level text, description_text text, reservable boolean, serves_breakfast boolean, serves_lunch boolean, serves_dinner boolean, instagram text, x text, source text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (p.id::text)
        p.id::text,
        p.name,
        p.address,
        p.city,
        ST_Y(p.location::geometry) AS latitude,
        ST_X(p.location::geometry) AS longitude,
        p.mapbox_id,
        p.google_place_id,
        p.phone,
        p.rating,
        p.user_ratings_total,
        p.categories,
        p.photo_urls,
        p.open_hours,
        p.price_level,
        p.description_text,
        p.reservable,
        p.serves_breakfast,
        p.serves_lunch,
        p.serves_dinner,
        p.instagram,
        p.x,
        p.source,
        p.created_at,
        p.updated_at
    FROM places p
    WHERE p.id::text IN (
        -- From my_places
        SELECT place_id FROM my_places WHERE user_id = p_user_id
        UNION
        -- From favorites
        SELECT place_id FROM favorites WHERE user_id = p_user_id
        UNION
        -- From place_list_items (via user's lists)
        SELECT pli.place_id 
        FROM place_list_items pli
        JOIN place_lists pl ON pli.list_id = pl.id
        WHERE pl.user_id = p_user_id
    );
END;
$function$


-- Overload 2 of 2
CREATE OR REPLACE FUNCTION public.get_all_user_places(p_user_id uuid)
 RETURNS TABLE(id text, name text, address text, city text, latitude double precision, longitude double precision, mapbox_id text, google_place_id text, phone text, rating double precision, user_ratings_total integer, categories text[], photo_urls text[], open_hours jsonb, price_level text, description_text text, reservable boolean, serves_breakfast boolean, serves_lunch boolean, serves_dinner boolean, instagram text, x text, source text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT * FROM get_all_user_places(p_user_id::text);
END;
$function$
