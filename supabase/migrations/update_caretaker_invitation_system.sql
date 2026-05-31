-- =====================================================
-- UPDATE CARETAKER SYSTEM TO SUPPORT INVITATIONS
-- =====================================================
-- This migration updates the existing caretaker system
-- to support inviting users who haven't signed up yet
-- =====================================================

-- Step 1: Make caretaker_id nullable (for pending invitations)
ALTER TABLE caretakers 
  ALTER COLUMN caretaker_id DROP NOT NULL;

-- Step 2: Add invitation columns
ALTER TABLE caretakers 
  ADD COLUMN IF NOT EXISTS invited_email TEXT,
  ADD COLUMN IF NOT EXISTS invitation_status TEXT DEFAULT 'pending' CHECK (invitation_status IN ('pending', 'accepted', 'expired')),
  ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ DEFAULT now();

-- Step 3: Drop old unique constraint (if exists)
ALTER TABLE caretakers 
  DROP CONSTRAINT IF EXISTS caretakers_landlord_id_caretaker_id_key;

-- Step 4: Add new constraint - either caretaker_id OR invited_email must be set
ALTER TABLE caretakers 
  DROP CONSTRAINT IF EXISTS caretaker_or_invitation;

ALTER TABLE caretakers 
  ADD CONSTRAINT caretaker_or_invitation CHECK (
    (caretaker_id IS NOT NULL AND invited_email IS NULL) OR
    (caretaker_id IS NULL AND invited_email IS NOT NULL)
  );

-- Step 5: Update existing records to have 'accepted' status
UPDATE caretakers 
SET invitation_status = 'accepted' 
WHERE caretaker_id IS NOT NULL 
  AND invitation_status IS NULL;

-- Step 6: Create index for invited_email lookups
CREATE INDEX IF NOT EXISTS idx_caretakers_invited_email ON caretakers(invited_email) 
WHERE invited_email IS NOT NULL;

-- Step 7: Create or replace the auto-accept function
CREATE OR REPLACE FUNCTION accept_caretaker_invitations()
RETURNS TRIGGER AS $$
BEGIN
  -- Update any pending invitations for this email
  UPDATE caretakers
  SET 
    caretaker_id = NEW.id,
    invited_email = NULL,
    invitation_status = 'accepted',
    assigned_at = now()
  WHERE 
    invited_email = NEW.email
    AND invitation_status = 'pending'
    AND caretaker_id IS NULL;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create trigger (drop first if exists)
DROP TRIGGER IF EXISTS on_profile_created_accept_invitations ON profiles;

CREATE TRIGGER on_profile_created_accept_invitations
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION accept_caretaker_invitations();

-- Step 9: Add comment
COMMENT ON COLUMN caretakers.invited_email IS 'Email address for pending invitations (NULL after acceptance)';
COMMENT ON COLUMN caretakers.invitation_status IS 'Status of invitation: pending, accepted, or expired';

-- =====================================================
-- VERIFICATION QUERIES (Optional - for testing)
-- =====================================================

-- Verify the changes
DO $$
BEGIN
  -- Check if columns exist
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'caretakers' 
    AND column_name = 'invited_email'
  ) THEN
    RAISE NOTICE '✓ Column invited_email added successfully';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'caretakers' 
    AND column_name = 'invitation_status'
  ) THEN
    RAISE NOTICE '✓ Column invitation_status added successfully';
  END IF;

  -- Check if trigger exists
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'on_profile_created_accept_invitations'
  ) THEN
    RAISE NOTICE '✓ Trigger on_profile_created_accept_invitations created successfully';
  END IF;

  -- Check if function exists
  IF EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'accept_caretaker_invitations'
  ) THEN
    RAISE NOTICE '✓ Function accept_caretaker_invitations created successfully';
  END IF;

  RAISE NOTICE '✓ Migration completed successfully!';
END $$;
