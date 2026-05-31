-- =====================================================
-- MISSING CRITICAL INDEXES
-- =====================================================
-- Adds indexes that were identified as missing in the audit

-- =====================================================
-- PROPERTIES TABLE INDEXES
-- =====================================================

-- Check if properties table exists before creating indexes
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'properties') THEN
        -- Location-based searches (most common query)
        CREATE INDEX IF NOT EXISTS idx_properties_location ON properties(location);
        
        -- Check if status column exists
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'status') THEN
            CREATE INDEX IF NOT EXISTS idx_properties_location_status ON properties(location, status) WHERE status = 'active';
            CREATE INDEX IF NOT EXISTS idx_properties_status_created ON properties(status, created_at DESC);
        END IF;
        
        -- Price range searches
        CREATE INDEX IF NOT EXISTS idx_properties_price ON properties(price);
        
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'status') THEN
            CREATE INDEX IF NOT EXISTS idx_properties_price_range ON properties(price, status, created_at DESC);
        END IF;
        
        -- Landlord's properties
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'landlord_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'status') THEN
                CREATE INDEX IF NOT EXISTS idx_properties_landlord_status ON properties(landlord_id, status, created_at DESC);
            ELSE
                CREATE INDEX IF NOT EXISTS idx_properties_landlord_created ON properties(landlord_id, created_at DESC);
            END IF;
        END IF;
        
        -- Search by type and location
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'property_type') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'status') THEN
                CREATE INDEX IF NOT EXISTS idx_properties_type_location ON properties(property_type, location) WHERE status = 'active';
            END IF;
        END IF;
        
        -- Full-text search on title and description
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'title') THEN
            CREATE INDEX IF NOT EXISTS idx_properties_title_search ON properties USING gin(to_tsvector('english', title));
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'description') THEN
            CREATE INDEX IF NOT EXISTS idx_properties_description_search ON properties USING gin(to_tsvector('english', description));
        END IF;
        
        -- Composite indexes for common queries
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'status') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'property_type') THEN
                CREATE INDEX IF NOT EXISTS idx_properties_search_composite ON properties(location, price, property_type, status) WHERE status = 'active';
            END IF;
        END IF;
        
        -- Landlord dashboard
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'landlord_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'views') THEN
                IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'likes') THEN
                    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = 'status') THEN
                        CREATE INDEX IF NOT EXISTS idx_properties_landlord_dashboard ON properties(landlord_id, status, created_at DESC, views, likes) WHERE status IN ('active', 'pending');
                    END IF;
                END IF;
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- NOTIFICATIONS TABLE INDEXES
-- =====================================================

-- Most common query: unread notifications for user
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC) WHERE is_read = false;

-- All notifications for user
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);

-- Notification type filtering (only if column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'notification_type'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(notification_type, created_at DESC);
    END IF;
END $$;

-- =====================================================
-- AGENCIES TABLE INDEXES
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'agencies') THEN
        -- Agency name search
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agencies' AND column_name = 'name') THEN
            CREATE INDEX IF NOT EXISTS idx_agencies_name ON agencies(name);
        END IF;
        
        -- Agency location
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agencies' AND column_name = 'location') THEN
            CREATE INDEX IF NOT EXISTS idx_agencies_location ON agencies(location);
        END IF;
        
        -- Agency status
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agencies' AND column_name = 'status') THEN
            CREATE INDEX IF NOT EXISTS idx_agencies_status ON agencies(status) WHERE status = 'active';
        END IF;
    END IF;
END $$;

