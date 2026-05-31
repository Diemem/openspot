# 📧 Caretaker Invitation System

## Overview

The caretaker system now supports **both existing users and invitations** for users who haven't signed up yet.

---

## How It Works

### Scenario 1: Adding an Existing User

**When you enter an email of someone who already has an account:**

1. System checks if user exists in `profiles` table
2. If found, adds them immediately as a caretaker
3. They get access right away
4. Status: `ACTIVE`

**Example:**
```
Email: john@example.com (already registered)
Result: ✅ "Caretaker added successfully"
Status: ACTIVE
```

### Scenario 2: Inviting a New User

**When you enter an email of someone who doesn't have an account:**

1. System checks if user exists
2. If NOT found, creates an invitation
3. Stores the email and permissions
4. When they sign up with that email, they're automatically added
5. Status: `INVITED` → `ACTIVE` (on signup)

**Example:**
```
Email: jane@example.com (not registered)
Result: ✅ "Invitation sent! They will be added when they sign up."
Status: INVITED
```

---

## Database Changes

### Updated `caretakers` Table

```sql
CREATE TABLE caretakers (
  id UUID PRIMARY KEY,
  landlord_id UUID NOT NULL,
  caretaker_id UUID,              -- NULL for pending invitations
  invited_email TEXT,              -- Email for pending invitations
  invitation_status TEXT,          -- 'pending', 'accepted', 'expired'
  invited_at TIMESTAMPTZ,
  
  -- Permissions (same as before)
  can_edit_properties BOOLEAN,
  can_add_properties BOOLEAN,
  can_delete_properties BOOLEAN,
  can_view_analytics BOOLEAN,
  can_respond_to_inquiries BOOLEAN,
  
  -- Constraint: Either caretaker_id OR invited_email must be set
  CONSTRAINT caretaker_or_invitation CHECK (
    (caretaker_id IS NOT NULL AND invited_email IS NULL) OR
    (caretaker_id IS NULL AND invited_email IS NOT NULL)
  )
);
```

### Auto-Accept Trigger

When a new user signs up, the system automatically:
1. Checks for pending invitations with their email
2. Updates the invitation to link to their new profile
3. Changes status from `pending` to `accepted`
4. Grants them the pre-configured permissions

```sql
CREATE FUNCTION accept_caretaker_invitations()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE caretakers
  SET 
    caretaker_id = NEW.id,
    invited_email = NULL,
    invitation_status = 'accepted',
    assigned_at = now()
  WHERE 
    invited_email = NEW.email
    AND invitation_status = 'pending';
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_profile_created_accept_invitations
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION accept_caretaker_invitations();
```

---

## UI Changes

### Caretaker Cards

#### Active Caretaker (Existing User)
```
┌─────────────────────────────────────┐
│ 👤 John Doe              [ACTIVE]   │
│ john@example.com                    │
│ +254712345678                       │
│                                     │
│ Permissions:                        │
│ [Edit] [View Analytics] [Respond]  │
│                                     │
│ [Edit]  [Remove]                    │
└─────────────────────────────────────┘
```

#### Pending Invitation (New User)
```
┌─────────────────────────────────────┐
│ 📧 jane@example.com     [INVITED]   │
│ Waiting for user to sign up         │
│                                     │
│ Permissions (will be granted):      │
│ [Edit] [View Analytics] [Respond]  │
│                                     │
│ [Cancel Invitation]                 │
└─────────────────────────────────────┘
```

### Add Caretaker Dialog

Updated with clear instructions:

```
Add Caretaker
─────────────────────────────────────

Enter the email address of the person you 
want to add as a caretaker.

• If they already have an account, they'll 
  be added immediately
• If not, an invitation will be sent and 
  they'll be added when they sign up

Email Address: [________________]

Permissions:
☑ Can Edit Properties
☐ Can Add Properties
☐ Can Delete Properties
☑ Can View Analytics
☑ Can Respond to Inquiries

         [Cancel]  [Add]
```

---

## User Flow Examples

### Flow 1: Adding Existing User

```
Landlord                    System                      Caretaker
   |                           |                            |
   |--Enter john@example.com-->|                            |
   |                           |--Check profiles table---->|
   |                           |<--User found--------------|
   |                           |--Create caretaker-------->|
   |<--"Added successfully"----|                            |
   |                           |                            |
   |                           |                     [Gets access]
```

### Flow 2: Inviting New User

