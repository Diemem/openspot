-- =====================================================
-- PAYMENTS SYSTEM FOR SPONSORED CONTENT
-- =====================================================
-- Adds payment tracking for featured listings and promotional video boosts
-- This is the ONLY missing piece for launch

-- Add featured_until column to properties (for expiring featured status)
ALTER TABLE properties ADD COLUMN IF NOT EXISTS featured_until TIMESTAMP WITH TIME ZONE;

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  package_type TEXT NOT NULL CHECK (package_type IN ('featured_7_days', 'featured_30_days', 'promotional_video')),
  amount NUMERIC(10,2) NOT NULL,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('mpesa', 'card', 'bank_transfer')),
  phone_number TEXT,
  transaction_id TEXT UNIQUE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for payments
CREATE INDEX IF NOT EXISTS idx_payments_property ON payments(property_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id) WHERE transaction_id IS NOT NULL;

-- Index for featured properties with expiry
CREATE INDEX IF NOT EXISTS idx_properties_featured_until ON properties(featured_until) WHERE featured = true;

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Payments policies
DROP POLICY IF EXISTS "Users can manage own payments" ON payments;
CREATE POLICY "Users can manage own payments" ON payments
  FOR ALL USING (auth.uid() = user_id);

-- Function: Expire featured properties
CREATE OR REPLACE FUNCTION expire_featured_properties()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE properties
  SET featured = false
  WHERE featured = true
    AND featured_until IS NOT NULL
    AND featured_until < NOW();
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION expire_featured_properties() TO authenticated;

-- Comments
COMMENT ON TABLE payments IS 'Payment tracking for featured listings and promotional video boosts';
COMMENT ON COLUMN properties.featured_until IS 'Timestamp when featured status expires (NULL = permanent)';
COMMENT ON FUNCTION expire_featured_properties IS 'Expire featured properties past their featured_until date (run daily via cron)';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ PAYMENTS SYSTEM INSTALLED!';
  RAISE NOTICE '💳 Table created: payments';
  RAISE NOTICE '⭐ Column added: properties.featured_until';
  RAISE NOTICE '🔍 Indexes created: 5 indexes for performance';
  RAISE NOTICE '🔒 RLS policies created: 1 policy for security';
  RAISE NOTICE '⚙️ Function created: expire_featured_properties()';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 OPENSPOT IS NOW READY FOR LAUNCH!';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Run this migration in Supabase';
  RAISE NOTICE '   2. Test payment flow end-to-end';
  RAISE NOTICE '   3. Integrate M-Pesa Daraja API';
  RAISE NOTICE '   4. Set up cron job to expire featured properties';
END $$;
