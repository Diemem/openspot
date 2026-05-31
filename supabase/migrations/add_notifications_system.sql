-- =====================================================
-- NOTIFICATIONS SYSTEM
-- =====================================================
-- In-app notifications for caretaker invitations,
-- property updates, and other events
-- =====================================================

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Notification details
  type TEXT NOT NULL CHECK (type IN (
    'caretaker_invitation',
    'caretaker_accepted',
    'caretaker_declined',
    'property_update',
    'inquiry_received',
    'message_received'
  )),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  
  -- Related entities
  related_id UUID, -- ID of related entity (caretaker record, property, etc.)
  related_type TEXT, -- Type of related entity
  
  -- Action data (for actionable notifications)
  action_type TEXT, -- 'accept_decline', 'view', 'navigate'
  action_data JSONB, -- Additional data for the action
  
  -- Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- RLS Policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "System can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

-- =====================================================
-- FUNCTION: Create notification for caretaker invitation
-- =====================================================

CREATE OR REPLACE FUNCTION notify_caretaker_invitation()
RETURNS TRIGGER AS $$
DECLARE
  landlord_name TEXT;
  caretaker_user_id UUID;
BEGIN
  -- Only notify if it's a new invitation to an existing user
  IF NEW.caretaker_id IS NOT NULL AND NEW.invitation_status = 'pending' THEN
    -- Get landlord name
    SELECT full_name INTO landlord_name
    FROM profiles
    WHERE id = NEW.landlord_id;
    
    caretaker_user_id := NEW.caretaker_id;
    
    -- Create notification
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      related_id,
      related_type,
      action_type,
      action_data
    ) VALUES (
      caretaker_user_id,
      'caretaker_invitation',
      'Caretaker Invitation',
      landlord_name || ' has invited you to become a caretaker for their properties.',
      NEW.id,
      'caretaker',
      'accept_decline',
      jsonb_build_object(
        'caretaker_id', NEW.id,
        'landlord_id', NEW.landlord_id,
        'landlord_name', landlord_name
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for caretaker invitations
DROP TRIGGER IF EXISTS on_caretaker_invitation_notify ON caretakers;
CREATE TRIGGER on_caretaker_invitation_notify
  AFTER INSERT ON caretakers
  FOR EACH ROW
  EXECUTE FUNCTION notify_caretaker_invitation();

-- =====================================================
-- FUNCTION: Notify landlord when invitation is accepted
-- =====================================================

CREATE OR REPLACE FUNCTION notify_caretaker_response()
RETURNS TRIGGER AS $$
DECLARE
  caretaker_name TEXT;
BEGIN
  -- Only notify on status change from pending to accepted/declined
  IF OLD.invitation_status = 'pending' AND NEW.invitation_status IN ('accepted', 'declined') THEN
    -- Get caretaker name
    SELECT full_name INTO caretaker_name
    FROM profiles
    WHERE id = NEW.caretaker_id;
    
    -- Notify landlord
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      related_id,
      related_type
    ) VALUES (
      NEW.landlord_id,
      CASE 
        WHEN NEW.invitation_status = 'accepted' THEN 'caretaker_accepted'
        ELSE 'caretaker_declined'
      END,
      CASE 
        WHEN NEW.invitation_status = 'accepted' THEN 'Invitation Accepted'
        ELSE 'Invitation Declined'
      END,
      caretaker_name || ' has ' || NEW.invitation_status || ' your caretaker invitation.',
      NEW.id,
      'caretaker'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for caretaker responses
DROP TRIGGER IF EXISTS on_caretaker_response_notify ON caretakers;
CREATE TRIGGER on_caretaker_response_notify
  AFTER UPDATE ON caretakers
  FOR EACH ROW
  EXECUTE FUNCTION notify_caretaker_response();

-- =====================================================
-- UPDATE: Modify caretakers table for proper invitation flow
-- =====================================================

-- Add status for invitation acceptance
ALTER TABLE caretakers 
  DROP CONSTRAINT IF EXISTS caretakers_status_check;

ALTER TABLE caretakers 
  ADD CONSTRAINT caretakers_status_check 
  CHECK (status IN ('pending', 'active', 'suspended', 'removed', 'declined'));

-- Update invitation_status constraint
ALTER TABLE caretakers 
  DROP CONSTRAINT IF EXISTS caretakers_invitation_status_check;

ALTER TABLE caretakers 
  ADD CONSTRAINT caretakers_invitation_status_check 
  CHECK (invitation_status IN ('pending', 'accepted', 'declined', 'expired'));

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(user_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM notifications
    WHERE user_id = user_uuid AND is_read = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(notification_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = now()
  WHERE id = notification_uuid AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS VOID AS $$
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = now()
  WHERE user_id = auth.uid() AND is_read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE notifications IS 'In-app notifications for users';
COMMENT ON COLUMN notifications.action_type IS 'Type of action: accept_decline, view, navigate';
COMMENT ON COLUMN notifications.action_data IS 'JSON data for the action (e.g., caretaker_id for accept/decline)';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '✓ Notifications table created';
  RAISE NOTICE '✓ RLS policies added';
  RAISE NOTICE '✓ Triggers for caretaker invitations created';
  RAISE NOTICE '✓ Helper functions created';
  RAISE NOTICE '✓ Notification system ready!';
END $$;
