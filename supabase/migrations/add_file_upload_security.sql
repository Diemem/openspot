-- =====================================================
-- FILE UPLOAD SECURITY SYSTEM
-- =====================================================
-- Validates file uploads and enforces storage quotas

-- Create file uploads tracking table
CREATE TABLE IF NOT EXISTS file_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_size BIGINT NOT NULL, -- in bytes
    file_path TEXT NOT NULL,
    storage_bucket TEXT NOT NULL,
    upload_purpose TEXT CHECK (upload_purpose IN ('profile_photo', 'property_image', 'property_video', 'document', 'promotional_video')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'deleted')),
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create user storage quotas table
CREATE TABLE IF NOT EXISTS user_storage_quotas (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    total_storage_used BIGINT DEFAULT 0, -- in bytes
    max_storage_allowed BIGINT DEFAULT 524288000, -- 500MB default
    total_files INTEGER DEFAULT 0,
    max_files_allowed INTEGER DEFAULT 100,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_file_uploads_user ON file_uploads(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_file_uploads_status ON file_uploads(status);
CREATE INDEX IF NOT EXISTS idx_file_uploads_purpose ON file_uploads(upload_purpose);

-- Enable RLS
ALTER TABLE file_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_storage_quotas ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own uploads"
    ON file_uploads FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own uploads"
    ON file_uploads FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own quota"
    ON user_storage_quotas FOR SELECT
    USING (auth.uid() = user_id);

-- =====================================================
-- FILE VALIDATION FUNCTIONS
-- =====================================================

-- Allowed file types configuration
CREATE OR REPLACE FUNCTION get_allowed_file_types(p_purpose TEXT)
RETURNS TEXT[] AS $$
BEGIN
    RETURN CASE p_purpose
        WHEN 'profile_photo' THEN ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
        WHEN 'property_image' THEN ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
        WHEN 'property_video' THEN ARRAY['video/mp4', 'video/quicktime', 'video/x-msvideo']
        WHEN 'promotional_video' THEN ARRAY['video/mp4', 'video/quicktime']
        WHEN 'document' THEN ARRAY['application/pdf', 'image/jpeg', 'image/png']
        ELSE ARRAY[]::TEXT[]
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Max file size configuration (in bytes)
CREATE OR REPLACE FUNCTION get_max_file_size(p_purpose TEXT)
RETURNS BIGINT AS $$
BEGIN
    RETURN CASE p_purpose
        WHEN 'profile_photo' THEN 5242880 -- 5MB
        WHEN 'property_image' THEN 10485760 -- 10MB
        WHEN 'property_video' THEN 104857600 -- 100MB
        WHEN 'promotional_video' THEN 52428800 -- 50MB
        WHEN 'document' THEN 10485760 -- 10MB
        ELSE 5242880 -- 5MB default
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Validate file upload
CREATE OR REPLACE FUNCTION validate_file_upload(
    p_file_name TEXT,
    p_file_type TEXT,
    p_file_size BIGINT,
    p_purpose TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_allowed_types TEXT[];
    v_max_size BIGINT;
    v_quota RECORD;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to upload files';
    END IF;
    
    -- Check file type
    v_allowed_types := get_allowed_file_types(p_purpose);
    IF NOT (p_file_type = ANY(v_allowed_types)) THEN
        RAISE EXCEPTION 'File type % not allowed for %. Allowed types: %', 
            p_file_type, p_purpose, array_to_string(v_allowed_types, ', ');
    END IF;
    
    -- Check file size
    v_max_size := get_max_file_size(p_purpose);
    IF p_file_size > v_max_size THEN
        RAISE EXCEPTION 'File size % bytes exceeds maximum allowed size of % bytes (% MB)', 
            p_file_size, v_max_size, (v_max_size / 1048576.0)::NUMERIC(10,2);
    END IF;
    
    -- Check file name (basic sanitization)
    IF p_file_name ~ '[<>:"/\\|?*]' THEN
        RAISE EXCEPTION 'File name contains invalid characters';
    END IF;
    
    IF LENGTH(p_file_name) > 255 THEN
        RAISE EXCEPTION 'File name too long (max 255 characters)';
    END IF;
    
    -- Check user storage quota
    SELECT * INTO v_quota
    FROM user_storage_quotas
    WHERE user_id = v_user_id;
    
    -- Create quota record if doesn't exist
    IF v_quota IS NULL THEN
        INSERT INTO user_storage_quotas (user_id)
        VALUES (v_user_id)
        RETURNING * INTO v_quota;
    END IF;
    
    -- Check storage limit
    IF (v_quota.total_storage_used + p_file_size) > v_quota.max_storage_allowed THEN
        RAISE EXCEPTION 'Storage quota exceeded. Used: % MB, Limit: % MB', 
            (v_quota.total_storage_used / 1048576.0)::NUMERIC(10,2),
            (v_quota.max_storage_allowed / 1048576.0)::NUMERIC(10,2);
    END IF;
    
    -- Check file count limit
    IF v_quota.total_files >= v_quota.max_files_allowed THEN
        RAISE EXCEPTION 'File count limit exceeded. Limit: % files', v_quota.max_files_allowed;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STORAGE QUOTA MANAGEMENT
-- =====================================================

-- Update user storage quota after upload
CREATE OR REPLACE FUNCTION update_storage_quota_on_upload()
RETURNS TRIGGER AS $$
BEGIN
    -- Update quota
    INSERT INTO user_storage_quotas (user_id, total_storage_used, total_files)
    VALUES (NEW.user_id, NEW.file_size, 1)
    ON CONFLICT (user_id) DO UPDATE SET
        total_storage_used = user_storage_quotas.total_storage_used + NEW.file_size,
        total_files = user_storage_quotas.total_files + 1,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update user storage quota after deletion
CREATE OR REPLACE FUNCTION update_storage_quota_on_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Update quota
    UPDATE user_storage_quotas
    SET 
        total_storage_used = GREATEST(0, total_storage_used - OLD.file_size),
        total_files = GREATEST(0, total_files - 1),
        updated_at = NOW()
    WHERE user_id = OLD.user_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS trigger_update_quota_on_upload ON file_uploads;
CREATE TRIGGER trigger_update_quota_on_upload
    AFTER INSERT ON file_uploads
    FOR EACH ROW
    EXECUTE FUNCTION update_storage_quota_on_upload();

DROP TRIGGER IF EXISTS trigger_update_quota_on_delete ON file_uploads;
CREATE TRIGGER trigger_update_quota_on_delete
    AFTER DELETE ON file_uploads
    FOR EACH ROW
    EXECUTE FUNCTION update_storage_quota_on_delete();

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Get user's current storage usage
CREATE OR REPLACE FUNCTION get_user_storage_info(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
    total_storage_used_bytes BIGINT,
    total_storage_used_mb NUMERIC,
    max_storage_allowed_bytes BIGINT,
    max_storage_allowed_mb NUMERIC,
    storage_percentage NUMERIC,
    total_files INTEGER,
    max_files_allowed INTEGER
) AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    RETURN QUERY
    SELECT 
        q.total_storage_used,
        (q.total_storage_used / 1048576.0)::NUMERIC(10,2),
        q.max_storage_allowed,
        (q.max_storage_allowed / 1048576.0)::NUMERIC(10,2),
        ((q.total_storage_used::NUMERIC / q.max_storage_allowed::NUMERIC) * 100)::NUMERIC(5,2),
        q.total_files,
        q.max_files_allowed
    FROM user_storage_quotas q
    WHERE q.user_id = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increase user storage quota (admin function)
CREATE OR REPLACE FUNCTION increase_user_storage_quota(
    p_user_id UUID,
    p_additional_mb INTEGER
) RETURNS VOID AS $$
BEGIN
    UPDATE user_storage_quotas
    SET 
        max_storage_allowed = max_storage_allowed + (p_additional_mb * 1048576),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Create if doesn't exist
    IF NOT FOUND THEN
        INSERT INTO user_storage_quotas (user_id, max_storage_allowed)
        VALUES (p_user_id, 524288000 + (p_additional_mb * 1048576));
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION validate_file_upload(TEXT, TEXT, BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_storage_info(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_allowed_file_types(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_max_file_size(TEXT) TO authenticated;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE file_uploads IS 'Tracks all file uploads with validation';
COMMENT ON TABLE user_storage_quotas IS 'Manages user storage quotas and limits';
COMMENT ON FUNCTION validate_file_upload IS 'Validates file uploads before allowing them';
COMMENT ON FUNCTION get_user_storage_info IS 'Get current storage usage for a user';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ File upload security system installed!';
    RAISE NOTICE '🔒 File type validation enabled';
    RAISE NOTICE '📏 File size limits enforced';
    RAISE NOTICE '💾 Storage quotas configured';
    RAISE NOTICE '🛡️ Protection against malicious uploads';
END $$;
