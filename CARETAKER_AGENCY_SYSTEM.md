# 🏢 Caretaker & Agency Management System

## Overview

OpenSpot now supports a comprehensive multi-role property management system with three distinct user types:

1. **Landlords** - Property owners who can delegate management
2. **Caretakers** - Trusted individuals who manage properties for landlords
3. **Agencies** - Professional real estate agencies managing properties for multiple landlords

---

## 🎯 System Architecture

### Database Schema

#### 1. **Caretakers Table**
Tracks caretakers assigned to landlords with granular permissions:

```sql
- landlord_id: UUID (references profiles)
- caretaker_id: UUID (references profiles)
- can_edit_properties: BOOLEAN
- can_add_properties: BOOLEAN
- can_delete_properties: BOOLEAN
- can_view_analytics: BOOLEAN
- can_respond_to_inquiries: BOOLEAN
- status: TEXT ('active', 'suspended', 'removed')
```

#### 2. **Agencies Table**
Stores agency business information:

```sql
- owner_id: UUID (references profiles)
- agency_name: TEXT
- agency_license: TEXT
- agency_phone: TEXT
- agency_email: TEXT
- agency_address: TEXT
- status: TEXT ('active', 'suspended', 'inactive')
- verified: BOOLEAN
```

#### 3. **Agency Clients Table**
Tracks landlords whose properties are managed by agencies:

```sql
- agency_id: UUID (references agencies)
- landlord_id: UUID (references profiles)
- contract_start_date: DATE
- contract_end_date: DATE
- commission_rate: DECIMAL
- can_edit_properties: BOOLEAN
- can_add_properties: BOOLEAN
- can_delete_properties: BOOLEAN
- status: TEXT ('active', 'suspended', 'terminated')
```

#### 4. **Agency Staff Table**
Tracks staff members working for agencies:

```sql
- agency_id: UUID (references agencies)
- staff_id: UUID (references profiles)
- staff_role: TEXT ('manager', 'agent', 'assistant')
- can_manage_properties: BOOLEAN
- can_manage_clients: BOOLEAN
- can_view_analytics: BOOLEAN
- status: TEXT ('active', 'suspended', 'removed')
```

#### 5. **Property Activity Log**
Audit trail for accountability:

```sql
- property_id: UUID
- user_id: UUID
- action: TEXT ('created', 'updated', 'deleted', etc.)
- changes: JSONB
- acting_as: TEXT ('landlord', 'caretaker', 'agency')
```

---

## 👥 User Roles & Permissions

### Landlord
**Full Control** - Owns properties and can:
- ✅ Add/Edit/Delete their own properties
- ✅ Assign caretakers with custom permissions
- ✅ View all analytics and financial data
- ✅ Manage promotional videos
- ✅ Respond to inquiries
- ✅ Hire agencies to manage properties

### Caretaker
**Delegated Access** - Manages properties on behalf of landlord:
- ✅ Edit properties (if permitted)
- ✅ Add new properties (if permitted)
- ✅ Delete properties (if permitted)
- ✅ View analytics (if permitted)
- ✅ Respond to inquiries (if permitted)
- ❌ Cannot change landlord's personal information
- ❌ Cannot remove themselves as caretaker

**Dashboard**: Same as landlord dashboard but with restricted actions based on permissions

### Agency
**Multi-Client Management** - Manages properties for multiple landlords:
- ✅ Manage multiple client accounts
- ✅ Add/manage staff members
- ✅ Edit/Add properties for clients (based on contract)
- ✅ View aggregated analytics across all clients
- ✅ Respond to inquiries on behalf of clients
- ❌ Cannot access client's financial information (unless permitted)

**Dashboard**: Dedicated agency dashboard with client overview

---

## 🚀 Features Implemented

### For Landlords

#### 1. **Manage Caretakers Screen** (`/manage-caretakers`)
- View all assigned caretakers
- Add new caretakers by email
- Edit caretaker permissions
- Remove/suspend caretakers
- See caretaker status (active/suspended/removed)

**Permissions you can grant:**
- Can Edit Properties
- Can Add Properties
- Can Delete Properties
- Can View Analytics
- Can Respond to Inquiries

#### 2. **Landlord Dashboard Updates**
- New "Manage Caretakers" button in Quick Actions
- Shows caretaker activity in recent activity feed

### For Agencies

#### 1. **Agency Setup Screen**
First-time agency creation with:
- Agency name
- License number
- Contact information (phone, email)
- Office address

#### 2. **Agency Dashboard** (`/agency-dashboard`)
- Overview stats (clients, properties, staff, views)
- Quick actions:
  - Manage Clients
  - Manage Staff
  - View Properties
  - Analytics

#### 3. **Manage Clients** (To be implemented)
- Add landlords as clients
- Set contract terms (commission rate, dates)
- Define permissions per client
- View client properties

#### 4. **Manage Staff** (To be implemented)
- Add staff members (managers, agents, assistants)
- Assign roles and permissions
- Track staff activity

### For Caretakers

#### 1. **Caretaker Dashboard**
- Uses the same landlord dashboard interface
- Actions are filtered based on granted permissions
- Shows "Acting as Caretaker for [Landlord Name]" indicator
- Cannot access landlord's personal profile settings

