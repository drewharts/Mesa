-- ============================================================================
-- Function: extract_video_url
-- ============================================================================
-- This file contains the current state of the function in the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.extract_video_url(videos jsonb[])
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    first_video JSONB;
BEGIN
    IF videos IS NULL OR array_length(videos, 1) IS NULL OR array_length(videos, 1) = 0 THEN
        RETURN NULL;
    END IF;
    
    first_video := videos[1];
    
    IF first_video IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN first_video->>'url';
END;
$function$
