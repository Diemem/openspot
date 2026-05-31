-- =====================================================
-- CARETAKER & AGENCY SYSTEM
-- =====================================================
-- This migration adds support for:
-- 1. Caretakers (delegated property managers)
-- 2. Agencies (manage properties for multiple landlords)
-- 3. Property access control and delegation
-- =====================================================

-- Add new roles to profiles
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS sub_role TEXT CHECK (sub_role IN ('caretaker', 'agency', NULL));

-- =====================================================
-- CARETAKERS TABLE
-- =====================================================
-- Tracks caretakers assigned to landlords
CREATE TABLE IF NOT EXISTS caretakers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  landlord_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  caretaker_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Invitation details (for users not yet registered)
  invited_email TEXT,
  invitation_status TEXT DEFAULT 'pending' CHECK (invitation_status IN ('pending', 'accepted', 'expired')),
  invited_at TIMESTAMPTZ DEFAULT now(),
  
  -- Permissions
  can_edit_properties BOOLEAN DEFAULT true,
  can_add_properties BOOLEAN DEFAULT false,
  can_delete_properties BOOLEAN DEFAULT false,
  can_view_analytics BOOLEAN DEFAULT true,
  can_respond_to_inquiries BOOLEAN DEFAULT true,
  
  -- Metadata
  assigned_at TIMESTAMPTZ DEFAULT now(),
  assigned_by UUID REFERENCES profiles(id),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'removed')),
  notes TEXT,
  
  -- Constraints: Either caretaker_id OR invited_email must be set
  CONSTRAINT caretaker_or_invitation CHECK (
    (caretaker_id IS NOT NULL AND invited_email IS NULL) OR
    (caretaker_id IS NULL AND invited_email IS NOT NULL)
  ),
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_caretakers_landlord ON caretakers(landlord_id);
CREATE INDEX IF NOT EXISTS idx_caretakers_caretaker ON caretakers(caretaker_id);
CREATE INDEX IF NOT EXISTS idx_caretakers_status ON caretakers(status);

-- =====================================================
-- AGENCIES TABLE
-- =====================================================
-- Tracks agency information
CREATE TABLE IF NOT EXISTS agencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Agency Details
  agency_name TEXT NOT NULL,
  agency_license TEXT,
  agency_phone TEXT,
  agency_email TEXT,
  agency_address TEXT,
  agency_logo_url TEXT,
  agency_website TEXT,
  
  -- Business Info
  registration_number TEXT,
  tax_id TEXT,
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'inactive')),
  verified BOOLEAN DEFAULT false,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_agencies_owner ON agencies(owner_id);
CREATE INDEX IF NOT EXISTS idx_agencies_status ON agencies(status);

-- =====================================================
-- AGENCY CLIENTS TABLE
-- =====================================================
-- Tracks landlords that agencies manage properties for
CREATE TABLE IF NOT EXISTS agency_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
  landlord_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Agreement Details
  contract_start_date DATE,
  contract_end_date DATE,
  commission_rate DECIMAL(5,2), -- e.g., 10.50 for 10.5%
  
  -- Permissions
  can_edit_properties BOOLEAN DEFAULT true,
  can_add_properties BOOLEAN DEFAULT true,
  can_delete_properties BOOLEAN DEFAULT false,
  can_view_financials BOOLEAN DEFAULT false,
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'terminated')),
  notes TEXT,
  
  -- Constraints
  UNIQUE(agency_id, landlord_id),
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_agency_clients_agency ON agency_clients(agency_id);
CREATE INDEX IF NOT EXISTS idx_agency_clients_landlord ON agency_clients(landlord_id);
CREATE INDEX IF NOT EXISTS idx_agency_clients_status ON agency_clients(status);

-- =====================================================
-- AGENCY STAFF TABLE
-- =====================================================
-- Tracks staff members working for an agency
CREATE TABLE IF NOT EXISTS agency_staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Role & Permissions
  staff_role TEXT DEFAULT 'agent' CHECK (staff_role IN ('manager', 'agent', 'assistant')),
  can_manage_properties BOOLEAN DEFAULT true,
  can_manage_clients BOOLEAN DEFAULT false,
  can_view_analytics BOOLEAN DEFAULT true,
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'removed')),
  hired_at TIMESTAMPTZ DEFAULT now(),
  
  -- Constraints
  UNIQUE(agency_id, staff_id),
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_agency_staff_agency ON agency_staff(agency_id);
CREATE INDEX IF NOT EXISTS idx_agency_staff_staff ON agency_staff(staff_id);

