-- =====================================================
-- AUDIT LOGGING SYSTEM
-- =====================================================
-- Tracks all critical actions for security and compliance

-- Create audit logs table (partitioned for scale)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    old_value JSONB,
    new_value JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id TEXT,
    status TEXT DEFAULT 'success' CHECK (status IN ('success', 'failure', 'error')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create partitions for current and next year
CREATE TABLE IF NOT EXISTS audit_logs_2026 PARTITION OF audit_logs
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE IF NOT EXISTS audit_logs_2027 PARTITION OF audit_logs
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs(status, created_at DESC) WHERE status != 'success';

-- Enable RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own audit logs"
    ON audit_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert audit logs"
    ON audit_logs FOR INSERT
    WITH CHECK (true);

-- =====================================================
-- AUDIT LOGGING FUNCTIONS
-- =====================================================

-- Generic audit log function
CREATE OR REPLACE FUNCTION log_audit(
    p_action TEXT,
    p_resource_type TEXT,
    p_resource_id UUID DEFAULT NULL,
    p_old_value JSONB DEFAULT NULL,
    p_new_value JSONB DEFAULT NULL,
    p_status TEXT DEFAULT 'success',
    p_error_message TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO audit_logs (
        user_id,
        action,
        resource_type,
        resource_id,
        old_value,
        new_value,
        status,
        error_message
    ) VALUES (
        auth.uid(),
        p_action,
        p_resource_type,
        p_resource_id,
        p_old_value,
        p_new_value,
        p_status,
        p_error_message
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- AUTOMATIC AUDIT TRIGGERS
-- =====================================================

-- Audit profile changes
CREATE OR REPLACE FUNCTION audit_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Only log if important fields changed
        IF (OLD.role != NEW.role OR 
            OLD.phone != NEW.phone OR 
            OLD.phone_verified != NEW.phone_verified OR
            OLD.id_verified != NEW.id_verified) THEN
            
            PERFORM log_audit(
                'profile_update',
                'profile',
                NEW.id,
                to_jsonb(OLD),
                to_jsonb(NEW)
            );
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM log_audit(
            'profile_delete',
            'profile',
            OLD.id,
            to_jsonb(OLD),
            NULL
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Audit property changes
CREATE OR REPLACE FUNCTION audit_property_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM log_audit(
            'property_create',
            'property',
            NEW.id,
            NULL,
            jsonb_build_object(
                'title', NEW.title,
                'price', NEW.price,
                'status', NEW.status
            )
        );
    ELSIF TG_OP = 'UPDATE' THEN
        -- Log status changes
        IF OLD.status != NEW.status THEN
            PERFORM log_audit(
                'property_status_change',
                'property',
                NEW.id,
                jsonb_build_object('status', OLD.status),
                jsonb_build_object('status', NEW.status)
            );
        END IF;
        
        -- Log price changes
        IF OLD.price != NEW.price THEN
            PERFORM log_audit(
                'property_price_change',
                'property',
                NEW.id,
                jsonb_build_object('price', OLD.price),
                jsonb_build_object('price', NEW.price)
            );
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM log_audit(
            'property_delete',
            'property',
            OLD.id,
            jsonb_build_object(
                'title', OLD.title,
                'price', OLD.price
            ),
            NULL
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Audit caretaker invitations
CREATE OR REPLACE FUNCTION audit_caretaker_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM log_audit(
            'caretaker_invite',
            'caretaker',
            NEW.id,
            NULL,
            jsonb_build_object(
                'property_id', NEW.property_id,
                'invited_email', NEW.invited_email
            )
        );
    ELSIF TG_OP = 'UPDATE' AND OLD.invitation_status != NEW.invitation_status THEN
        PERFORM log_audit(
            'caretaker_invitation_' || NEW.invitation_status,
            'caretaker',
            NEW.id,
            jsonb_build_object('status', OLD.invitation_status),
            jsonb_build_object('status', NEW.invitation_status)
        );
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM log_audit(
            'caretaker_remove',
            'caretaker',
            OLD.id,
            jsonb_build_object('property_id', OLD.property_id),
            NULL
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS trigger_audit_profile_changes ON profiles;
CREATE TRIGGER trigger_audit_profile_changes
    AFTER UPDATE OR DELETE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION audit_profile_changes();

-- Only create property trigger if table exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'properties') THEN
        DROP TRIGGER IF EXISTS trigger_audit_property_changes ON properties;
        CREATE TRIGGER trigger_audit_property_changes
            AFTER INSERT OR UPDATE OR DELETE ON properties
            FOR EACH ROW
            EXECUTE FUNCTION audit_property_changes();
    END IF;
END $$;

-- Only create caretaker trigger if table exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'caretakers') THEN
        DROP TRIGGER IF EXISTS trigger_audit_caretaker_changes ON caretakers;
        CREATE TRIGGER trigger_audit_caretaker_changes
            AFTER INSERT OR UPDATE OR DELETE ON caretakers
            FOR EACH ROW
            EXECUTE FUNCTION audit_caretaker_changes();
    END IF;
END $$;

-- =====================================================
-- AUDIT QUERY FUNCTIONS
-- =====================================================

-- Get audit trail for a resource
CREATE OR REPLACE FUNCTION get_audit_trail(
    p_resource_type TEXT,
    p_resource_id UUID,
    p_limit INTEGER DEFAULT 50
) RETURNS TABLE (
    id UUID,
    user_id UUID,
    action TEXT,
    old_value JSONB,
    new_value JSONB,
    status TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.user_id,
        a.action,
        a.old_value,
        a.new_value,
        a.status,
        a.created_at
    FROM audit_logs a
    WHERE a.resource_type = p_resource_type
        AND a.resource_id = p_resource_id
    ORDER BY a.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user activity log
CREATE OR REPLACE FUNCTION get_user_activity(
    p_user_id UUID DEFAULT NULL,
    p_days INTEGER DEFAULT 30,
    p_limit INTEGER DEFAULT 100
) RETURNS TABLE (
    id UUID,
    action TEXT,
    resource_type TEXT,
    resource_id UUID,
    status TEXT,
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    RETURN QUERY
    SELECT 
        a.id,
        a.action,
        a.resource_type,
        a.resource_id,
        a.status,
        a.created_at
    FROM audit_logs a
    WHERE a.user_id = v_user_id
        AND a.created_at > NOW() - (p_days || ' days')::INTERVAL
    ORDER BY a.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get failed actions (security monitoring)
CREATE OR REPLACE FUNCTION get_failed_actions(
    p_hours INTEGER DEFAULT 24,
    p_limit INTEGER DEFAULT 100
) RETURNS TABLE (
    id UUID,
    user_id UUID,
    action TEXT,
    resource_type TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.user_id,
        a.action,
        a.resource_type,
        a.error_message,
        a.created_at
    FROM audit_logs a
    WHERE a.status IN ('failure', 'error')
        AND a.created_at > NOW() - (p_hours || ' hours')::INTERVAL
    ORDER BY a.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS VOID AS $$
BEGIN
    -- Delete audit logs older than 2 years
    DELETE FROM audit_logs
    WHERE created_at < NOW() - INTERVAL '2 years';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION log_audit(TEXT, TEXT, UUID, JSONB, JSONB, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_trail(TEXT, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_activity(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_audit_logs() TO postgres;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all critical actions';
COMMENT ON FUNCTION log_audit IS 'Log an audit event';
COMMENT ON FUNCTION get_audit_trail IS 'Get audit history for a specific resource';
COMMENT ON FUNCTION get_user_activity IS 'Get activity log for a user';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Audit logging system installed!';
    RAISE NOTICE '📝 All critical actions will be logged';
    RAISE NOTICE '🔍 Full audit trail available';
    RAISE NOTICE '🛡️ Security monitoring enabled';
    RAISE NOTICE '📊 Partitioned for performance';
END $$;
