import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Provider for agency properties
final agencyPropertiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  // Get agency ID
  final agency = await SupabaseService.client
      .from('agencies')
      .select('id')
      .eq('owner_id', userId)
      .single();

  final agencyId = agency['id'];

  // Get properties managed by this agency
  final properties = await SupabaseService.client
      .from('properties')
      .select('*')
      .eq('managed_by_agency_id', agencyId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(properties);
});

class AgencyPropertiesScreen extends ConsumerWidget {
  const AgencyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(agencyPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency Properties'),
      ),
      body: properties.when(
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
                onPressed: () => ref.invalidate(agencyPropertiesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (propertiesList) {
          if (propertiesList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No properties yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Properties managed by your agency will appear here',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyPropertiesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: propertiesList.length,
              itemBuilder: (context, index) {
                final property = propertiesList[index];
                final title = property['title'] as String;
                final location = property['location'] as String;
                final price = property['price'] as num;
                final status = property['status'] as String;
                final views = property['views'] as int? ?? 0;
                final likes = property['likes'] as int? ?? 0;
                final thumbnailUrl = property['thumbnail_url'] as String?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              thumbnailUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.home),
                              ),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.home),
                          ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          'KES ${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.visibility, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('$views', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(width: 12),
                            Icon(Icons.favorite, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('$likes', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusTextColor(status),
                        ),
                      ),
                    ),
                    onTap: () => context.push('/property/${property['id']}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade100;
      case 'pending':
        return Colors.orange.shade100;
      case 'rented':
      case 'sold':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade900;
      case 'pending':
        return Colors.orange.shade900;
      case 'rented':
      case 'sold':
        return Colors.blue.shade900;
      default:
        return Colors.grey.shade700;
    }
  }
}
