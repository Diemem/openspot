-- Add view tracking functionality

-- Function to increment property views
CREATE OR REPLACE FUNCTION increment_property_views(property_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE properties 
  SET views = COALESCE(views, 0) + 1,
      updated_at = NOW()
  WHERE id = property_id;
END;
$$;

-- Function to get property view stats for landlords
CREATE OR REPLACE FUNCTION get_property_view_stats(landlord_user_id UUID)
RETURNS TABLE (
  property_id UUID,
  property_title TEXT,
  total_views BIGINT,
  unique_viewers BIGINT,
  favorites_count BIGINT,
  recent_views BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as property_id,
    p.title as property_title,
    COALESCE(p.views, 0) as total_views,
    COUNT(DISTINCT pv.user_id) as unique_viewers,
    COUNT(CASE WHEN pv.is_favorite = true THEN 1 END) as favorites_count,
    COUNT(CASE WHEN pv.viewed_at > NOW() - INTERVAL '7 days' THEN 1 END) as recent_views
  FROM properties p
  LEFT JOIN property_views pv ON p.id = pv.property_id
  WHERE p.landlord_id = landlord_user_id
  GROUP BY p.id, p.title, p.views
  ORDER BY total_views DESC;
END;
$$;

-- Function to clean up old property views (keep last 100 per user)
CREATE OR REPLACE FUNCTION cleanup_old_property_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Keep only the 100 most recent views per user
  DELETE FROM property_views 
  WHERE id IN (
    SELECT id FROM (
      SELECT id,
             ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY viewed_at DESC) as rn
      FROM property_views
      WHERE viewed_at IS NOT NULL
    ) ranked
    WHERE rn > 100
  );
END;
$$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_property_views_user_viewed 
ON property_views(user_id, viewed_at DESC) 
WHERE viewed_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_property_views_property_recent 
ON property_views(property_id, viewed_at);

-- Create a separate index for recent views (last 30 days) - we'll handle this in queries instead
CREATE INDEX IF NOT EXISTS idx_property_views_recent_timestamp
ON property_views(viewed_at DESC)
WHERE viewed_at IS NOT NULL;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION increment_property_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_property_view_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_property_views() TO service_role;