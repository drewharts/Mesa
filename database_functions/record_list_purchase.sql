-- ============================================================================
-- Function: record_list_purchase
-- ============================================================================
-- Records a verified StoreKit purchase in the database.
-- Uses ON CONFLICT to safely handle duplicate transaction attempts.
-- ============================================================================

CREATE OR REPLACE FUNCTION record_list_purchase(
    p_user_id TEXT,
    p_list_id TEXT,
    p_transaction_id TEXT,
    p_original_transaction_id TEXT,
    p_price_tier TEXT,
    p_price_cents INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    INSERT INTO list_purchases (user_id, list_id, price_tier, price_cents, transaction_id, original_transaction_id)
    VALUES (p_user_id, p_list_id::UUID, p_price_tier, p_price_cents, p_transaction_id, p_original_transaction_id)
    ON CONFLICT (user_id, list_id) DO NOTHING;
END;
$function$;

GRANT EXECUTE ON FUNCTION record_list_purchase(TEXT, TEXT, TEXT, TEXT, TEXT, INT) TO authenticated;
