-- ============================================================================
-- MIGRATION: Create place_list_collaborators table
-- Purpose: Enable collaborative editing of place lists
-- Note: Using TEXT for IDs to match existing place_lists and users tables
-- ============================================================================

-- ============================================================================
-- TABLE: place_list_collaborators
-- ============================================================================
CREATE TABLE IF NOT EXISTS place_list_collaborators (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    list_id TEXT NOT NULL REFERENCES place_lists(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'editor' CHECK (role IN ('viewer', 'editor')),
    added_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Prevent duplicate collaborators on the same list
    UNIQUE(list_id, user_id)
);

-- ============================================================================
-- INDEXES for performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_place_list_collaborators_list_id 
    ON place_list_collaborators(list_id);

CREATE INDEX IF NOT EXISTS idx_place_list_collaborators_user_id 
    ON place_list_collaborators(user_id);

CREATE INDEX IF NOT EXISTS idx_place_list_collaborators_added_at 
    ON place_list_collaborators(added_at DESC);

-- ============================================================================
-- ENABLE RLS
-- ============================================================================
ALTER TABLE place_list_collaborators ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES for place_list_collaborators
-- ============================================================================

-- SELECT: Users can see collaborators for lists they own or collaborate on
CREATE POLICY place_list_collaborators_select_policy ON place_list_collaborators
    FOR SELECT
    USING (
        -- The collaborator can see their own record
        user_id = auth.uid()::text OR
        -- The person who added them can see
        added_by = auth.uid()::text OR
        -- List owner can see all collaborators
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_collaborators.list_id 
            AND pl.user_id = auth.uid()::text
        ) OR
        -- Other collaborators on the same list can see
        EXISTS (
            SELECT 1 FROM place_list_collaborators plc2
            WHERE plc2.list_id = place_list_collaborators.list_id
            AND plc2.user_id = auth.uid()::text
        )
    );

-- INSERT: Only list owners can add collaborators
CREATE POLICY place_list_collaborators_insert_policy ON place_list_collaborators
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_collaborators.list_id 
            AND pl.user_id = auth.uid()::text
        )
    );

-- UPDATE: List owners can update collaborator roles
CREATE POLICY place_list_collaborators_update_policy ON place_list_collaborators
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_collaborators.list_id 
            AND pl.user_id = auth.uid()::text
        )
    );

-- DELETE: List owners can remove collaborators, collaborators can remove themselves
CREATE POLICY place_list_collaborators_delete_policy ON place_list_collaborators
    FOR DELETE
    USING (
        -- Collaborator can remove themselves
        user_id = auth.uid()::text OR
        -- Owner can remove anyone
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_collaborators.list_id 
            AND pl.user_id = auth.uid()::text
        )
    );

-- ============================================================================
-- UPDATE place_lists RLS to allow collaborator access
-- ============================================================================

-- Drop existing select policy and recreate with collaborator support
DROP POLICY IF EXISTS place_lists_select_policy ON place_lists;
CREATE POLICY place_lists_select_policy ON place_lists
    FOR SELECT
    USING (
        user_id = auth.uid()::text OR
        is_public = true OR
        -- Allow collaborators to view the list
        EXISTS (
            SELECT 1 FROM place_list_collaborators plc
            WHERE plc.list_id = place_lists.id
            AND plc.user_id = auth.uid()::text
        )
    );

-- ============================================================================
-- UPDATE place_list_items RLS to allow collaborator edits
-- ============================================================================

-- Drop and recreate SELECT policy
DROP POLICY IF EXISTS place_list_items_select_policy ON place_list_items;
CREATE POLICY place_list_items_select_policy ON place_list_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_items.list_id 
            AND (
                pl.user_id = auth.uid()::text OR 
                pl.is_public = true OR
                EXISTS (
                    SELECT 1 FROM place_list_collaborators plc
                    WHERE plc.list_id = pl.id
                    AND plc.user_id = auth.uid()::text
                )
            )
        )
    );

-- Drop and recreate INSERT policy - allow editors to add items
DROP POLICY IF EXISTS place_list_items_insert_policy ON place_list_items;
CREATE POLICY place_list_items_insert_policy ON place_list_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_items.list_id 
            AND (
                pl.user_id = auth.uid()::text OR
                -- Editors can add items
                EXISTS (
                    SELECT 1 FROM place_list_collaborators plc
                    WHERE plc.list_id = pl.id
                    AND plc.user_id = auth.uid()::text
                    AND plc.role = 'editor'
                )
            )
        )
    );

-- Drop and recreate DELETE policy - allow editors to remove items
DROP POLICY IF EXISTS place_list_items_delete_policy ON place_list_items;
CREATE POLICY place_list_items_delete_policy ON place_list_items
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_items.list_id 
            AND (
                pl.user_id = auth.uid()::text OR
                -- Editors can remove items
                EXISTS (
                    SELECT 1 FROM place_list_collaborators plc
                    WHERE plc.list_id = pl.id
                    AND plc.user_id = auth.uid()::text
                    AND plc.role = 'editor'
                )
            )
        )
    );

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

