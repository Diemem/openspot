# 🚀 Setup Guide: Caretaker & Agency System

## Prerequisites
- ✅ Flutter app is running
- ✅ Supabase project is set up
- ✅ You have access to Supabase SQL Editor

---

## Step 1: Run Database Migration

### Option A: Using Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Copy and Paste Migration**
   - Open the file: `supabase/migrations/add_caretaker_agency_system.sql`
   - Copy ALL the content
   - Paste into the SQL Editor

4. **Run the Migration**
   - Click "Run" button (or press Ctrl+Enter)
   - Wait for success message
   - You should see: "Success. No rows returned"

5. **Verify Tables Created**
   - Go to "Table Editor" in left sidebar
   - You should see new tables:
     - `caretakers`
     - `agencies`
     - `agency_clients`
     - `agency_staff`
     - `property_activity_log`

### Option B: Using Supabase CLI

```bash
# If you have Supabase CLI installed
cd openspot
supabase db push
```

---

## Step 2: Verify Routes Are Working

### Test the Routes

1. **Restart your Flutter app**
   ```bash
   # Stop the app (Ctrl+C)
   # Then run again
   flutter run
   ```

2. **Navigate to Landlord Dashboard**
   - Sign in as a landlord
   - Go to Account tab
   - You should see the landlord dashboard

3. **Click "Manage Caretakers"**
   - Should navigate to `/manage-caretakers`
   - Should show empty state: "No Caretakers Yet"
   - Should have "Add First Caretaker" button

---

## Step 3: Test Adding a Caretaker

### Create a Test Caretaker User

1. **Sign out from your landlord account**

2. **Create a new account** (this will be the caretaker)
   - Email: `caretaker@test.com`
   - Password: `Test123!`
   - Name: `John Caretaker`
   - Role: Regular User (not landlord)

3. **Sign out from caretaker account**

4. **Sign back in as landlord**

### Add the Caretaker

1. **Go to Manage Caretakers**
   - Account → Landlord Dashboard → Manage Caretakers

2. **Click "Add Caretaker" or "Add First Caretaker"**

3. **Enter caretaker email**
   - Email: `caretaker@test.com`

4. **Select permissions**
   - ✅ Can Edit Properties
   - ✅ Can View Analytics
   - ✅ Can Respond to Inquiries
   - ❌ Can Add Properties (optional)
   - ❌ Can Delete Properties (optional)

5. **Click "Add"**
   - Should see success message
   - Caretaker card should appear

---

## Step 4: Test Caretaker Functionality

### View as Caretaker

1. **Sign out from landlord account**

2. **Sign in as caretaker**
   - Email: `caretaker@test.com`
   - Password: `Test123!`

3. **Navigate to Account**
   - Should see landlord dashboard (with restricted actions)
   - Should see properties owned by the landlord
   - Can edit properties (if permission granted)

---

## Step 5: Test Agency Setup

### Create Agency Account

1. **Sign out**

2. **Create new account**
   - Email: `agency@test.com`
   - Password: `Test123!`
   - Name: `Prime Properties Agency`
   - Role: Landlord (agencies are landlords with sub_role)

3. **Navigate to Account**

4. **Go to Agency Dashboard**
   - Should see "Setup Your Agency" screen

5. **Fill in agency details**
   - Agency Name: `Prime Properties Ltd`
   - License Number: `REA-12345` (optional)
   - Phone: `+254712345678`
   - Email: `info@primeproperties.com`
   - Address: `Nairobi, Kenya` (optional)

6. **Click "Create Agency"**
   - Should see success message
   - Should redirect to agency dashboard

---

## Troubleshooting

### Issue: "No route found for /manage-caretakers"

**Solution:**
1. Make sure you've restarted the Flutter app after adding routes
2. Check that the import is correct in `app_router.dart`
3. Run `flutter clean` then `flutter run`

### Issue: "Table 'caretakers' does not exist"

**Solution:**
1. The migration hasn't been run yet
2. Go to Supabase SQL Editor and run the migration
3. Verify tables exist in Table Editor

### Issue: "Not authenticated" error

**Solution:**
1. Make sure you're signed in
2. Check that `SupabaseService.client.auth.currentUser` is not null
3. Try signing out and signing back in

### Issue: "User not found with this email"

