-- =====================================================
-- ENGAGEMENT TRACKING FUNCTIONS
-- =====================================================
-- These functions handle view and like tracking for properties
-- Used by the Explore screen for promotional content analytics

-- Function: Increment property views
-- Called when user views a property for 2+ seconds in Explore feed
CREATE OR REPLACE FUNCTION increment_property_views(property_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE properties
  SET views = views + 1
  WHERE id = property_id;
END;
$$;

-- Function: Increment property likes
-- Called when user favorites/likes a property
CREATE OR REPLACE FUNCTION increment_property_likes(property_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE properties
  SET likes = likes + 1
  WHERE id = property_id;
END;
$$;

-- Function: Decrement property likes
-- Called when user unfavorites/unlikes a property
CREATE OR REPLACE FUNCTION decrement_property_likes(property_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE properties
  SET likes = GREATEST(likes - 1, 0)  -- Prevent negative likes
  WHERE id = property_id;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_property_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_property_likes(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_property_likes(UUID) TO authenticated;

-- Optional: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_properties_views ON properties(views DESC);
CREATE INDEX IF NOT EXISTS idx_properties_likes ON properties(likes DESC);
CREATE INDEX IF NOT EXISTS idx_properties_featured ON properties(featured) WHERE featured = true;

-- =====================================================
-- FREE PROMOTIONAL VIDEOS SYSTEM
-- =====================================================
-- Landlords get 1-2 FREE promotional videos when listing a property
-- These videos appear in Explore feed for 7 days

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

-- Index for active promotions
CREATE INDEX IF NOT EXISTS idx_free_promos_active ON free_promotional_videos(status, expires_at) 
  WHERE status = 'approved' AND expires_at > NOW();

-- Index for landlord's videos
CREATE INDEX IF NOT EXISTS idx_free_promos_landlord ON free_promotional_videos(landlord_id, created_at DESC);

-- Index for property's videos
CREATE INDEX IF NOT EXISTS idx_free_promos_property ON free_promotional_videos(property_id);

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
  USING (status = 'approved' AND expires_at > NOW());

-- Policy: Admins can update any video
CREATE POLICY "Admins can update promos" ON free_promotional_videos
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

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
-- SELECT cron.schedule('expire-old-promos', '0 0 * * *', 'SELECT expire_old_promos()');

-- Function: Get active free promotional videos for Explore feed
CREATE OR REPLACE FUNCTION get_active_free_promos(limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  property_id UUID,
  video_url TEXT,
  property_title TEXT,
  property_price NUMERIC,
  property_location TEXT,
  landlord_name TEXT,
  landlord_verified BOOLEAN,
  impressions INTEGER,
  views INTEGER,
  likes INTEGER
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
    p.title AS property_title,
    p.price AS property_price,
    p.location AS property_location,
    p.landlord_name,
    p.landlord_verified,
    fpv.impressions,
    fpv.views,
    fpv.likes
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

-- Function: Track free promo impression
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

-- Function: Track free promo view (2+ seconds)
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION track_free_promo_impression(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_free_promo_impression(UUID) TO anon;
GRANT EXECUTE ON FUNCTION track_free_promo_view(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION track_free_promo_view(UUID) TO anon;

-- Optional: Add analytics table for detailed tracking (future enhancement)
-- This allows tracking individual view events for analytics dashboard
CREATE TABLE IF NOT EXISTS property_views (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  source TEXT DEFAULT 'explore', -- 'explore', 'home', 'map', 'search'
  session_id TEXT,
  device_type TEXT,
  CONSTRAINT fk_property FOREIGN KEY (property_id) REFERENCES properties(id)
);

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_property_views_property_id ON property_views(property_id);
CREATE INDEX IF NOT EXISTS idx_property_views_viewed_at ON property_views(viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_property_views_user_id ON property_views(user_id);

-- Enable Row Level Security
ALTER TABLE property_views ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert view events (even anonymous users)
CREATE POLICY "Anyone can track views" ON property_views
  FOR INSERT
  WITH CHECK (true);

-- Policy: Users can read their own view history
CREATE POLICY "Users can read own views" ON property_views
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Landlords can read views for their properties
CREATE POLICY "Landlords can read property views" ON property_views
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM properties
      WHERE properties.id = property_views.property_id
      AND properties.landlord_id = auth.uid()
    )
  );

COMMENT ON TABLE property_views IS 'Detailed view tracking for analytics and landlord dashboards';
COMMENT ON FUNCTION increment_property_views IS 'Increments view count when user views property for 2+ seconds';
COMMENT ON FUNCTION increment_property_likes IS 'Increments like count when user favorites property';
COMMENT ON FUNCTION decrement_property_likes IS 'Decrements like count when user unfavorites property';