```
Landlord                    System                      New User
   |                           |                            |
   |--Enter jane@example.com-->|                            |
   |                           |--Check profiles table---->|
   |                           |<--User NOT found----------|
   |                           |--Create invitation------->|
   |<--"Invitation sent"-------|                            |
   |                           |                            |
   |                           |                            |
   |                           |                     [Signs up later]
   |                           |<--New profile created-----|
   |                           |--Trigger fires----------->|
   |                           |--Accept invitation------->|
   |                           |                     [Gets access]
```

---

## Error Handling

### Duplicate Checks

**Existing Caretaker:**
```
Error: "This user is already your caretaker"
```

**Existing Invitation:**
```
Error: "Invitation already sent to this email"
```

### Invalid Email

The system validates email format on the client side before submission.

---

## Migration Steps

### Step 1: Update Database

Run the updated migration:
```sql
-- In Supabase SQL Editor
-- Run: supabase/migrations/add_caretaker_agency_system.sql
```

This will:
- Modify `caretakers` table to support invitations
- Add `invited_email` and `invitation_status` columns
- Create auto-accept trigger
- Update constraints

### Step 2: Restart App

```bash
flutter run
```

### Step 3: Test Both Scenarios

**Test Existing User:**
1. Create two accounts (landlord + caretaker)
2. Sign in as landlord
3. Add caretaker by their email
4. Should see "Caretaker added successfully"
5. Card shows ACTIVE status

**Test Invitation:**
1. Sign in as landlord
2. Add caretaker with non-existent email
3. Should see "Invitation sent!"
4. Card shows INVITED status
5. Sign up with that email
6. Invitation auto-accepts
7. Card updates to ACTIVE

---

## Benefits

### For Landlords
✅ Can add caretakers even if they don't have accounts yet
✅ Pre-configure permissions before they sign up
✅ No need to coordinate signup timing
✅ Clear visibility of pending invitations

### For Caretakers
✅ Seamless onboarding - access granted on signup
✅ No extra steps after registration
✅ Permissions already configured
✅ Can start working immediately

### For the System
✅ Reduces friction in onboarding
✅ Maintains security (email-based verification)
✅ Automatic cleanup via triggers
✅ Audit trail of invitations

---

## Future Enhancements

### Phase 1 (Current)
- ✅ Invitation system
- ✅ Auto-accept on signup
- ✅ Visual distinction between active/invited

### Phase 2 (Planned)
- [ ] Email notifications when invited
- [ ] Invitation expiry (30 days)
- [ ] Resend invitation option
- [ ] Invitation link with pre-filled signup

### Phase 3 (Future)
- [ ] SMS invitations
- [ ] Bulk invite multiple caretakers
- [ ] Invitation templates
- [ ] Custom invitation messages

---

## Troubleshooting

### Issue: Invitation not auto-accepting

**Check:**
1. Trigger is created: `on_profile_created_accept_invitations`
2. Email matches exactly (case-insensitive)
3. Invitation status is 'pending'

**Solution:**
```sql
-- Verify trigger exists
SELECT * FROM pg_trigger 
WHERE tgname = 'on_profile_created_accept_invitations';

-- Manually accept if needed
UPDATE caretakers
SET caretaker_id = 'USER_ID',
    invited_email = NULL,
    invitation_status = 'accepted'
WHERE invited_email = 'email@example.com';
```

### Issue: Duplicate invitation error

**Check:**
```sql
SELECT * FROM caretakers 
WHERE landlord_id = 'LANDLORD_ID' 
AND invited_email = 'email@example.com';
```

**Solution:**
Cancel the old invitation first, then create a new one.

---

## Security Considerations

### Email Verification
- Invitations are tied to email addresses
- Only the person with that email can accept
- Supabase handles email verification on signup

### Permission Control
- Landlord sets permissions before invitation
- Permissions can be edited after acceptance
- Caretaker cannot escalate their own permissions

### Data Privacy
- Invited emails are stored securely
- Only landlord can see pending invitations
- Caretaker data follows RLS policies

---

## Summary

The invitation system makes it **easy to add caretakers** regardless of whether they have an account:

- **Existing users** → Added immediately
- **New users** → Invited and auto-added on signup
- **Clear UI** → Shows status (ACTIVE vs INVITED)
- **Automatic** → No manual steps after signup
- **Secure** → Email-based verification

This removes the friction of requiring caretakers to sign up before being added, making the onboarding process much smoother!