**Solution:**
1. Make sure the caretaker user is registered in your app
2. Check the email is correct (no typos)
3. Verify the user exists in Supabase Auth dashboard

### Issue: "This user is already your caretaker"

**Solution:**
1. The caretaker has already been added
2. Check the caretakers list
3. If you want to update permissions, use "Edit" button instead

### Issue: Permission denied when querying caretakers

**Solution:**
1. RLS policies might not be set up correctly
2. Re-run the migration to ensure policies are created
3. Check Supabase logs for specific error

---

## Verification Checklist

After setup, verify these work:

### Landlord Features
- [ ] Can navigate to "Manage Caretakers" from dashboard
- [ ] Can see empty state when no caretakers
- [ ] Can add caretaker by email
- [ ] Can set custom permissions
- [ ] Can view caretaker list with cards
- [ ] Can edit caretaker permissions
- [ ] Can remove caretaker
- [ ] Caretaker status shows correctly (active/suspended/removed)

### Caretaker Features
- [ ] Caretaker can sign in
- [ ] Caretaker sees landlord's properties
- [ ] Caretaker can edit properties (if permitted)
- [ ] Caretaker cannot add properties (if not permitted)
- [ ] Caretaker cannot access landlord's personal info

### Agency Features
- [ ] Can create agency profile
- [ ] Agency dashboard shows correctly
- [ ] Stats display properly (0 initially)
- [ ] Quick actions navigate to placeholder screens

---

## Database Schema Verification

Run this query in Supabase SQL Editor to verify setup:

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('caretakers', 'agencies', 'agency_clients', 'agency_staff', 'property_activity_log');

-- Check if columns exist in profiles
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name = 'sub_role';

-- Check if columns exist in properties
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'properties' 
AND column_name IN ('managed_by_agency_id', 'managed_by_caretaker_id');

-- Check RLS policies
SELECT tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('caretakers', 'agencies', 'agency_clients', 'agency_staff');
```

Expected results:
- 5 tables should be listed
- `sub_role` column should exist in profiles
- 2 new columns should exist in properties
- Multiple RLS policies should be listed

---

## Next Steps After Setup

1. **Test the full flow**
   - Create landlord account
   - Add properties
   - Create caretaker account
   - Add caretaker from landlord dashboard
   - Sign in as caretaker and verify access

2. **Implement remaining features**
   - Agency client management
   - Agency staff management
   - Activity log viewer
   - Notifications

3. **Production considerations**
   - Add email notifications when caretaker is added
   - Add invitation system (send invite before adding)
   - Add activity monitoring dashboard
   - Add contract management for agencies

---

## Support

If you encounter issues:

1. **Check Flutter logs**
   ```bash
   flutter logs
   ```

2. **Check Supabase logs**
   - Go to Supabase Dashboard → Logs
   - Look for errors in API logs

3. **Verify authentication**
   ```dart
   print(SupabaseService.client.auth.currentUser?.id);
   ```

4. **Test database connection**
   ```dart
   final test = await SupabaseService.client.from('profiles').select().limit(1);
   print(test);
   ```

---

## Success Indicators

You'll know the system is working when:

✅ No route errors when navigating to `/manage-caretakers`
✅ Empty state shows correctly
✅ Can add caretaker by email
✅ Caretaker card displays with permissions
✅ Can edit and remove caretakers
✅ Agency setup flow works
✅ No database errors in logs

---

## Quick Commands

```bash
# Restart Flutter app
flutter run

# Clean build
flutter clean
flutter pub get
flutter run

# Check for errors
flutter analyze

# View logs
flutter logs
```

---

## File Locations

- **Migration**: `supabase/migrations/add_caretaker_agency_system.sql`
- **Manage Caretakers Screen**: `lib/features/landlord/screens/manage_caretakers_screen.dart`
- **Agency Dashboard**: `lib/features/agency/screens/agency_dashboard_screen.dart`
- **Router**: `lib/core/router/app_router.dart`
- **Documentation**: `CARETAKER_AGENCY_SYSTEM.md`

---

## Testing Credentials Template

```
LANDLORD ACCOUNT:
Email: landlord@test.com
Password: Test123!

CARETAKER ACCOUNT:
Email: caretaker@test.com
Password: Test123!

AGENCY ACCOUNT:
Email: agency@test.com
Password: Test123!
```

---

🎉 **You're all set!** The caretaker and agency system is now ready to use.
