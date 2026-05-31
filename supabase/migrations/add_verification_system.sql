-- =====================================================
-- VERIFICATION & FRAUD PREVENTION SYSTEM
-- =====================================================
-- Critical for real estate platform security

-- Create verifications table
CREATE TABLE IF NOT EXISTS verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    verification_type TEXT NOT NULL CHECK (verification_type IN (
        'landlord_identity',
        'agency_registration',
        'property_ownership',
        'student_id',
        'national_id'
    )),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected', 'expired')),
    documents JSONB, -- Array of document URLs
    document_metadata JSONB, -- Document types, upload dates, etc.
    submitted_data JSONB, -- Additional verification data
    reviewed_by UUID REFERENCES profiles(id),
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    notes TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create fraud reports table
CREATE TABLE IF NOT EXISTS fraud_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reported_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    reported_property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    report_type TEXT NOT NULL CHECK (report_type IN (
        'fake_listing',
        'fake_landlord',
        'scam',
        'duplicate_listing',
        'inappropriate_content',
        'harassment',
        'other'
    )),
    reason TEXT NOT NULL,
    description TEXT,
    evidence JSONB, -- Screenshots, URLs, etc.
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'dismissed')),
    resolution TEXT,
    resolved_by UUID REFERENCES profiles(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create user trust scores table
CREATE TABLE IF NOT EXISTS user_trust_scores (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    trust_score INTEGER DEFAULT 50 CHECK (trust_score >= 0 AND trust_score <= 100),
    verification_count INTEGER DEFAULT 0,
    successful_transactions INTEGER DEFAULT 0,
    fraud_reports_received INTEGER DEFAULT 0,
    fraud_reports_confirmed INTEGER DEFAULT 0,
    account_age_days INTEGER DEFAULT 0,
    last_calculated TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_verifications_user ON verifications(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_verifications_status ON verifications(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_verifications_type ON verifications(verification_type, status);

CREATE INDEX IF NOT EXISTS idx_fraud_reports_reported_user ON fraud_reports(reported_user_id, status);
CREATE INDEX IF NOT EXISTS idx_fraud_reports_property ON fraud_reports(reported_property_id, status);
CREATE INDEX IF NOT EXISTS idx_fraud_reports_status ON fraud_reports(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trust_scores_score ON user_trust_scores(trust_score DESC);

-- Enable RLS
ALTER TABLE verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_trust_scores ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own verifications"
    ON verifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own verifications"
    ON verifications FOR INSERT
    WITH CHECK (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "Users can view own fraud reports"
    ON fraud_reports FOR SELECT
    USING (auth.uid() = reporter_id OR auth.uid() = reported_user_id);

CREATE POLICY "Users can create fraud reports"
    ON fraud_reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can view own trust score"
    ON user_trust_scores FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view trust scores"
    ON user_trust_scores FOR SELECT
    USING (true);

-- =====================================================
-- VERIFICATION FUNCTIONS
-- =====================================================

-- Submit verification request
CREATE OR REPLACE FUNCTION submit_verification(
    p_verification_type TEXT,
    p_documents JSONB,
    p_submitted_data JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_verification_id UUID;
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    -- Check rate limit (max 3 pending verifications)
    IF (SELECT COUNT(*) FROM verifications 
        WHERE user_id = v_user_id AND status = 'pending') >= 3 THEN
        RAISE EXCEPTION 'Maximum pending verifications reached';
    END IF;
    
    -- Create verification request
    INSERT INTO verifications (
        user_id,
        verification_type,
        documents,
        submitted_data,
        status
    ) VALUES (
        v_user_id,
        p_verification_type,
        p_documents,
        p_submitted_data,
        'pending'
    ) RETURNING id INTO v_verification_id;
    
    -- Log audit
    PERFORM log_audit(
        'verification_submitted',
        'verification',
        v_verification_id,
        NULL,
        jsonb_build_object('type', p_verification_type)
    );
    
    RETURN v_verification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Approve verification (admin function)
CREATE OR REPLACE FUNCTION approve_verification(
    p_verification_id UUID,
    p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_verification RECORD;
BEGIN
    -- Get verification
    SELECT * INTO v_verification
    FROM verifications
    WHERE id = p_verification_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Verification not found';
    END IF;
    
    -- Update verification
    UPDATE verifications
    SET 
        status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        notes = p_notes,
        expires_at = NOW() + INTERVAL '1 year',
        updated_at = NOW()
    WHERE id = p_verification_id;
    
    -- Update profile verification status
    IF v_verification.verification_type = 'landlord_identity' THEN
        UPDATE profiles
        SET id_verified = true
        WHERE id = v_verification.user_id;
    ELSIF v_verification.verification_type = 'student_id' THEN
        UPDATE profiles
        SET student_id_verified = true
        WHERE id = v_verification.user_id;
    END IF;
    
    -- Update trust score
    PERFORM update_trust_score(v_verification.user_id);
    
    -- Log audit
    PERFORM log_audit(
        'verification_approved',
        'verification',
        p_verification_id,
        jsonb_build_object('status', 'pending'),
        jsonb_build_object('status', 'approved')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reject verification (admin function)
CREATE OR REPLACE FUNCTION reject_verification(
    p_verification_id UUID,
    p_rejection_reason TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE verifications
    SET 
        status = 'rejected',
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        rejection_reason = p_rejection_reason,
        updated_at = NOW()
    WHERE id = p_verification_id;
    
    -- Log audit
    PERFORM log_audit(
        'verification_rejected',
        'verification',
        p_verification_id,
        jsonb_build_object('status', 'pending'),
        jsonb_build_object('status', 'rejected', 'reason', p_rejection_reason)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FRAUD REPORTING FUNCTIONS
-- =====================================================

-- Submit fraud report
CREATE OR REPLACE FUNCTION submit_fraud_report(
    p_report_type TEXT,
    p_reason TEXT,
    p_reported_user_id UUID DEFAULT NULL,
    p_reported_property_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_evidence JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_report_id UUID;
BEGIN
    -- Must report either user or property
    IF p_reported_user_id IS NULL AND p_reported_property_id IS NULL THEN
        RAISE EXCEPTION 'Must specify either reported_user_id or reported_property_id';
    END IF;
    
    -- Check rate limit (max 5 reports per day)
    IF (SELECT COUNT(*) FROM fraud_reports 
        WHERE reporter_id = auth.uid() 
        AND created_at > NOW() - INTERVAL '1 day') >= 5 THEN
        RAISE EXCEPTION 'Maximum daily fraud reports reached';
    END IF;
    
    -- Create fraud report
    INSERT INTO fraud_reports (
        reporter_id,
        reported_user_id,
        reported_property_id,
        report_type,
        reason,
        description,
        evidence
    ) VALUES (
        auth.uid(),
        p_reported_user_id,
        p_reported_property_id,
        p_report_type,
        p_reason,
        p_description,
        p_evidence
    ) RETURNING id INTO v_report_id;
    
    -- Update trust score of reported user
    IF p_reported_user_id IS NOT NULL THEN
        UPDATE user_trust_scores
        SET 
            fraud_reports_received = fraud_reports_received + 1,
            updated_at = NOW()
        WHERE user_id = p_reported_user_id;
        
        PERFORM update_trust_score(p_reported_user_id);
    END IF;
    
    -- Log audit
    PERFORM log_audit(
        'fraud_report_submitted',
        'fraud_report',
        v_report_id,
        NULL,
        jsonb_build_object('type', p_report_type)
    );
    
    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TRUST SCORE CALCULATION
-- =====================================================

CREATE OR REPLACE FUNCTION update_trust_score(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_score INTEGER := 50; -- Base score
    v_verification_count INTEGER;
    v_account_age_days INTEGER;
    v_fraud_reports INTEGER;
    v_fraud_confirmed INTEGER;
BEGIN
    -- Get user data
    SELECT 
        (SELECT COUNT(*) FROM verifications WHERE user_id = p_user_id AND status = 'approved'),
        EXTRACT(DAY FROM NOW() - created_at)::INTEGER,
        0, -- transactions not implemented yet
        0  -- fraud confirmed not implemented yet
    INTO v_verification_count, v_account_age_days
    FROM profiles
    WHERE id = p_user_id;
    
    -- Get fraud reports
    SELECT COUNT(*) INTO v_fraud_reports
    FROM fraud_reports
    WHERE reported_user_id = p_user_id;
    
    -- Calculate score
    -- +10 points per verification (max +30)
    v_score := v_score + LEAST(v_verification_count * 10, 30);
    
    -- +1 point per week of account age (max +20)
    v_score := v_score + LEAST((v_account_age_days / 7), 20);
    
    -- -15 points per fraud report (max -45)
    v_score := v_score - LEAST(v_fraud_reports * 15, 45);
    
    -- Ensure score is between 0 and 100
    v_score := GREATEST(0, LEAST(100, v_score));
    
    -- Update or insert trust score
    INSERT INTO user_trust_scores (
        user_id,
        trust_score,
        verification_count,
        fraud_reports_received,
        account_age_days
    ) VALUES (
        p_user_id,
        v_score,
        v_verification_count,
        v_fraud_reports,
        v_account_age_days
    )
    ON CONFLICT (user_id) DO UPDATE SET
        trust_score = v_score,
        verification_count = v_verification_count,
        fraud_reports_received = v_fraud_reports,
        account_age_days = v_account_age_days,
        last_calculated = NOW(),
        updated_at = NOW();
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION submit_verification(TEXT, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_fraud_report(TEXT, TEXT, UUID, UUID, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION update_trust_score(UUID) TO authenticated;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE verifications IS 'User and property verification requests';
COMMENT ON TABLE fraud_reports IS 'Fraud and abuse reports';
COMMENT ON TABLE user_trust_scores IS 'User trust and reputation scores';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Verification & fraud prevention system installed!';
    RAISE NOTICE '🔐 Identity verification enabled';
    RAISE NOTICE '🚨 Fraud reporting system active';
    RAISE NOTICE '⭐ Trust score calculation implemented';
    RAISE NOTICE '🛡️ Platform security enhanced';
END $$;
