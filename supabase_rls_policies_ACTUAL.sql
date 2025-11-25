-- Row-Level Security Policies for Your Actual Schema
-- Run this after your schema is set up

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE places ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE following ENABLE ROW LEVEL SECURITY;
ALTER TABLE place_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE place_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE my_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE place_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tik_tok_place_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_likes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- USERS TABLE POLICIES
-- ============================================================================

-- Users can read all profiles (for search, following, etc.)
CREATE POLICY users_select_policy ON users
    FOR SELECT
    USING (true);

-- Users can only update their own profile
CREATE POLICY users_update_policy ON users
    FOR UPDATE
    USING (auth.uid()::text = id::text);

-- Users can insert their own profile (on signup)
CREATE POLICY users_insert_policy ON users
    FOR INSERT
    WITH CHECK (auth.uid()::text = id::text);

-- ============================================================================
-- PLACES TABLE POLICIES
-- ============================================================================

-- Everyone can read all places
CREATE POLICY places_select_policy ON places
    FOR SELECT
    USING (true);

-- Authenticated users can create places
CREATE POLICY places_insert_policy ON places
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update places they've saved
CREATE POLICY places_update_policy ON places
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM favorites WHERE user_id::text = auth.uid()::text AND place_id = places.id
        ) OR
        EXISTS (
            SELECT 1 FROM my_places WHERE user_id::text = auth.uid()::text AND place_id = places.id
        )
    );

-- ============================================================================
-- FAVORITES TABLE POLICIES
-- ============================================================================

-- Users can see their own favorites and favorites of users they follow
CREATE POLICY favorites_select_policy ON favorites
    FOR SELECT
    USING (
        user_id::text = auth.uid()::text OR
        user_id IN (SELECT following_id FROM following WHERE follower_id::text = auth.uid()::text)
    );

-- Users can only add to their own favorites
CREATE POLICY favorites_insert_policy ON favorites
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only delete their own favorites
CREATE POLICY favorites_delete_policy ON favorites
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- FOLLOWING TABLE POLICIES
-- ============================================================================

-- Users can see who they follow and who follows them
CREATE POLICY following_select_policy ON following
    FOR SELECT
    USING (
        follower_id::text = auth.uid()::text OR
        following_id::text = auth.uid()::text
    );

-- Users can only create follows where they are the follower
CREATE POLICY following_insert_policy ON following
    FOR INSERT
    WITH CHECK (follower_id::text = auth.uid()::text);

-- Users can only delete follows where they are the follower
CREATE POLICY following_delete_policy ON following
    FOR DELETE
    USING (follower_id::text = auth.uid()::text);

-- ============================================================================
-- PLACE LISTS TABLE POLICIES
-- ============================================================================

-- Users can see their own lists and public lists
CREATE POLICY place_lists_select_policy ON place_lists
    FOR SELECT
    USING (
        user_id::text = auth.uid()::text OR
        is_public = true
    );

-- Users can only create their own lists
CREATE POLICY place_lists_insert_policy ON place_lists
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only update their own lists
CREATE POLICY place_lists_update_policy ON place_lists
    FOR UPDATE
    USING (user_id::text = auth.uid()::text);

-- Users can only delete their own lists
CREATE POLICY place_lists_delete_policy ON place_lists
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- PLACE LIST ITEMS TABLE POLICIES
-- ============================================================================

-- Users can see items in their own lists or public lists
CREATE POLICY place_list_items_select_policy ON place_list_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_items.list_id 
            AND (pl.user_id::text = auth.uid()::text OR pl.is_public = true)
        )
    );

-- Users can only add items to their own lists
CREATE POLICY place_list_items_insert_policy ON place_list_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_items.list_id 
            AND pl.user_id::text = auth.uid()::text
        )
    );

-- Users can only delete items from their own lists
CREATE POLICY place_list_items_delete_policy ON place_list_items
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM place_lists pl 
            WHERE pl.id = place_list_items.list_id 
            AND pl.user_id::text = auth.uid()::text
        )
    );

-- ============================================================================
-- REVIEWS TABLE POLICIES
-- ============================================================================

-- Everyone can read all reviews
CREATE POLICY reviews_select_policy ON reviews
    FOR SELECT
    USING (true);

-- Users can only create reviews as themselves
CREATE POLICY reviews_insert_policy ON reviews
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only update their own reviews
CREATE POLICY reviews_update_policy ON reviews
    FOR UPDATE
    USING (user_id::text = auth.uid()::text);

