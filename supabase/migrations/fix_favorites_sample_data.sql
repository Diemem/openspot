-- Migration: Fix favorites and add sample data
-- Created: 2026-04-27
-- Purpose: Add sample favorites data for testing

-- Add sample favorites for existing users (if any)
DO $
DECLARE
    sample_user_id UUID;
    sample_property_id UUID;
    favorites_exist BOOLEAN;
BEGIN
    -- Get the first user from auth.users (if any exists)
    SELECT id INTO sample_user_id FROM auth.users LIMIT 1;
    
    -- Get the first property (if any exists)
    SELECT id INTO sample_property_id FROM properties WHERE status = 'active' LIMIT 1;
    
    -- Only insert sample data if we have both user and property
    IF sample_user_id IS NOT NULL AND sample_property_id IS NOT NULL THEN
        -- Check if sample favorites already exist for this user
        SELECT EXISTS(
            SELECT 1 FROM favorites 
            WHERE user_id = sample_user_id 
            AND property_id = sample_property_id
        ) INTO favorites_exist;
        
        -- Only insert if no sample data exists
        IF NOT favorites_exist THEN
            -- Insert sample favorite
            INSERT INTO favorites (user_id, property_id, created_at) 
            VALUES (sample_user_id, sample_property_id, NOW() - INTERVAL '1 day');
            
            -- Add a second favorite if there's another property
            SELECT id INTO sample_property_id FROM properties 
            WHERE status = 'active' AND id != sample_property_id LIMIT 1;
            
            IF sample_property_id IS NOT NULL THEN
                INSERT INTO favorites (user_id, property_id, created_at) 
                VALUES (sample_user_id, sample_property_id, NOW() - INTERVAL '2 hours')
                ON CONFLICT (user_id, property_id) DO NOTHING;
            END IF;
        END IF;
    END IF;
END $;

COMMENT ON TABLE favorites IS 'User favorite properties - simple many-to-many relationship';