---

## 🔐 Security & Access Control

### Row Level Security (RLS)
All tables have RLS policies ensuring:
- Landlords can only manage their own caretakers
- Caretakers can only view their assignments
- Agencies can only manage their own clients and staff
- Property access is validated through helper functions

### Helper Functions

#### `can_manage_property(property_uuid, user_uuid)`
Returns TRUE if user can manage the property as:
- Property owner (landlord)
- Active caretaker with edit permissions
- Agency staff managing the landlord's properties

#### `get_user_role_for_property(property_uuid, user_uuid)`
Returns the user's role context:
- 'landlord' - Property owner
- 'caretaker' - Assigned caretaker
- 'agency' - Agency staff member
- NULL - No access

---

## 📱 User Flows

### Landlord Assigns a Caretaker

1. Landlord goes to Dashboard → "Manage Caretakers"
2. Clicks "Add Caretaker"
3. Enters caretaker's email (must be registered user)
4. Selects permissions to grant
5. Clicks "Add"
6. Caretaker receives notification (future feature)
7. Caretaker can now access landlord's properties

### Agency Onboards a Client

1. Agency owner creates agency profile
2. Goes to "Manage Clients"
3. Adds landlord by email
4. Sets contract terms (commission, dates)
5. Defines permissions
6. Landlord receives invitation (future feature)
7. Landlord accepts
8. Agency can now manage landlord's properties

### Caretaker Manages Properties

1. Caretaker logs in
2. Sees landlord dashboard with restricted actions
3. Can edit properties (if permitted)
4. All changes are logged with "acting_as: caretaker"
5. Landlord can view activity log

---

## 🛠️ Implementation Status

### ✅ Completed
- [x] Database schema and migrations
- [x] RLS policies and security functions
- [x] Caretaker management screen
- [x] Agency dashboard foundation
- [x] Agency setup flow
- [x] Permission system architecture
- [x] Activity logging structure

### 🚧 To Be Implemented
- [ ] Agency client management screen
- [ ] Agency staff management screen
- [ ] Caretaker dashboard with role indicator
- [ ] Property access control in edit screens
- [ ] Activity log viewer
- [ ] Notifications for assignments
- [ ] Contract management for agencies
- [ ] Commission tracking
- [ ] Multi-agency support (landlord can hire multiple agencies)
- [ ] Caretaker invitation system
- [ ] Agency verification process

---

## 🔄 Migration Instructions

### Step 1: Run the Migration
```bash
# In Supabase SQL Editor, run:
supabase/migrations/add_caretaker_agency_system.sql
```

### Step 2: Update Routing
Add these routes to your router configuration:

```dart
GoRoute(
  path: '/manage-caretakers',
  builder: (context, state) => const ManageCaretakersScreen(),
),
GoRoute(
  path: '/agency-dashboard',
  builder: (context, state) => const AgencyDashboardScreen(),
),
```

### Step 3: Update Profile Role Logic
In `account_screen.dart`, check for `sub_role`:

```dart
final subRole = profileData['sub_role'] as String?;

if (subRole == 'agency') {
  return const AgencyDashboardScreen();
} else if (role == 'landlord') {
  return _LandlordAccountScreen(...);
}
```

---

## 📊 Future Enhancements

### Phase 2
- Real-time notifications for caretaker assignments
- In-app messaging between landlords and caretakers
- Performance metrics for caretakers
- Agency commission calculator
- Bulk property import for agencies

### Phase 3
- Multi-language support for international agencies
- White-label agency portals
- API access for third-party integrations
- Advanced analytics dashboard
- Automated contract renewals

---

## 🐛 Known Limitations

1. **Single Agency per Landlord**: Currently, a landlord can only work with one agency at a time
2. **No Invitation System**: Caretakers/clients must already be registered users
3. **No Commission Tracking**: Commission rates are stored but not calculated
4. **No Contract Enforcement**: Contract dates are informational only
5. **Limited Activity Log**: Only property changes are logged, not all actions

---

## 💡 Best Practices

### For Landlords
- Grant minimal permissions to caretakers initially
- Regularly review caretaker activity logs
- Use agencies for professional management of large portfolios
- Keep caretaker list updated (remove inactive ones)

### For Agencies
- Clearly define contract terms with clients
- Assign specific properties to specific staff members
- Regularly audit staff permissions
- Maintain professional communication with clients

### For Caretakers
- Only make changes you're authorized to make
- Communicate with landlord before major decisions
- Keep property information accurate and up-to-date
- Respond promptly to inquiries

---

## 📞 Support

For questions or issues with the caretaker/agency system:
1. Check this documentation first
2. Review the database schema in the migration file
3. Check RLS policies if access issues occur
4. Contact the development team

---

## 🎉 Summary

The Caretaker & Agency system transforms OpenSpot from a simple property listing platform into a comprehensive property management ecosystem. Landlords can delegate work, agencies can scale their business, and caretakers can earn by managing properties—all with proper access control and accountability.

**Key Benefits:**
- 🏆 Scalability for landlords with multiple properties
- 🤝 Professional management through agencies
- 🔒 Granular permission control
- 📈 Activity tracking and accountability
- 💼 Business growth opportunities for agencies
