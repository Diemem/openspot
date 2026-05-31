import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Provider for agency staff
final agencyStaffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  // Get agency ID
  final agency = await SupabaseService.client
      .from('agencies')
      .select('id')
      .eq('owner_id', userId)
      .single();

  final agencyId = agency['id'];

  // Get staff with profile details
  final staff = await SupabaseService.client
      .from('agency_staff')
      .select('''
        *,
        staff:staff_id (
          id,
          full_name,
          email,
          phone,
          avatar_url
        )
      ''')
      .eq('agency_id', agencyId)
      .order('hired_at', ascending: false);

  return List<Map<String, dynamic>>.from(staff);
});

class AgencyStaffScreen extends ConsumerWidget {
  const AgencyStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(agencyStaffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddStaffDialog(context),
            tooltip: 'Add Staff',
          ),
        ],
      ),
      body: staff.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(agencyStaffProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No staff members yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add agents and assistants to help manage properties',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStaffDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyStaffProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: staffList.length,
              itemBuilder: (context, index) {
                final member = staffList[index];
                final staffProfile = member['staff'] as Map<String, dynamic>?;
                final role = member['staff_role'] as String;
                final status = member['status'] as String;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: staffProfile?['avatar_url'] != null
                          ? NetworkImage(staffProfile!['avatar_url'])
                          : null,
                      child: staffProfile?['avatar_url'] == null
                          ? Text((staffProfile?['full_name'] as String? ?? 'U')[0].toUpperCase())
                          : null,
                    ),
                    title: Text(
                      staffProfile?['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staffProfile?['email'] ?? ''),
                        Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active' ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status == 'active' ? Colors.green.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    onTap: () => _showStaffDetails(context, member),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Staff Member'),
        content: const Text(
          'This feature allows you to add agents, managers, and assistants to your agency team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Staff invitation feature coming soon!')),
              );
            },
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  void _showStaffDetails(BuildContext context, Map<String, dynamic> member) {
    final staffProfile = member['staff'] as Map<String, dynamic>?;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text(staffProfile?['full_name'] ?? 'Unknown'),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(staffProfile?['email'] ?? 'N/A'),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone'),
              subtitle: Text(staffProfile?['phone'] ?? 'N/A'),
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Role'),
              subtitle: Text((member['staff_role'] as String).toUpperCase()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
