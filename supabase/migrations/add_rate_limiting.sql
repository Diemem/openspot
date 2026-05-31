-- =====================================================
-- RATE LIMITING SYSTEM
-- =====================================================
-- Prevents API abuse and protects against DDoS attacks

-- Create rate limiting table
CREATE TABLE IF NOT EXISTS api_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    ip_address INET,
    endpoint TEXT NOT NULL,
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create composite index for fast lookups
CREATE INDEX IF NOT EXISTS idx_rate_limits_user_endpoint 
    ON api_rate_limits(user_id, endpoint, window_start DESC);

CREATE INDEX IF NOT EXISTS idx_rate_limits_ip_endpoint 
    ON api_rate_limits(ip_address, endpoint, window_start DESC);

CREATE INDEX IF NOT EXISTS idx_rate_limits_cleanup 
    ON api_rate_limits(window_start);

-- Enable RLS
ALTER TABLE api_rate_limits ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own rate limit status
CREATE POLICY "Users can view own rate limits"
    ON api_rate_limits FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: System can manage rate limits
CREATE POLICY "System can manage rate limits"
    ON api_rate_limits FOR ALL
    USING (true);

-- =====================================================
-- RATE LIMIT CHECK FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION check_rate_limit(
    p_endpoint TEXT,
    p_max_requests INTEGER DEFAULT 60,
    p_window_minutes INTEGER DEFAULT 1
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
    v_window_start TIMESTAMPTZ;
BEGIN
    v_user_id := auth.uid();
    v_window_start := NOW() - (p_window_minutes || ' minutes')::INTERVAL;
    
    -- Count requests in current window
    SELECT COALESCE(SUM(request_count), 0) INTO v_count
    FROM api_rate_limits
    WHERE user_id = v_user_id
        AND endpoint = p_endpoint
        AND window_start > v_window_start;
    
    -- Check if limit exceeded
    IF v_count >= p_max_requests THEN
        RAISE EXCEPTION 'Rate limit exceeded. Try again in % minute(s).', p_window_minutes
            USING ERRCODE = '42501';
    END IF;
    
    -- Record this request
    INSERT INTO api_rate_limits (user_id, endpoint, request_count, window_start)
    VALUES (v_user_id, p_endpoint, 1, NOW())
    ON CONFLICT DO NOTHING;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- IP-BASED RATE LIMITING (for anonymous users)
-- =====================================================

CREATE OR REPLACE FUNCTION check_rate_limit_by_ip(
    p_ip_address TEXT,
    p_endpoint TEXT,
    p_max_requests INTEGER DEFAULT 30,
    p_window_minutes INTEGER DEFAULT 1
) RETURNS BOOLEAN AS $$
DECLARE
    v_count INTEGER;
    v_window_start TIMESTAMPTZ;
    v_ip INET;
BEGIN
    v_ip := p_ip_address::INET;
    v_window_start := NOW() - (p_window_minutes || ' minutes')::INTERVAL;
    
    -- Count requests in current window
    SELECT COALESCE(SUM(request_count), 0) INTO v_count
    FROM api_rate_limits
    WHERE ip_address = v_ip
        AND endpoint = p_endpoint
        AND window_start > v_window_start;
    
    -- Check if limit exceeded
    IF v_count >= p_max_requests THEN
        RAISE EXCEPTION 'Rate limit exceeded. Try again in % minute(s).', p_window_minutes
            USING ERRCODE = '42501';
    END IF;
    
    -- Record this request
    INSERT INTO api_rate_limits (ip_address, endpoint, request_count, window_start)
    VALUES (v_ip, p_endpoint, 1, NOW())
    ON CONFLICT DO NOTHING;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ENDPOINT-SPECIFIC RATE LIMITS
-- =====================================================

-- Strict limits for authentication endpoints
CREATE OR REPLACE FUNCTION check_auth_rate_limit()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN check_rate_limit('auth', 5, 15); -- 5 requests per 15 minutes
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Property creation limits
CREATE OR REPLACE FUNCTION check_property_creation_limit()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN check_rate_limit('property_create', 10, 60); -- 10 properties per hour
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Message sending limits
CREATE OR REPLACE FUNCTION check_message_rate_limit()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN check_rate_limit('message_send', 30, 1); -- 30 messages per minute
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Search query limits
CREATE OR REPLACE FUNCTION check_search_rate_limit()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN check_rate_limit('search', 100, 1); -- 100 searches per minute
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_old_rate_limits()
RETURNS VOID AS $$
BEGIN
    -- Delete rate limit records older than 1 hour
    DELETE FROM api_rate_limits
    WHERE window_start < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION check_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_rate_limit_by_ip(TEXT, TEXT, INTEGER, INTEGER) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_auth_rate_limit() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_property_creation_limit() TO authenticated;
GRANT EXECUTE ON FUNCTION check_message_rate_limit() TO authenticated;
GRANT EXECUTE ON FUNCTION check_search_rate_limit() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION cleanup_old_rate_limits() TO postgres;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE api_rate_limits IS 'Tracks API request rates to prevent abuse';
COMMENT ON FUNCTION check_rate_limit IS 'Check if user has exceeded rate limit for endpoint';
COMMENT ON FUNCTION check_rate_limit_by_ip IS 'Check rate limit by IP address for anonymous users';
COMMENT ON FUNCTION cleanup_old_rate_limits IS 'Cleanup old rate limit records (run hourly)';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Rate limiting system installed!';
    RAISE NOTICE '🛡️ Protection against API abuse';
    RAISE NOTICE '⚡ Fast lookups with optimized indexes';
    RAISE NOTICE '🔒 Endpoint-specific limits configured';
END $$;
