-- Feature Flags System for Runtime Configuration
-- This allows toggling features without app updates

-- Create feature_flags table
CREATE TABLE IF NOT EXISTS feature_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_key TEXT UNIQUE NOT NULL,
    flag_name TEXT NOT NULL,
    description TEXT,
    is_enabled BOOLEAN DEFAULT false,
    rollout_percentage INTEGER DEFAULT 0 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
    target_user_ids TEXT[], -- Specific users to enable for
    target_roles TEXT[], -- Specific roles to enable for (landlord, agency, caretaker)
    min_app_version TEXT,
    max_app_version TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create app_config table for general configuration
CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key TEXT UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert default feature flags
INSERT INTO feature_flags (flag_key, flag_name, description, is_enabled, rollout_percentage) VALUES
('enable_new_agency_dashboard', 'New Agency Dashboard', 'Enable the redesigned agency dashboard', false, 0),
('enable_ai_property_description', 'AI Property Descriptions', 'Enable AI-powered property description generator', false, 0),
('enable_video_tours', 'Video Property Tours', 'Enable video tour uploads for properties', false, 0),
('enable_chat_feature', 'In-App Chat', 'Enable direct messaging between users', false, 0),
('enable_advanced_search', 'Advanced Search Filters', 'Enable advanced property search filters', true, 100),
('maintenance_mode', 'Maintenance Mode', 'Put app in maintenance mode', false, 0)
ON CONFLICT (flag_key) DO NOTHING;

-- Insert default app configuration
INSERT INTO app_config (config_key, config_value, description) VALUES
('min_supported_version', '"1.0.0"', 'Minimum app version that is supported'),
('force_update_version', '"0.9.0"', 'Version below which users must update'),
('api_rate_limit', '{"requests_per_minute": 60, "requests_per_hour": 1000}', 'API rate limiting configuration'),
('maintenance_message', '{"title": "Under Maintenance", "message": "We are currently performing maintenance. Please check back soon."}', 'Message to show during maintenance'),
('feature_announcements', '[]', 'List of feature announcements to show users')
ON CONFLICT (config_key) DO NOTHING;

-- Create function to check if feature is enabled for a user
CREATE OR REPLACE FUNCTION is_feature_enabled(
    p_flag_key TEXT,
    p_user_id UUID DEFAULT NULL,
    p_user_role TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_flag RECORD;
    v_random_percentage INTEGER;
BEGIN
    -- Get the feature flag
    SELECT * INTO v_flag
    FROM feature_flags
    WHERE flag_key = p_flag_key;
    
    -- If flag doesn't exist, return false
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- If flag is globally disabled, return false
    IF NOT v_flag.is_enabled THEN
        RETURN false;
    END IF;
    
    -- Check app version constraints
    IF p_app_version IS NOT NULL THEN
        IF v_flag.min_app_version IS NOT NULL AND p_app_version < v_flag.min_app_version THEN
            RETURN false;
        END IF;
        IF v_flag.max_app_version IS NOT NULL AND p_app_version > v_flag.max_app_version THEN
            RETURN false;
        END IF;
    END IF;
    
    -- Check if user is specifically targeted
    IF p_user_id IS NOT NULL AND v_flag.target_user_ids IS NOT NULL THEN
        IF p_user_id::TEXT = ANY(v_flag.target_user_ids) THEN
            RETURN true;
        END IF;
    END IF;
    
    -- Check if user role is targeted
    IF p_user_role IS NOT NULL AND v_flag.target_roles IS NOT NULL THEN
        IF p_user_role = ANY(v_flag.target_roles) THEN
            RETURN true;
        END IF;
    END IF;
    
    -- Check rollout percentage
    IF v_flag.rollout_percentage = 100 THEN
        RETURN true;
    ELSIF v_flag.rollout_percentage = 0 THEN
        RETURN false;
    ELSE
        -- Use user_id hash for consistent rollout
        IF p_user_id IS NOT NULL THEN
            v_random_percentage := (hashtext(p_user_id::TEXT) % 100);
            RETURN v_random_percentage < v_flag.rollout_percentage;
        ELSE
            -- If no user_id, use random
            RETURN (random() * 100)::INTEGER < v_flag.rollout_percentage;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create function to get all enabled features for a user
CREATE OR REPLACE FUNCTION get_user_features(
    p_user_id UUID DEFAULT NULL,
    p_user_role TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL
) RETURNS TABLE(flag_key TEXT, is_enabled BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ff.flag_key,
        is_feature_enabled(ff.flag_key, p_user_id, p_user_role, p_app_version) as is_enabled
    FROM feature_flags ff
    ORDER BY ff.flag_key;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON feature_flags(flag_key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_enabled ON feature_flags(is_enabled);
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(config_key);

-- Enable RLS
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Everyone can read feature flags and config
CREATE POLICY "Anyone can read feature flags"
    ON feature_flags FOR SELECT
    USING (true);

CREATE POLICY "Anyone can read app config"
    ON app_config FOR SELECT
    USING (true);

-- Only authenticated users can check feature status
-- (The functions are STABLE so they respect RLS)

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_feature_flags_updated_at
    BEFORE UPDATE ON feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_config_updated_at
    BEFORE UPDATE ON app_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE feature_flags IS 'Runtime feature flags for gradual rollouts and A/B testing';
COMMENT ON TABLE app_config IS 'General application configuration';
COMMENT ON FUNCTION is_feature_enabled IS 'Check if a feature flag is enabled for a specific user';
COMMENT ON FUNCTION get_user_features IS 'Get all feature flags status for a user';