-- Users can only delete their own reviews
CREATE POLICY reviews_delete_policy ON reviews
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- COMMENTS TABLE POLICIES
-- ============================================================================

-- Everyone can read all comments
CREATE POLICY comments_select_policy ON comments
    FOR SELECT
    USING (true);

-- Users can only create comments as themselves
CREATE POLICY comments_insert_policy ON comments
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only update their own comments
CREATE POLICY comments_update_policy ON comments
    FOR UPDATE
    USING (user_id::text = auth.uid()::text);

-- Users can only delete their own comments
CREATE POLICY comments_delete_policy ON comments
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- MY_PLACES TABLE POLICIES
-- ============================================================================

-- Users can see their own places and places of users they follow
CREATE POLICY my_places_select_policy ON my_places
    FOR SELECT
    USING (
        user_id::text = auth.uid()::text OR
        user_id IN (SELECT following_id FROM following WHERE follower_id::text = auth.uid()::text)
    );

-- Users can only add to their own my_places
CREATE POLICY my_places_insert_policy ON my_places
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only delete their own places
CREATE POLICY my_places_delete_policy ON my_places
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- EXTERNAL PLACES TABLE POLICIES
-- ============================================================================

-- Users can only see their own external places
CREATE POLICY external_places_select_policy ON external_places
    FOR SELECT
    USING (user_id::text = auth.uid()::text);

-- Users can only create their own external places
CREATE POLICY external_places_insert_policy ON external_places
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only delete their own external places
CREATE POLICY external_places_delete_policy ON external_places
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- PLACE NOTES TABLE POLICIES
-- ============================================================================

-- Users can only see their own notes
CREATE POLICY place_notes_select_policy ON place_notes
    FOR SELECT
    USING (user_id::text = auth.uid()::text);

-- Users can only create their own notes
CREATE POLICY place_notes_insert_policy ON place_notes
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only update their own notes
CREATE POLICY place_notes_update_policy ON place_notes
    FOR UPDATE
    USING (user_id::text = auth.uid()::text);

-- Users can only delete their own notes
CREATE POLICY place_notes_delete_policy ON place_notes
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- TIKTOK PLACE FLAGS TABLE POLICIES
-- ============================================================================

-- Users can only see their own flags
CREATE POLICY tik_tok_flags_select_policy ON tik_tok_place_flags
    FOR SELECT
    USING (user_id::text = auth.uid()::text);

-- Users can only create their own flags
CREATE POLICY tik_tok_flags_insert_policy ON tik_tok_place_flags
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only delete their own flags
CREATE POLICY tik_tok_flags_delete_policy ON tik_tok_place_flags
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- USER NOTIFICATIONS TABLE POLICIES
-- ============================================================================

-- Users can only see their own notifications
CREATE POLICY user_notifications_select_policy ON user_notifications
    FOR SELECT
    USING (user_id::text = auth.uid()::text);

-- System/other users can create notifications for any user
CREATE POLICY user_notifications_insert_policy ON user_notifications
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Users can only update their own notifications (mark as read)
CREATE POLICY user_notifications_update_policy ON user_notifications
    FOR UPDATE
    USING (user_id::text = auth.uid()::text);

-- Users can only delete their own notifications
CREATE POLICY user_notifications_delete_policy ON user_notifications
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- NOTIFICATIONS TABLE POLICIES (duplicate table?)
-- ============================================================================

-- Users can only see their own notifications
CREATE POLICY notifications_select_policy ON notifications
    FOR SELECT
    USING (user_id::text = auth.uid()::text);

-- System/other users can create notifications
CREATE POLICY notifications_insert_policy ON notifications
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Users can only update their own notifications
CREATE POLICY notifications_update_policy ON notifications
    FOR UPDATE
    USING (user_id::text = auth.uid()::text);

-- Users can only delete their own notifications
CREATE POLICY notifications_delete_policy ON notifications
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- REVIEW LIKES TABLE POLICIES
-- ============================================================================

-- Everyone can see all likes (for like counts)
CREATE POLICY review_likes_select_policy ON review_likes
    FOR SELECT
    USING (true);

-- Users can only create likes as themselves
CREATE POLICY review_likes_insert_policy ON review_likes
    FOR INSERT
    WITH CHECK (user_id::text = auth.uid()::text);

-- Users can only delete their own likes
CREATE POLICY review_likes_delete_policy ON review_likes
    FOR DELETE
    USING (user_id::text = auth.uid()::text);

-- ============================================================================
-- RLS POLICIES COMPLETE
-- ============================================================================

