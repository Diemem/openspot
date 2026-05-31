import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Provider to get user's available roles
final availableRolesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) {
    debugPrint('No user ID found');
    return [];
  }

  final roles = <String>[];

  try {
    // Get user's profile
    final profileData = await SupabaseService.client
        .from('profiles')
        .select('role, sub_role')
        .eq('id', userId)
        .maybeSingle();

    debugPrint('Profile data: $profileData');

    if (profileData == null) {
      debugPrint('No profile found for user');
      return [];
    }

    final mainRole = profileData['role'] as String?;
    final subRole = profileData['sub_role'] as String?;

    debugPrint('Main role: $mainRole, Sub role: $subRole');

    // Add main role
    if (mainRole == 'landlord') {
      roles.add('landlord');
    }

    // Check if user is a caretaker for any landlord
    final caretakerRecords = await SupabaseService.client
        .from('caretakers')
        .select('id')
        .eq('caretaker_id', userId)
        .eq('status', 'active');

    debugPrint('Caretaker records: ${caretakerRecords.length}');

    if (caretakerRecords.isNotEmpty) {
      roles.add('caretaker');
    }

    // Check if user owns an agency
    if (subRole == 'agency') {
      roles.add('agency');
    }

    debugPrint('Final roles: $roles');
    return roles;
  } catch (e, stack) {
    debugPrint('Error fetching roles: $e');
    debugPrint('Stack trace: $stack');
    return [];
  }
});

// Provider for current active role (stored in local state)
final activeRoleProvider = StateProvider<String?>((ref) => null);

// Provider to get caretaker assignments
final caretakerAssignmentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return [];

  final assignments = await SupabaseService.client
      .from('caretakers')
      .select('''
        *,
        landlord:landlord_id (
          id,
          full_name,
          email
        )
      ''')
      .eq('caretaker_id', userId)
      .eq('status', 'active');

  return List<Map<String, dynamic>>.from(assignments);
});
