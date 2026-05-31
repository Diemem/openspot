-- =====================================================
-- ENSURE SUB_ROLE COLUMN EXISTS
-- =====================================================
-- This migration ensures the sub_role column exists in profiles table
-- for supporting multiple roles (landlord + agency, etc.)
-- =====================================================

-- Add sub_role column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'profiles' 
    AND column_name = 'sub_role'
  ) THEN
    ALTER TABLE profiles 
      ADD COLUMN sub_role TEXT CHECK (sub_role IN ('caretaker', 'agency', NULL));
    
    RAISE NOTICE 'Added sub_role column to profiles table';
  ELSE
    RAISE NOTICE 'sub_role column already exists in profiles table';
  END IF;
END $$;

-- Create index for sub_role if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_profiles_sub_role ON profiles(sub_role);

-- Update RLS policies to allow users to update their own sub_role
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
