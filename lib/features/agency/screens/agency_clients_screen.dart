import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Provider for agency clients
final agencyClientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  // Get agency ID
  final agency = await SupabaseService.client
      .from('agencies')
      .select('id')
      .eq('owner_id', userId)
      .single();

  final agencyId = agency['id'];

  // Get clients with landlord details
  final clients = await SupabaseService.client
      .from('agency_clients')
      .select('''
        *,
        landlord:landlord_id (
          id,
          full_name,
          email,
          phone,
          avatar_url
        )
      ''')
      .eq('agency_id', agencyId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(clients);
});

class AgencyClientsScreen extends ConsumerWidget {
  const AgencyClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(agencyClientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddClientDialog(context, ref),
            tooltip: 'Add Client',
          ),
        ],
      ),
      body: clients.when(
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
                onPressed: () => ref.invalidate(agencyClientsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (clientsList) {
          if (clientsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No clients yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add landlords as clients to manage their properties',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddClientDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Client'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyClientsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: clientsList.length,
              itemBuilder: (context, index) {
                final client = clientsList[index];
                final landlord = client['landlord'] as Map<String, dynamic>?;
                final status = client['status'] as String;
                final commissionRate = client['commission_rate'] as num?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: landlord?['avatar_url'] != null
                          ? NetworkImage(landlord!['avatar_url'])
                          : null,
                      child: landlord?['avatar_url'] == null
                          ? Text((landlord?['full_name'] as String? ?? 'U')[0].toUpperCase())
                          : null,
                    ),
                    title: Text(
                      landlord?['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(landlord?['email'] ?? ''),
                        if (commissionRate != null)
                          Text('Commission: $commissionRate%'),
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
                    onTap: () => _showClientDetails(context, ref, client),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddClientDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Client'),
        content: const Text(
          'This feature allows you to add landlords as clients. '
          'You\'ll be able to manage their properties and earn commission.',
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
                const SnackBar(content: Text('Client invitation feature coming soon!')),
              );
            },
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  void _showClientDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> client) {
    final landlord = client['landlord'] as Map<String, dynamic>?;
    
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
              'Client Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text(landlord?['full_name'] ?? 'Unknown'),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(landlord?['email'] ?? 'N/A'),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone'),
              subtitle: Text(landlord?['phone'] ?? 'N/A'),
            ),
            ListTile(
              leading: const Icon(Icons.percent),
              title: const Text('Commission Rate'),
              subtitle: Text('${client['commission_rate'] ?? 0}%'),
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
