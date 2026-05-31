-- =====================================================
-- FREE PROMOTIONAL VIDEOS SYSTEM
-- =====================================================
-- Landlords get 1-2 FREE promotional videos when listing a property
-- These videos appear in Explore feed for 7 days
-- Run this AFTER add_engagement_tracking.sql

-- Table: Free promotional videos
CREATE TABLE IF NOT EXISTS free_promotional_videos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  landlord_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_url TEXT NOT NULL,
  video_order INTEGER DEFAULT 1, -- 1 or 2 (max 2 videos per property)
  status TEXT DEFAULT 'pending', -- pending, approved, rejected, expired
  rejection_reason TEXT,
  
  -- Promotion period
  starts_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  
  -- Analytics
  impressions INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  shares INTEGER DEFAULT 0,
  contacts INTEGER DEFAULT 0,
  avg_watch_time INTEGER DEFAULT 0, -- in seconds
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approved_at TIMESTAMP WITH TIME ZONE,
  approved_by UUID REFERENCES auth.users(id),
  
  CONSTRAINT fk_property FOREIGN KEY (property_id) REFERENCES properties(id),
  CONSTRAINT fk_landlord FOREIGN KEY (landlord_id) REFERENCES auth.users(id),
  CONSTRAINT valid_video_order CHECK (video_order IN (1, 2)),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'approved', 'rejected', 'expired'))
);

-- Index for active promotions (most important - used by Explore feed)
CREATE INDEX IF NOT EXISTS idx_free_promos_active ON free_promotional_videos(status, expires_at) 
  WHERE status = 'approved';

-- Index for landlord's videos
CREATE INDEX IF NOT EXISTS idx_free_promos_landlord ON free_promotional_videos(landlord_id, created_at DESC);

-- Index for property's videos
CREATE INDEX IF NOT EXISTS idx_free_promos_property ON free_promotional_videos(property_id);

-- Index for pending reviews (admin dashboard)
CREATE INDEX IF NOT EXISTS idx_free_promos_pending ON free_promotional_videos(created_at DESC)
  WHERE status = 'pending';

-- Enable Row Level Security
ALTER TABLE free_promotional_videos ENABLE ROW LEVEL SECURITY;

-- Policy: Landlords can insert their own videos
CREATE POLICY "Landlords can create free promos" ON free_promotional_videos
  FOR INSERT
  WITH CHECK (auth.uid() = landlord_id);

-- Policy: Landlords can read their own videos
CREATE POLICY "Landlords can read own promos" ON free_promotional_videos
  FOR SELECT
  USING (auth.uid() = landlord_id);

-- Policy: Anyone can read approved videos (for Explore feed)
CREATE POLICY "Anyone can read approved promos" ON free_promotional_videos
  FOR SELECT
  USING (status = 'approved');

-- Policy: Admins can update any video
-- Note: Replace with proper admin check when user_roles table exists
CREATE POLICY "Admins can update promos" ON free_promotional_videos
  FOR UPDATE
  USING (auth.uid() = landlord_id); -- For now, landlords can update their own

-- Policy: Admins can delete any video
-- Note: Replace with proper admin check when user_roles table exists
CREATE POLICY "Admins can delete promos" ON free_promotional_videos
  FOR DELETE
  USING (auth.uid() = landlord_id); -- For now, landlords can delete their own

-- Function: Auto-approve and set expiry for free promotional videos
CREATE OR REPLACE FUNCTION auto_approve_free_promo()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Auto-approve if landlord is verified
  IF EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = NEW.property_id AND p.landlord_verified = true
  ) THEN
    NEW.status := 'approved';
    NEW.starts_at := NOW();
    NEW.expires_at := NOW() + INTERVAL '7 days';
    NEW.approved_at := NOW();
  ELSE
    -- Pending review for unverified landlords
    NEW.status := 'pending';
  END IF;
  
  RETURN NEW;
END;
$$;

-- Trigger: Auto-approve on insert
DROP TRIGGER IF EXISTS trigger_auto_approve_free_promo ON free_promotional_videos;
CREATE TRIGGER trigger_auto_approve_free_promo
  BEFORE INSERT ON free_promotional_videos
  FOR EACH ROW
  EXECUTE FUNCTION auto_approve_free_promo();

