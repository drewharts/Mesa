-- ============================================================================
-- Function: match_contacts_by_phone
-- ============================================================================
-- Matches provided E.164 phone numbers against the users.phone_number column,
-- excluding the requesting user. Returns SETOF users so the response decodes
-- directly to ProfileData.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.match_contacts_by_phone(
    p_phone_numbers TEXT[],
    p_requesting_user_id TEXT
)
RETURNS SETOF users
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT u.*
    FROM users u
    WHERE u.phone_number = ANY(p_phone_numbers)
      AND u.id != p_requesting_user_id;
END;
$function$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.match_contacts_by_phone(TEXT[], TEXT) TO authenticated;
