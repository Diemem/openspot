-- Migration: Add notifications and saved searches tables
-- Created: 2026-04-26
-- Note: This migration will DROP and recreate the tables to ensure correct schema

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- Drop existing table if it exists to ensure clean schema
DROP TABLE IF EXISTS notifications CASCADE;

CREATE TABLE notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'general' CHECK (type IN ('general', 'property_match', 'price_drop', 'new_message', 'system')),
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- RLS for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SAVED SEARCHES TABLE
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- Drop existing table if it exists to ensure clean schema
DROP TABLE IF EXISTS saved_searches CASCADE;

CREATE TABLE saved_searches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    filters JSONB NOT NULL DEFAULT '{}',
    notifications_enabled BOOLEAN DEFAULT TRUE,
    last_notification_sent TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for saved searches
CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id ON saved_searches(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_searches_notifications ON saved_searches(notifications_enabled) WHERE notifications_enabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_saved_searches_created_at ON saved_searches(created_at DESC);

-- RLS for saved searches
ALTER TABLE saved_searches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own saved searches" ON saved_searches;
CREATE POLICY "Users can manage their own saved searches" ON saved_searches
    FOR ALL USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_notifications_updated_at ON notifications;
CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON notifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_saved_searches_updated_at ON saved_searches;
CREATE TRIGGER update_saved_searches_updated_at 
    BEFORE UPDATE ON saved_searches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- Function to create a notification
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_title TEXT,
    p_message TEXT,
    p_type TEXT DEFAULT 'general',
    p_data JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (p_user_id, p_title, p_message, p_type, p_data)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notifications 
    SET is_read = TRUE, read_at = NOW()
    WHERE id = p_notification_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE notifications 
    SET is_read = TRUE, read_at = NOW()
    WHERE user_id = auth.uid() AND is_read = FALSE;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM notifications
        WHERE user_id = auth.uid() AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cleanup old notifications (older than 90 days)
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SAMPLE DATA (for development and testing)
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- Insert sample notifications for development (will only work if users exist)
-- These will be inserted for any existing users in the system

DO $$
DECLARE
    sample_user_id UUID;
    notification_exists BOOLEAN;
BEGIN
    -- Get the first user from auth.users (if any exists)
    SELECT id INTO sample_user_id FROM auth.users LIMIT 1;
    
    -- Only insert sample data if we have at least one user
    IF sample_user_id IS NOT NULL THEN
        -- Check if sample notifications already exist for this user
        SELECT EXISTS(
            SELECT 1 FROM notifications 
            WHERE user_id = sample_user_id 
            AND title = 'Welcome to OpenSpot!'
        ) INTO notification_exists;
        
        -- Only insert if no sample data exists
        IF NOT notification_exists THEN
            -- Insert sample notifications
            INSERT INTO notifications (user_id, title, message, type, is_read, created_at) VALUES
            (sample_user_id, 'Welcome to OpenSpot!', 'Complete your profile to get started and unlock all features', 'system', false, NOW() - INTERVAL '5 minutes'),
            (sample_user_id, 'New property match found', 'Found 3 new properties matching your saved search criteria in Westlands', 'property_match', false, NOW() - INTERVAL '2 hours'),
            (sample_user_id, 'Price drop alert', 'A property in your favorites reduced price by 15% - Modern 2BR Apartment', 'price_drop', false, NOW() - INTERVAL '3 hours'),
            (sample_user_id, 'Profile verification reminder', 'Verify your phone number to build trust with landlords and unlock premium features', 'system', true, NOW() - INTERVAL '1 day'),
            (sample_user_id, 'New properties in your area', 'Check out 5 new listings that match your preferences in Nairobi', 'property_match', true, NOW() - INTERVAL '2 days'),
            (sample_user_id, 'Search saved successfully', 'Your search for "2BR apartments under KES 50,000" has been saved with notifications enabled', 'system', true, NOW() - INTERVAL '3 days');
        END IF;
        
        -- Check if sample saved searches already exist
        SELECT EXISTS(
            SELECT 1 FROM saved_searches 
            WHERE user_id = sample_user_id 
            AND name = '2BR in Westlands'
        ) INTO notification_exists;
        
        -- Only insert saved searches if none exist
        IF NOT notification_exists THEN
            -- Insert sample saved searches
            INSERT INTO saved_searches (user_id, name, filters, notifications_enabled, created_at) VALUES
            (sample_user_id, '2BR in Westlands', '{"location": "Westlands", "property_type": "apartment", "bedrooms": 2, "max_price": 80000}', true, NOW() - INTERVAL '1 day'),
            (sample_user_id, 'Affordable Studios', '{"property_type": "studio", "max_price": 30000}', true, NOW() - INTERVAL '3 days'),
            (sample_user_id, 'Family Houses', '{"property_type": "house", "bedrooms": 3, "min_price": 60000, "max_price": 120000}', false, NOW() - INTERVAL '1 week');
        END IF;
    END IF;
END $$;

COMMENT ON TABLE notifications IS 'User notifications for property matches, messages, and system updates';
COMMENT ON TABLE saved_searches IS 'User saved search criteria with notification preferences';
COMMENT ON FUNCTION create_notification IS 'Creates a new notification for a user';
COMMENT ON FUNCTION mark_notification_read IS 'Marks a specific notification as read';
COMMENT ON FUNCTION mark_all_notifications_read IS 'Marks all notifications as read for the current user';
COMMENT ON FUNCTION get_unread_notification_count IS 'Returns count of unread notifications for current user';
COMMENT ON FUNCTION cleanup_old_notifications IS 'Removes notifications older than 90 days';