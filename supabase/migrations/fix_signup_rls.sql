-- ============================================================
-- FIX: Allow profile creation during signup
-- This fixes the ERR_CONNECTION_RESET error during signup
-- ============================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;

-- Allow authenticated users to insert their own profile
-- This is needed for the signup trigger to work
CREATE POLICY "profiles_insert_authenticated" 
  ON profiles 
  FOR INSERT 
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Also allow the service role (used by triggers) to insert
CREATE POLICY "profiles_insert_service" 
  ON profiles 
  FOR INSERT 
  TO service_role
  WITH CHECK (true);

-- Ensure the trigger function has proper permissions
ALTER FUNCTION handle_new_user() SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON profiles TO service_role;

-- Verify RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Test: This should now work
-- When a user signs up, the trigger will create their profile successfully
