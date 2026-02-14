CREATE OR REPLACE FUNCTION public.delete_external_review_image(
    p_place_id text,
    p_image_url text
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Remove the specific image from the media array
    UPDATE external_reviews
    SET media = (
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(media) AS elem
        WHERE elem->>'imageUrl' != p_image_url
    )
    WHERE place_id = p_place_id
    AND media @> jsonb_build_array(jsonb_build_object('imageUrl', p_image_url));

    -- Clean up reviews with no remaining media
    DELETE FROM external_reviews
    WHERE place_id = p_place_id
    AND (media IS NULL OR media = '[]'::jsonb OR jsonb_array_length(media) = 0);
END;
$$;
