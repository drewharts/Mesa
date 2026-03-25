-- ============================================================================
-- Migration: Create list_purchases table
-- ============================================================================
-- Tracks completed in-app purchases of paid lists.
-- Each row represents a single verified StoreKit transaction.
-- UNIQUE(user_id, list_id) ensures one purchase per user per list.
-- ============================================================================

CREATE TABLE IF NOT EXISTS list_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id),
  list_id UUID NOT NULL REFERENCES place_lists(id) ON DELETE CASCADE,
  price_tier TEXT NOT NULL,
  price_cents INT NOT NULL,
  transaction_id TEXT NOT NULL,
  original_transaction_id TEXT,
  purchased_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, list_id)
);

CREATE INDEX IF NOT EXISTS idx_list_purchases_user ON list_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_list_purchases_list ON list_purchases(list_id);
