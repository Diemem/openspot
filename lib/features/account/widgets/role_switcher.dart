import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/role_provider.dart';

class RoleSwitcher extends ConsumerWidget {
  const RoleSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableRoles = ref.watch(availableRolesProvider);
    final activeRole = ref.watch(activeRoleProvider);

    return availableRoles.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) {
        debugPrint('Role switcher error: $error');
        return const SizedBox.shrink();
      },
      data: (roles) {
        debugPrint('Available roles: $roles');
        // Show role switcher even with single role for testing
        // Remove this condition later: if (roles.length <= 1) return const SizedBox.shrink();
        if (roles.isEmpty) {
          // Show a message that user only has one role
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Role Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You currently have a single role. When you become a caretaker for other landlords or join an agency, you\'ll be able to switch between roles here.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Switch Role',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roles.map((role) {
                    final isActive = activeRole == role || (activeRole == null && role == roles.first);
                    return _buildRoleChip(
                      context,
                      ref,
                      role,
                      isActive,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleChip(BuildContext context, WidgetRef ref, String role, bool isActive) {
    IconData icon;
    String label;
    Color color;

    switch (role) {
      case 'landlord':
        icon = Icons.home_work;
        label = 'Landlord';
        color = Colors.blue;
        break;
      case 'caretaker':
        icon = Icons.person;
        label = 'Caretaker';
        color = Colors.green;
        break;
      case 'agency':
        icon = Icons.business;
        label = 'Agency';
        color = Colors.purple;
        break;
      default:
        icon = Icons.person;
        label = role;
        color = Colors.grey;
    }

    return FilterChip(
      selected: isActive,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(activeRoleProvider.notifier).state = role;
          _navigateToRole(context, role);
        }
      },
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : color,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _navigateToRole(BuildContext context, String role) {
    switch (role) {
      case 'landlord':
        context.go('/landlord');
        break;
      case 'caretaker':
        _showCaretakerSelection(context);
        break;
      case 'agency':
        context.go('/agency');
        break;
    }
  }

  void _showCaretakerSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _CaretakerSelectionSheet(),
    );
  }
}

class _CaretakerSelectionSheet extends ConsumerWidget {
  const _CaretakerSelectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(caretakerAssignmentsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Landlord',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose which landlord\'s properties you want to manage',
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          assignments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
            data: (assignmentsList) {
              if (assignmentsList.isEmpty) {
                return const Text('No active caretaker assignments');
              }

              return Column(
                children: assignmentsList.map((assignment) {
                  final landlord = assignment['landlord'] as Map<String, dynamic>?;
                  final landlordName = landlord?['full_name'] ?? 'Unknown';
                  final landlordEmail = landlord?['email'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(landlordName[0].toUpperCase()),
                    ),
                    title: Text(landlordName),
                    subtitle: Text(landlordEmail),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to caretaker dashboard for this landlord
                      context.go('/caretaker-dashboard/${assignment['landlord_id']}');
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