-- =====================================================
-- PROPERTY ACCESS CONTROL
-- =====================================================
-- Add agency tracking to properties
ALTER TABLE properties 
  ADD COLUMN IF NOT EXISTS managed_by_agency_id UUID REFERENCES agencies(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS managed_by_caretaker_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_properties_agency ON properties(managed_by_agency_id);
CREATE INDEX IF NOT EXISTS idx_properties_caretaker ON properties(managed_by_caretaker_id);

-- =====================================================
-- ACTIVITY LOG
-- =====================================================
-- Track who does what (for accountability)
CREATE TABLE IF NOT EXISTS property_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Activity Details
  action TEXT NOT NULL, -- 'created', 'updated', 'deleted', 'published', 'unpublished'
  changes JSONB, -- Store what changed
  acting_as TEXT, -- 'landlord', 'caretaker', 'agency'
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_activity_log_property ON property_activity_log(property_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_user ON property_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_created ON property_activity_log(created_at DESC);

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Caretakers table policies
ALTER TABLE caretakers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Landlords can manage their caretakers"
  ON caretakers FOR ALL
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

CREATE POLICY "Caretakers can view their assignments"
  ON caretakers FOR SELECT
  USING (caretaker_id = auth.uid());

-- Agencies table policies
ALTER TABLE agencies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agency owners can manage their agency"
  ON agencies FOR ALL
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Anyone can view active agencies"
  ON agencies FOR SELECT
  USING (status = 'active');

-- Agency clients table policies
ALTER TABLE agency_clients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agency can manage their clients"
  ON agency_clients FOR ALL
  USING (
    agency_id IN (
      SELECT id FROM agencies WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Landlords can view their agency relationships"
  ON agency_clients FOR SELECT
  USING (landlord_id = auth.uid());

-- Agency staff table policies
ALTER TABLE agency_staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agency owners can manage staff"
  ON agency_staff FOR ALL
  USING (
    agency_id IN (
      SELECT id FROM agencies WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Staff can view their employment"
  ON agency_staff FOR SELECT
  USING (staff_id = auth.uid());

-- Activity log policies
ALTER TABLE property_activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view activity for their properties"
  ON property_activity_log FOR SELECT
  USING (
    property_id IN (
      SELECT id FROM properties WHERE landlord_id = auth.uid()
    )
    OR user_id = auth.uid()
  );

CREATE POLICY "Authenticated users can insert activity logs"
  ON property_activity_log FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to check if user can manage a property
CREATE OR REPLACE FUNCTION can_manage_property(property_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Owner can always manage
  IF EXISTS (
    SELECT 1 FROM properties 
    WHERE id = property_uuid AND landlord_id = user_uuid
  ) THEN
    RETURN TRUE;
  END IF;
  
  -- Check if user is an active caretaker with edit permissions
  IF EXISTS (
    SELECT 1 FROM properties p
    JOIN caretakers c ON c.landlord_id = p.landlord_id
    WHERE p.id = property_uuid 
      AND c.caretaker_id = user_uuid
      AND c.status = 'active'
      AND c.can_edit_properties = true
  ) THEN
    RETURN TRUE;
  END IF;
  
  -- Check if user is agency staff managing this property
  IF EXISTS (
    SELECT 1 FROM properties p
    JOIN agency_clients ac ON ac.landlord_id = p.landlord_id
    JOIN agency_staff ast ON ast.agency_id = ac.agency_id
    WHERE p.id = property_uuid
      AND ast.staff_id = user_uuid
      AND ac.status = 'active'
      AND ast.status = 'active'
      AND ac.can_edit_properties = true
  ) THEN
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's role context for a property
CREATE OR REPLACE FUNCTION get_user_role_for_property(property_uuid UUID, user_uuid UUID)
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Check if owner
  IF EXISTS (
    SELECT 1 FROM properties 
    WHERE id = property_uuid AND landlord_id = user_uuid
  ) THEN
    RETURN 'landlord';
  END IF;
  
  -- Check if caretaker
  IF EXISTS (
    SELECT 1 FROM properties p
    JOIN caretakers c ON c.landlord_id = p.landlord_id
    WHERE p.id = property_uuid 
      AND c.caretaker_id = user_uuid
      AND c.status = 'active'
  ) THEN
    RETURN 'caretaker';
  END IF;
  
  -- Check if agency
  IF EXISTS (
    SELECT 1 FROM properties p
    JOIN agency_clients ac ON ac.landlord_id = p.landlord_id
    JOIN agency_staff ast ON ast.agency_id = ac.agency_id
    WHERE p.id = property_uuid
      AND ast.staff_id = user_uuid
      AND ac.status = 'active'
      AND ast.status = 'active'
  ) THEN
    RETURN 'agency';
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to accept pending caretaker invitations when user signs up
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

-- Trigger to auto-accept invitations on profile creation
DROP TRIGGER IF EXISTS on_profile_created_accept_invitations ON profiles;
CREATE TRIGGER on_profile_created_accept_invitations
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION accept_caretaker_invitations();

-- =====================================================
-- UPDATE TRIGGERS
-- =====================================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_caretakers_updated_at BEFORE UPDATE ON caretakers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agencies_updated_at BEFORE UPDATE ON agencies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agency_clients_updated_at BEFORE UPDATE ON agency_clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agency_staff_updated_at BEFORE UPDATE ON agency_staff
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE caretakers IS 'Tracks caretakers assigned to manage properties for landlords';
COMMENT ON TABLE agencies IS 'Real estate agencies that manage properties for multiple landlords';
COMMENT ON TABLE agency_clients IS 'Landlords whose properties are managed by agencies';
COMMENT ON TABLE agency_staff IS 'Staff members working for agencies';
COMMENT ON TABLE property_activity_log IS 'Audit log of all property changes';
