-- =====================================================
-- ENHANCED PROFILES SYSTEM
-- =====================================================
-- Adds profile photos, phone verification, bio, and more

-- Add new columns to profiles table
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

-- Create index for phone lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone) WHERE phone IS NOT NULL;

-- Create index for verified users
CREATE INDEX IF NOT EXISTS idx_profiles_verified ON profiles(id_verified, student_id_verified);

-- Create index for active users
CREATE INDEX IF NOT EXISTS idx_profiles_active ON profiles(last_active DESC);

-- Function: Update last_active timestamp
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

-- Trigger: Update last_active on profile update
DROP TRIGGER IF EXISTS trigger_update_profile_last_active ON profiles;
CREATE TRIGGER trigger_update_profile_last_active
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_last_active();

-- Function: Check if profile is complete
CREATE OR REPLACE FUNCTION check_profile_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Profile is complete if it has:
  -- 1. Role
  -- 2. Phone (verified for landlords)
  -- 3. Photo
  -- 4. Bio
  
  IF NEW.role IS NOT NULL 
     AND NEW.phone IS NOT NULL 
     AND NEW.photo_url IS NOT NULL 
     AND NEW.bio IS NOT NULL THEN
    
    -- For landlords, require phone verification
    IF NEW.role = 'landlord' THEN
      NEW.profile_completed := NEW.phone_verified;
    ELSE
      NEW.profile_completed := true;
    END IF;
  ELSE
    NEW.profile_completed := false;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Trigger: Check profile completion on update
DROP TRIGGER IF EXISTS trigger_check_profile_completion ON profiles;
CREATE TRIGGER trigger_check_profile_completion
  BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION check_profile_completion();

-- Table: Profile views (who viewed whose profile)
CREATE TABLE IF NOT EXISTS profile_views (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  viewer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_profile_view UNIQUE(viewer_id, profile_id, viewed_at)
);

-- Index for profile views
CREATE INDEX IF NOT EXISTS idx_profile_views_profile ON profile_views(profile_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_views_viewer ON profile_views(viewer_id, viewed_at DESC);

-- Enable RLS
ALTER TABLE profile_views ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert profile views
CREATE POLICY "Anyone can track profile views" ON profile_views
  FOR INSERT
  WITH CHECK (true);

-- Policy: Users can read views of their own profile
CREATE POLICY "Users can read own profile views" ON profile_views
  FOR SELECT
  USING (profile_id = auth.uid());

-- Table: Reviews (landlord reviews from tenants, student reviews from landlords)
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reviewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reviewee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  review_type TEXT NOT NULL CHECK (review_type IN ('landlord_to_tenant', 'tenant_to_landlord')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_review UNIQUE(reviewer_id, reviewee_id, property_id)
);

-- Index for reviews
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON reviews(reviewee_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer ON reviews(reviewer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_property ON reviews(property_id);

-- Enable RLS
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create reviews
CREATE POLICY "Users can create reviews" ON reviews
  FOR INSERT
  WITH CHECK (auth.uid() = reviewer_id);

-- Policy: Anyone can read reviews
CREATE POLICY "Anyone can read reviews" ON reviews
  FOR SELECT
  USING (true);

-- Policy: Users can update their own reviews
CREATE POLICY "Users can update own reviews" ON reviews
  FOR UPDATE
  USING (auth.uid() = reviewer_id);

-- Function: Update profile rating after review
CREATE OR REPLACE FUNCTION update_profile_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  avg_rating NUMERIC;
  review_count INTEGER;
BEGIN
  -- Calculate average rating for the reviewee
  SELECT 
    AVG(rating)::NUMERIC(3,2),
    COUNT(*)::INTEGER
  INTO avg_rating, review_count
  FROM reviews
  WHERE reviewee_id = NEW.reviewee_id;
  
  -- Update profile
  UPDATE profiles
  SET 
    rating = COALESCE(avg_rating, 0.00),
    total_reviews = review_count
  WHERE id = NEW.reviewee_id;
  
  RETURN NEW;
END;
$$;

-- Trigger: Update rating after review insert/update
DROP TRIGGER IF EXISTS trigger_update_rating_insert ON reviews;
CREATE TRIGGER trigger_update_rating_insert
  AFTER INSERT ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_rating();

DROP TRIGGER IF EXISTS trigger_update_rating_update ON reviews;
CREATE TRIGGER trigger_update_rating_update
  AFTER UPDATE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_rating();

-- Function: Get profile with stats
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
  total_properties BIGINT,
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
    p.rating,
    p.total_reviews,
    p.profile_completed,
    COALESCE(COUNT(DISTINCT pr.id), 0) AS total_properties,
    COALESCE(SUM(pr.views), 0) AS total_views,
    0::BIGINT AS total_contacts,
    p.created_at,
    p.last_active
  FROM profiles p
  LEFT JOIN properties pr ON pr.landlord_id = p.id AND pr.status = 'active'
  WHERE p.id = user_id
  GROUP BY p.id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_profile_with_stats(UUID) TO authenticated;

-- Function: Send phone verification code
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
  
  -- Store in user metadata (temporary - in production, use a separate table)
  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object(
      'phone_verification_code', verification_code,
      'phone_verification_expires', NOW() + INTERVAL '10 minutes'
    )
  WHERE id = auth.uid();
  
  -- TODO: Integrate with SMS provider (Twilio, Africa's Talking, etc.)
  -- For now, return the code (REMOVE IN PRODUCTION!)
  RETURN verification_code;
END;
$$;

-- Function: Verify phone code
CREATE OR REPLACE FUNCTION verify_phone_code(code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stored_code TEXT;
  expires_at TIMESTAMP WITH TIME ZONE;
  user_phone TEXT;
BEGIN
  -- Get stored code and expiry
  SELECT 
    raw_user_meta_data->>'phone_verification_code',
    (raw_user_meta_data->>'phone_verification_expires')::TIMESTAMP WITH TIME ZONE,
    raw_user_meta_data->>'phone'
  INTO stored_code, expires_at, user_phone
  FROM auth.users
  WHERE id = auth.uid();
  
  -- Check if code matches and hasn't expired
  IF stored_code = code AND expires_at > NOW() THEN
    -- Update profile
    UPDATE profiles
    SET phone_verified = true, phone = user_phone
    WHERE id = auth.uid();
    
    -- Clear verification code
    UPDATE auth.users
    SET raw_user_meta_data = raw_user_meta_data - 'phone_verification_code' - 'phone_verification_expires'
    WHERE id = auth.uid();
    
    RETURN true;
  ELSE
    RETURN false;
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION send_phone_verification(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_phone_code(TEXT) TO authenticated;

-- Add comments
COMMENT ON COLUMN profiles.phone IS 'User phone number for contacts';
COMMENT ON COLUMN profiles.phone_verified IS 'Whether phone number has been verified via SMS';
COMMENT ON COLUMN profiles.photo_url IS 'Profile photo URL from storage';
COMMENT ON COLUMN profiles.bio IS 'User bio/description';
COMMENT ON COLUMN profiles.rating IS 'Average rating from reviews (0.00 to 5.00)';
COMMENT ON COLUMN profiles.total_reviews IS 'Total number of reviews received';
COMMENT ON COLUMN profiles.profile_completed IS 'Whether profile has all required fields';