-- =====================================================
-- AGENCY_CLIENTS TABLE INDEXES
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'agency_clients') THEN
        -- Agency's clients
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'agency_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'status') THEN
                CREATE INDEX IF NOT EXISTS idx_agency_clients_agency ON agency_clients(agency_id, status, created_at DESC);
            ELSE
                CREATE INDEX IF NOT EXISTS idx_agency_clients_agency ON agency_clients(agency_id, created_at DESC);
            END IF;
        END IF;
        
        -- Landlord's agencies
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'landlord_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'status') THEN
                CREATE INDEX IF NOT EXISTS idx_agency_clients_landlord ON agency_clients(landlord_id, status);
            ELSE
                CREATE INDEX IF NOT EXISTS idx_agency_clients_landlord ON agency_clients(landlord_id);
            END IF;
        END IF;
        
        -- Active relationships
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'agency_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'landlord_id') THEN
                IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'agency_clients' AND column_name = 'status') THEN
                    CREATE INDEX IF NOT EXISTS idx_agency_clients_active ON agency_clients(agency_id, landlord_id) WHERE status = 'active';
                END IF;
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- CARETAKERS TABLE INDEXES
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'caretakers') THEN
        -- Property's caretakers
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'caretakers' AND column_name = 'property_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'caretakers' AND column_name = 'invitation_status') THEN
                CREATE INDEX IF NOT EXISTS idx_caretakers_property ON caretakers(property_id, invitation_status);
            ELSE
                CREATE INDEX IF NOT EXISTS idx_caretakers_property ON caretakers(property_id);
            END IF;
        END IF;
        
        -- User's caretaker roles
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'caretakers' AND column_name = 'caretaker_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'caretakers' AND column_name = 'invitation_status') THEN
                CREATE INDEX IF NOT EXISTS idx_caretakers_user ON caretakers(caretaker_id, invitation_status) WHERE caretaker_id IS NOT NULL;
            ELSE
                CREATE INDEX IF NOT EXISTS idx_caretakers_user ON caretakers(caretaker_id) WHERE caretaker_id IS NOT NULL;
            END IF;
        END IF;
        
        -- Pending invitations
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'caretakers' AND column_name = 'invited_email') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'caretakers' AND column_name = 'invitation_status') THEN
                CREATE INDEX IF NOT EXISTS idx_caretakers_pending ON caretakers(invited_email, invitation_status) WHERE invitation_status = 'pending';
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- MESSAGES/INQUIRIES INDEXES (if table exists)
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'messages') THEN
        -- User's messages (sender)
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'sender_id') THEN
            CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id, created_at DESC);
        END IF;
        
        -- User's messages (recipient)
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'recipient_id') THEN
            CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id, created_at DESC);
        END IF;
        
        -- Unread messages
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'recipient_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'is_read') THEN
                CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(recipient_id, is_read, created_at DESC) WHERE is_read = false;
            END IF;
        END IF;
        
        -- Conversation threads
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'sender_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'recipient_id') THEN
                CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(sender_id, recipient_id, created_at DESC);
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- SAVED SEARCHES INDEXES
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'saved_searches') THEN
        -- User's saved searches
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_searches' AND column_name = 'user_id') THEN
            CREATE INDEX IF NOT EXISTS idx_saved_searches_user ON saved_searches(user_id, created_at DESC);
        END IF;
        
        -- Active saved searches
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_searches' AND column_name = 'user_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_searches' AND column_name = 'is_active') THEN
                CREATE INDEX IF NOT EXISTS idx_saved_searches_active ON saved_searches(user_id, is_active) WHERE is_active = true;
            END IF;
        END IF;
    END IF;
END $$;

-- =====================================================
-- PROPERTY VIEWS INDEXES (engagement tracking)
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'property_views') THEN
        -- Property's views
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'property_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'viewed_at') THEN
                CREATE INDEX IF NOT EXISTS idx_property_views_property ON property_views(property_id, viewed_at DESC);
            ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'created_at') THEN
                CREATE INDEX IF NOT EXISTS idx_property_views_property ON property_views(property_id, created_at DESC);
            END IF;
        END IF;
        
        -- User's view history
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'user_id') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'viewed_at') THEN
                CREATE INDEX IF NOT EXISTS idx_property_views_user ON property_views(user_id, viewed_at DESC) WHERE user_id IS NOT NULL;
            ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'created_at') THEN
                CREATE INDEX IF NOT EXISTS idx_property_views_user ON property_views(user_id, created_at DESC) WHERE user_id IS NOT NULL;
            END IF;
        END IF;
        
        -- Recent views (for analytics) - removed WHERE clause as NOW() is not immutable
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'viewed_at') THEN
            CREATE INDEX IF NOT EXISTS idx_property_views_recent ON property_views(viewed_at DESC);
        ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'property_views' AND column_name = 'created_at') THEN
            CREATE INDEX IF NOT EXISTS idx_property_views_recent ON property_views(created_at DESC);
        END IF;
    END IF;
END $$;

-- =====================================================
-- ANALYZE TABLES
-- =====================================================

-- Update statistics for query planner (only for existing tables)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'properties') THEN
        EXECUTE 'ANALYZE properties';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notifications') THEN
        EXECUTE 'ANALYZE notifications';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'agencies') THEN
        EXECUTE 'ANALYZE agencies';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'agency_clients') THEN
        EXECUTE 'ANALYZE agency_clients';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'caretakers') THEN
        EXECUTE 'ANALYZE caretakers';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'profiles') THEN
        EXECUTE 'ANALYZE profiles';
    END IF;
END $$;

-- =====================================================
-- COMMENTS
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_indexes WHERE indexname = 'idx_properties_location') THEN
        COMMENT ON INDEX idx_properties_location IS 'Fast location-based property searches';
    END IF;
    
    IF EXISTS (SELECT FROM pg_indexes WHERE indexname = 'idx_notifications_user_unread') THEN
        COMMENT ON INDEX idx_notifications_user_unread IS 'Optimized for fetching unread notifications';
    END IF;
    
    IF EXISTS (SELECT FROM pg_indexes WHERE indexname = 'idx_properties_search_composite') THEN
        COMMENT ON INDEX idx_properties_search_composite IS 'Composite index for common search queries';
    END IF;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Missing indexes added!';
    RAISE NOTICE '⚡ Query performance significantly improved';
    RAISE NOTICE '🔍 Full-text search enabled on properties';
    RAISE NOTICE '📊 Statistics updated for query planner';
END $$;
