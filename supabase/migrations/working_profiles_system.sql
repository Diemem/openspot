-- =====================================================
-- WORKING PROFILES SYSTEM (COMPATIBLE WITH EXISTING SCHEMA)
-- =====================================================
-- This migration works with your existing tables and adds scalability features

-- =====================================================
-- 1. ENSURE PROFILES TABLE HAS ALL NEEDED COLUMNS
-- =====================================================

-- Add missing columns to profiles table (from enhance_profiles.sql)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS university TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS budget_min INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS budget_max INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_verified BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS student_id_verified BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 0.00;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- =====================================================
-- 2. CREATE SCALABLE STATS TABLES
-- =====================================================

-- Profile stats (precomputed for fast queries)
CREATE TABLE IF NOT EXISTS profile_stats (
  profile_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  total_properties INTEGER DEFAULT 0,
  total_views BIGINT DEFAULT 0,
  total_reviews INTEGER DEFAULT 0,
  rating NUMERIC(3,2) DEFAULT 0.00,
  total_contacts BIGINT DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Profile view aggregation (instead of storing every view)
CREATE TABLE IF NOT EXISTS profile_view_stats (
  profile_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  total_views BIGINT DEFAULT 0,
  views_today INTEGER DEFAULT 0,
  views_this_week INTEGER DEFAULT 0,
  views_this_month INTEGER DEFAULT 0,
  last_viewed TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Phone verification (structured, not in JSON)
CREATE TABLE IF NOT EXISTS phone_verifications (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  attempts INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_location ON profiles(location) WHERE location IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_university ON profiles(university) WHERE university IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_verified ON profiles(id_verified, student_id_verified);
CREATE INDEX IF NOT EXISTS idx_profiles_active ON profiles(last_active DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_completed ON profiles(profile_completed) WHERE profile_completed = true;

-- Profile stats indexes
CREATE INDEX IF NOT EXISTS idx_profile_stats_rating ON profile_stats(rating DESC) WHERE rating > 0;
CREATE INDEX IF NOT EXISTS idx_profile_stats_properties ON profile_stats(total_properties DESC) WHERE total_properties > 0;

-- Phone verification indexes
CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone ON phone_verifications(phone);
CREATE INDEX IF NOT EXISTS idx_phone_verifications_expires ON phone_verifications(expires_at DESC);

-- =====================================================
-- 4. ENABLE ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE profile_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_view_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE phone_verifications ENABLE ROW LEVEL SECURITY;

-- Profile stats policies
CREATE POLICY "Users can read all profile stats" ON profile_stats
  FOR SELECT USING (true);

-- Profile view stats policies  
CREATE POLICY "Users can read all view stats" ON profile_view_stats
  FOR SELECT USING (true);

-- Phone verification policies
CREATE POLICY "Users can manage own phone verification" ON phone_verifications
  FOR ALL USING (user_id = auth.uid());

-- =====================================================
-- 5. ESSENTIAL FUNCTIONS ONLY
-- =====================================================

-- Function: Get profile with precomputed stats (FAST)
CREATE OR REPLACE FUNCTION get_profile_with_stats(user_id UUID)
RETURNS TABLE (
  id UUID,
  role TEXT,
  phone TEXT,
  phone_verified BOOLEAN,
  photo_url TEXT,
  bio TEXT,
  location TEXT,
  university TEXT,
  budget_min INTEGER,
  budget_max INTEGER,
  email_verified BOOLEAN,
  id_verified BOOLEAN,
  student_id_verified BOOLEAN,
  rating NUMERIC,
  total_reviews INTEGER,
  profile_completed BOOLEAN,
  total_properties INTEGER,
  total_views BIGINT,
  total_contacts BIGINT,
  created_at TIMESTAMP WITH TIME ZONE,
  last_active TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.role,
    p.phone,
    p.phone_verified,
    p.photo_url,
    p.bio,
    p.location,
    p.university,
    p.budget_min,
    p.budget_max,
    p.email_verified,
    p.id_verified,
    p.student_id_verified,
    COALESCE(ps.rating, p.rating, 0.00) as rating,
    COALESCE(ps.total_reviews, p.total_reviews, 0) as total_reviews,
    p.profile_completed,
    COALESCE(ps.total_properties, 0) as total_properties,
    COALESCE(ps.total_views, 0) as total_views,
    COALESCE(ps.total_contacts, 0) as total_contacts,
    p.created_at,
    p.last_active
  FROM profiles p
  LEFT JOIN profile_stats ps ON ps.profile_id = p.id
  WHERE p.id = user_id;
END;
$$;

-- Function: Send phone verification
CREATE OR REPLACE FUNCTION send_phone_verification(user_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  verification_code TEXT;
BEGIN
  -- Generate 6-digit code
  verification_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  
  -- Store in structured table
  INSERT INTO phone_verifications (user_id, phone, code, expires_at)
  VALUES (auth.uid(), user_phone, verification_code, NOW() + INTERVAL '10 minutes')
  ON CONFLICT (user_id) DO UPDATE SET
    phone = user_phone,
    code = verification_code,
    expires_at = NOW() + INTERVAL '10 minutes',
    attempts = 0,
    created_at = NOW();
  
  -- TODO: Integrate with SMS provider (Africa's Talking, Twilio)
  -- For now, return the code (REMOVE IN PRODUCTION!)
  RETURN verification_code;
END;
$$;

-- Function: Verify phone code (simple version)
CREATE OR REPLACE FUNCTION verify_phone_code(input_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if code exists and is valid
  IF EXISTS (
    SELECT 1 FROM phone_verifications 
    WHERE user_id = auth.uid() 
    AND code = input_code 
    AND expires_at > NOW() 
    AND attempts < 3
  ) THEN
    -- Update profile with phone from verification
    UPDATE profiles 
    SET phone_verified = true, 
        phone = (SELECT phone FROM phone_verifications WHERE user_id = auth.uid())
    WHERE id = auth.uid();
    
    -- Delete verification record
    DELETE FROM phone_verifications WHERE user_id = auth.uid();
    
    RETURN true;
  ELSE
    -- Increment attempts if record exists
    UPDATE phone_verifications 
    SET attempts = attempts + 1 
    WHERE user_id = auth.uid();
    
    RETURN false;
  END IF;
END;
$$;

-- Function: Track profile view (aggregated)
CREATE OR REPLACE FUNCTION track_profile_view(viewer_profile_id UUID, viewed_profile_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update aggregated stats
  INSERT INTO profile_view_stats (profile_id, total_views, views_today, views_this_week, views_this_month, last_viewed)
  VALUES (viewed_profile_id, 1, 1, 1, 1, NOW())
  ON CONFLICT (profile_id) DO UPDATE SET
    total_views = profile_view_stats.total_views + 1,
    views_today = CASE 
      WHEN DATE_TRUNC('day', profile_view_stats.last_viewed) = DATE_TRUNC('day', NOW()) 
      THEN profile_view_stats.views_today + 1 
      ELSE 1 
    END,
    views_this_week = CASE 
      WHEN profile_view_stats.last_viewed > NOW() - INTERVAL '7 days' 
      THEN profile_view_stats.views_this_week + 1 
      ELSE 1 
    END,
    views_this_month = CASE 
      WHEN profile_view_stats.last_viewed > NOW() - INTERVAL '30 days' 
      THEN profile_view_stats.views_this_month + 1 
      ELSE 1 
    END,
    last_viewed = NOW(),
    updated_at = NOW();
    
  -- Update profile stats
  INSERT INTO profile_stats (profile_id, total_views)
  VALUES (viewed_profile_id, 1)
  ON CONFLICT (profile_id) DO UPDATE SET
    total_views = profile_stats.total_views + 1,
    updated_at = NOW();
END;
$$;

-- =====================================================
-- 6. SIMPLE TRIGGERS
-- =====================================================

-- Profile completion trigger
CREATE OR REPLACE FUNCTION check_profile_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Simple completion check
  NEW.profile_completed := (
    NEW.role IS NOT NULL 
    AND NEW.phone IS NOT NULL 
    AND NEW.photo_url IS NOT NULL 
    AND NEW.bio IS NOT NULL
    AND (NEW.role != 'landlord' OR NEW.phone_verified = true)
  );
  
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

-- Update last active trigger
CREATE OR REPLACE FUNCTION update_profile_last_active()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NEW.last_active := NOW();
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

-- Create triggers
DROP TRIGGER IF EXISTS trigger_check_profile_completion ON profiles;
CREATE TRIGGER trigger_check_profile_completion
  BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION check_profile_completion();

DROP TRIGGER IF EXISTS trigger_update_profile_last_active ON profiles;
CREATE TRIGGER trigger_update_profile_last_active
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_last_active();

-- =====================================================
-- 7. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION get_profile_with_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_profile_view(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION send_phone_verification(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_phone_code(TEXT) TO authenticated;

-- =====================================================
-- 8. COMMENTS
-- =====================================================

COMMENT ON TABLE profile_stats IS 'Precomputed profile statistics for fast queries';
COMMENT ON TABLE profile_view_stats IS 'Aggregated profile view statistics';
COMMENT ON TABLE phone_verifications IS 'Structured phone verification codes';

COMMENT ON FUNCTION get_profile_with_stats(UUID) IS 'Fast profile lookup with precomputed stats';
COMMENT ON FUNCTION track_profile_view(UUID, UUID) IS 'Efficient profile view tracking';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ WORKING PROFILES SYSTEM INSTALLED!';
  RAISE NOTICE '📊 Enhanced profiles table with all needed columns';
  RAISE NOTICE '⚡ Added scalable stats tables';
  RAISE NOTICE '🔍 Created performance indexes';
  RAISE NOTICE '⚙️ Added essential functions only';
  RAISE NOTICE '🎯 Compatible with existing schema!';
END $$;