-- Function: Expire old promotional videos
CREATE OR REPLACE FUNCTION expire_old_promos()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET status = 'expired'
  WHERE status = 'approved'
    AND expires_at < NOW();
END;
$$;

-- Schedule: Run expiry check daily (requires pg_cron extension)
-- Uncomment if pg_cron is enabled:
-- SELECT cron.schedule('expire-old-promos', '0 0 * * *', 'SELECT expire_old_promos()');

-- Function: Get active free promotional videos for Explore feed
CREATE OR REPLACE FUNCTION get_active_free_promos(limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  property_id UUID,
  video_url TEXT,
  video_order INTEGER,
  property_title TEXT,
  property_price NUMERIC,
  property_location TEXT,
  property_type TEXT,
  property_bedrooms INTEGER,
  property_bathrooms INTEGER,
  landlord_name TEXT,
  landlord_verified BOOLEAN,
  landlord_phone TEXT,
  impressions INTEGER,
  views INTEGER,
  likes INTEGER,
  expires_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fpv.id,
    fpv.property_id,
    fpv.video_url,
    fpv.video_order,
    p.title AS property_title,
    p.price AS property_price,
    p.location AS property_location,
    p.property_type,
    p.bedrooms AS property_bedrooms,
    p.bathrooms AS property_bathrooms,
    p.landlord_name,
    p.landlord_verified,
    p.landlord_phone,
    fpv.impressions,
    fpv.views,
    fpv.likes,
    fpv.expires_at
  FROM free_promotional_videos fpv
  JOIN properties p ON fpv.property_id = p.id
  WHERE fpv.status = 'approved'
    AND fpv.expires_at > NOW()
    AND p.status = 'active'
    AND p.available = true
  ORDER BY fpv.created_at DESC
  LIMIT limit_count;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_active_free_promos(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_free_promos(INTEGER) TO anon;

-- Function: Get landlord's promotional videos
CREATE OR REPLACE FUNCTION get_landlord_promos(landlord_uuid UUID)
RETURNS TABLE (
  id UUID,
  property_id UUID,
  property_title TEXT,
  video_url TEXT,
  video_order INTEGER,
  status TEXT,
  starts_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  impressions INTEGER,
  views INTEGER,
  likes INTEGER,
  shares INTEGER,
  contacts INTEGER,
  avg_watch_time INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fpv.id,
    fpv.property_id,
    p.title AS property_title,
    fpv.video_url,
    fpv.video_order,
    fpv.status,
    fpv.starts_at,
    fpv.expires_at,
    fpv.impressions,
    fpv.views,
    fpv.likes,
    fpv.shares,
    fpv.contacts,
    fpv.avg_watch_time,
    fpv.created_at
  FROM free_promotional_videos fpv
  JOIN properties p ON fpv.property_id = p.id
  WHERE fpv.landlord_id = landlord_uuid
  ORDER BY fpv.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_landlord_promos(UUID) TO authenticated;

-- Function: Track free promo impression (shown in feed)
CREATE OR REPLACE FUNCTION track_free_promo_impression(promo_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET impressions = impressions + 1
  WHERE id = promo_id;
END;
$$;

-- Function: Track free promo view (watched 2+ seconds)
CREATE OR REPLACE FUNCTION track_free_promo_view(promo_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET views = views + 1
  WHERE id = promo_id;
END;
$$;

-- Function: Track free promo like
CREATE OR REPLACE FUNCTION track_free_promo_like(promo_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET likes = likes + 1
  WHERE id = promo_id;
END;
$$;

-- Function: Track free promo share
CREATE OR REPLACE FUNCTION track_free_promo_share(promo_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET shares = shares + 1
  WHERE id = promo_id;
END;
$$;

-- Function: Track free promo contact
CREATE OR REPLACE FUNCTION track_free_promo_contact(promo_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET contacts = contacts + 1
  WHERE id = promo_id;
END;
$$;

-- Grant execute permissions for tracking functions
GRANT EXECUTE ON FUNCTION track_free_promo_impression(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_free_promo_impression(UUID) TO anon;
GRANT EXECUTE ON FUNCTION track_free_promo_view(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_free_promo_view(UUID) TO anon;
GRANT EXECUTE ON FUNCTION track_free_promo_like(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_free_promo_share(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_free_promo_contact(UUID) TO authenticated;

-- Function: Approve free promo (admin action)
CREATE OR REPLACE FUNCTION approve_free_promo(promo_id UUID, admin_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET 
    status = 'approved',
    starts_at = NOW(),
    expires_at = NOW() + INTERVAL '7 days',
    approved_at = NOW(),
    approved_by = admin_id
  WHERE id = promo_id;
END;
$$;

-- Function: Reject free promo (admin action)
CREATE OR REPLACE FUNCTION reject_free_promo(promo_id UUID, reason TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE free_promotional_videos
  SET 
    status = 'rejected',
    rejection_reason = reason
  WHERE id = promo_id;
END;
$$;

-- Grant execute permissions for admin functions
GRANT EXECUTE ON FUNCTION approve_free_promo(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_free_promo(UUID, TEXT) TO authenticated;

-- Function: Get pending promos for admin review
CREATE OR REPLACE FUNCTION get_pending_promos()
RETURNS TABLE (
  id UUID,
  property_id UUID,
  property_title TEXT,
  landlord_id UUID,
  landlord_name TEXT,
  video_url TEXT,
  video_order INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fpv.id,
    fpv.property_id,
    p.title AS property_title,
    fpv.landlord_id,
    p.landlord_name,
    fpv.video_url,
    fpv.video_order,
    fpv.created_at
  FROM free_promotional_videos fpv
  JOIN properties p ON fpv.property_id = p.id
  WHERE fpv.status = 'pending'
  ORDER BY fpv.created_at ASC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_pending_promos() TO authenticated;

-- Function: Get promo statistics (admin dashboard)
CREATE OR REPLACE FUNCTION get_promo_statistics()
RETURNS TABLE (
  total_promos BIGINT,
  active_promos BIGINT,
  pending_promos BIGINT,
  expired_promos BIGINT,
  rejected_promos BIGINT,
  total_impressions BIGINT,
  total_views BIGINT,
  total_likes BIGINT,
  total_contacts BIGINT,
  avg_watch_time NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT AS total_promos,
    COUNT(*) FILTER (WHERE status = 'approved' AND expires_at > NOW())::BIGINT AS active_promos,
    COUNT(*) FILTER (WHERE status = 'pending')::BIGINT AS pending_promos,
    COUNT(*) FILTER (WHERE status = 'expired')::BIGINT AS expired_promos,
    COUNT(*) FILTER (WHERE status = 'rejected')::BIGINT AS rejected_promos,
    COALESCE(SUM(impressions), 0)::BIGINT AS total_impressions,
    COALESCE(SUM(views), 0)::BIGINT AS total_views,
    COALESCE(SUM(likes), 0)::BIGINT AS total_likes,
    COALESCE(SUM(contacts), 0)::BIGINT AS total_contacts,
    COALESCE(AVG(NULLIF(avg_watch_time, 0)), 0)::NUMERIC AS avg_watch_time
  FROM free_promotional_videos;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_promo_statistics() TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE free_promotional_videos IS 'Free promotional videos for landlords - 1-2 videos per property, active for 7 days';
COMMENT ON COLUMN free_promotional_videos.video_order IS 'Order of video (1 or 2) - max 2 videos per property';
COMMENT ON COLUMN free_promotional_videos.status IS 'pending: awaiting approval, approved: live in Explore, rejected: not approved, expired: 7 days passed';
COMMENT ON COLUMN free_promotional_videos.impressions IS 'Number of times video was shown in feed';
COMMENT ON COLUMN free_promotional_videos.views IS 'Number of times video was watched for 2+ seconds';
COMMENT ON FUNCTION get_active_free_promos IS 'Get all active free promotional videos for Explore feed';
COMMENT ON FUNCTION track_free_promo_impression IS 'Increment impression count when video appears in feed';
COMMENT ON FUNCTION track_free_promo_view IS 'Increment view count when video is watched for 2+ seconds';
COMMENT ON FUNCTION expire_old_promos IS 'Mark expired promos as expired (run daily via cron)';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Free promotional videos system installed successfully!';
  RAISE NOTICE '📊 Table created: free_promotional_videos';
  RAISE NOTICE '🔍 Indexes created: 4 indexes for performance';
  RAISE NOTICE '🔒 RLS policies created: 5 policies for security';
  RAISE NOTICE '⚙️ Functions created: 12 functions for operations';
  RAISE NOTICE '🎯 Ready to use! Landlords can now upload free promotional videos.';
END $$;
