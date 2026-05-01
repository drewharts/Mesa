-- ============================================================================
-- Table: saved_lists
-- ============================================================================
-- Tracks which public lists users have saved to their profile.
-- Lightweight join table — references original list_id so creator updates
-- flow through automatically (live sync, not a fork).
--
-- CASCADE on list_id: if creator deletes their list, all saves are cleaned up.
-- UNIQUE constraint: prevents duplicate saves.
-- ============================================================================

CREATE TABLE IF NOT EXISTS saved_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    list_id UUID NOT NULL REFERENCES place_lists(id) ON DELETE CASCADE,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, list_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_lists_user_id ON saved_lists(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_lists_list_id ON saved_lists(list_id);

-- ============================================================================
-- RLS Policies
-- ============================================================================

ALTER TABLE saved_lists ENABLE ROW LEVEL SECURITY;

-- Users can view their own saved lists
CREATE POLICY saved_lists_select ON saved_lists
    FOR SELECT USING (user_id = auth.uid()::text);

-- Users can save public lists that aren't their own
CREATE POLICY saved_lists_insert ON saved_lists
    FOR INSERT WITH CHECK (
        user_id = auth.uid()::text
        AND EXISTS (
            SELECT 1 FROM place_lists pl
            WHERE pl.id = list_id
            AND pl.is_public = true
            AND pl.user_id != auth.uid()::text
        )
    );

-- Users can unsave their own saved lists
CREATE POLICY saved_lists_delete ON saved_lists
    FOR DELETE USING (user_id = auth.uid()::text);

-- Allow list owners to count saves on their lists (for save count display)
CREATE POLICY saved_lists_owner_count ON saved_lists
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM place_lists pl
            WHERE pl.id = list_id
            AND pl.user_id = auth.uid()::text
        )
    );
