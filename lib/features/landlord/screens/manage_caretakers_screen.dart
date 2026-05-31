import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ManageCaretakersScreen extends ConsumerStatefulWidget {
  const ManageCaretakersScreen({super.key});

  @override
  ConsumerState<ManageCaretakersScreen> createState() => _ManageCaretakersScreenState();
}

class _ManageCaretakersScreenState extends ConsumerState<ManageCaretakersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _caretakers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCaretakers();
  }

  Future<void> _loadCaretakers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final response = await SupabaseService.client
          .from('caretakers')
          .select('''
            *,
            caretaker:caretaker_id (
              id,
              full_name,
              email,
              phone,
              photo_url
            )
          ''')
          .eq('landlord_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _caretakers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addCaretaker() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddCaretakerDialog(),
    );

    if (result != null && mounted) {
      await _loadCaretakers();
      if (mounted) {
        final isInvitation = result['isInvitation'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInvitation
                  ? 'Invitation sent! They will be notified when they sign up.'
                  : 'Invitation sent! They can accept it from their notifications.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editCaretaker(Map<String, dynamic> caretaker) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditCaretakerDialog(caretaker: caretaker),
    );

    if (result == true && mounted) {
      await _loadCaretakers();
    }
  }

  Future<void> _removeCaretaker(String caretakerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Caretaker'),
        content: const Text('Are you sure you want to remove this caretaker? They will lose access to manage your properties.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.client
            .from('caretakers')
            .update({'status': 'removed'})
            .eq('id', caretakerId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caretaker removed')),
          );
          await _loadCaretakers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Caretakers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCaretaker,
            tooltip: 'Add Caretaker',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCaretakers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _caretakers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadCaretakers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _caretakers.length,
                        itemBuilder: (context, index) {
                          final caretaker = _caretakers[index];
                          return _buildCaretakerCard(caretaker);
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Caretakers Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Delegate property management to trusted caretakers',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addCaretaker,
              icon: const Icon(Icons.add),
              label: const Text('Add First Caretaker'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaretakerCard(Map<String, dynamic> caretaker) {
    final caretakerProfile = caretaker['caretaker'] as Map<String, dynamic>?;
    final invitedEmail = caretaker['invited_email'] as String?;
    final invitationStatus = caretaker['invitation_status'] as String?;
    final isPending = invitationStatus == 'pending';
    
    // For pending invitations
    if (isPending && invitedEmail != null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.mail_outline, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                invitedEmail,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'INVITED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Waiting for user to sign up',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Permissions (will be granted on signup):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (caretaker['can_edit_properties'] == true)
                    _buildPermissionChip('Edit Properties', Icons.edit, Colors.blue),
                  if (caretaker['can_add_properties'] == true)
                    _buildPermissionChip('Add Properties', Icons.add, Colors.green),
                  if (caretaker['can_delete_properties'] == true)
                    _buildPermissionChip('Delete Properties', Icons.delete, Colors.red),
                  if (caretaker['can_view_analytics'] == true)
                    _buildPermissionChip('View Analytics', Icons.analytics, Colors.purple),
                  if (caretaker['can_respond_to_inquiries'] == true)
                    _buildPermissionChip('Respond to Inquiries', Icons.message, Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _removeCaretaker(caretaker['id']),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel Invitation'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    // For accepted caretakers
    final name = caretakerProfile?['full_name'] ?? 'Unknown';
    final email = caretakerProfile?['email'] ?? '';
    final phone = caretakerProfile?['phone'] ?? '';
    final photoUrl = caretakerProfile?['photo_url'] as String?;
    final status = caretaker['status'] as String;
    final isActive = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Permissions:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (caretaker['can_edit_properties'] == true)
                  _buildPermissionChip('Edit Properties', Icons.edit, Colors.blue),
                if (caretaker['can_add_properties'] == true)
                  _buildPermissionChip('Add Properties', Icons.add, Colors.green),
                if (caretaker['can_delete_properties'] == true)
                  _buildPermissionChip('Delete Properties', Icons.delete, Colors.red),
                if (caretaker['can_view_analytics'] == true)
                  _buildPermissionChip('View Analytics', Icons.analytics, Colors.purple),
                if (caretaker['can_respond_to_inquiries'] == true)
                  _buildPermissionChip('Respond to Inquiries', Icons.message, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editCaretaker(caretaker),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _removeCaretaker(caretaker['id']),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// =====================================================
// ADD CARETAKER DIALOG
// =====================================================

class _AddCaretakerDialog extends StatefulWidget {
  const _AddCaretakerDialog();

  @override
  State<_AddCaretakerDialog> createState() => _AddCaretakerDialogState();
}

class _AddCaretakerDialogState extends State<_AddCaretakerDialog> {
  final _emailController = TextEditingController();
  bool _canEdit = true;
  bool _canAdd = false;
  bool _canDelete = false;
  bool _canViewAnalytics = true;
  bool _canRespondToInquiries = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email')),
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Try to find user by email
      final userResponse = await SupabaseService.client
          .from('profiles')
          .select('id, email')
          .eq('email', email)
          .maybeSingle();

      String? caretakerId;
      String? invitedEmail;

      if (userResponse != null) {
        // User exists - add them directly
        caretakerId = userResponse['id'] as String;
        
        // Check if already a caretaker
        final existing = await SupabaseService.client
            .from('caretakers')
            .select('id')
            .eq('landlord_id', userId)
            .eq('caretaker_id', caretakerId!)
            .maybeSingle();

        if (existing != null) {
          throw Exception('This user is already your caretaker');
        }
      } else {
        // User doesn't exist - create invitation
        invitedEmail = email;
        
        // Check if invitation already exists
        final existingInvite = await SupabaseService.client
            .from('caretakers')
            .select('id')
            .eq('landlord_id', userId)
            .eq('invited_email', email)
            .maybeSingle();

        if (existingInvite != null) {
          throw Exception('Invitation already sent to this email');
        }
      }

      // Add caretaker or invitation
      await SupabaseService.client.from('caretakers').insert({
        'landlord_id': userId,
        'caretaker_id': caretakerId,
        'invited_email': invitedEmail,
        'invitation_status': invitedEmail != null ? 'pending' : 'pending', // Always pending for approval
        'status': 'pending', // Pending until accepted
        'can_edit_properties': _canEdit,
        'can_add_properties': _canAdd,
        'can_delete_properties': _canDelete,
        'can_view_analytics': _canViewAnalytics,
        'can_respond_to_inquiries': _canRespondToInquiries,
        'assigned_by': userId,
      });

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'isInvitation': invitedEmail != null,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Caretaker'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the email address of the person you want to add as a caretaker.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              '• If they already have an account, they\'ll be added immediately\n• If not, an invitation will be sent and they\'ll be added when they sign up',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'caretaker@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            const Text(
              'Permissions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Can Edit Properties'),
              value: _canEdit,
              onChanged: (value) => setState(() => _canEdit = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can Add Properties'),
              value: _canAdd,
              onChanged: (value) => setState(() => _canAdd = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can Delete Properties'),
              value: _canDelete,
              onChanged: (value) => setState(() => _canDelete = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can View Analytics'),
              value: _canViewAnalytics,
              onChanged: (value) => setState(() => _canViewAnalytics = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can Respond to Inquiries'),
              value: _canRespondToInquiries,
              onChanged: (value) => setState(() => _canRespondToInquiries = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

// =====================================================
// EDIT CARETAKER DIALOG
// =====================================================

class _EditCaretakerDialog extends StatefulWidget {
  final Map<String, dynamic> caretaker;

  const _EditCaretakerDialog({required this.caretaker});

  @override
  State<_EditCaretakerDialog> createState() => _EditCaretakerDialogState();
}

class _EditCaretakerDialogState extends State<_EditCaretakerDialog> {
  late bool _canEdit;
  late bool _canAdd;
  late bool _canDelete;
  late bool _canViewAnalytics;
  late bool _canRespondToInquiries;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _canEdit = widget.caretaker['can_edit_properties'] ?? true;
    _canAdd = widget.caretaker['can_add_properties'] ?? false;
    _canDelete = widget.caretaker['can_delete_properties'] ?? false;
    _canViewAnalytics = widget.caretaker['can_view_analytics'] ?? true;
    _canRespondToInquiries = widget.caretaker['can_respond_to_inquiries'] ?? true;
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      await SupabaseService.client
          .from('caretakers')
          .update({
            'can_edit_properties': _canEdit,
            'can_add_properties': _canAdd,
            'can_delete_properties': _canDelete,
            'can_view_analytics': _canViewAnalytics,
            'can_respond_to_inquiries': _canRespondToInquiries,
          })
          .eq('id', widget.caretaker['id']);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caretakerProfile = widget.caretaker['caretaker'] as Map<String, dynamic>?;
    final name = caretakerProfile?['full_name'] ?? 'Unknown';

    return AlertDialog(
      title: Text('Edit Permissions: $name'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Can Edit Properties'),
              value: _canEdit,
              onChanged: (value) => setState(() => _canEdit = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can Add Properties'),
              value: _canAdd,
              onChanged: (value) => setState(() => _canAdd = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can Delete Properties'),
              value: _canDelete,
              onChanged: (value) => setState(() => _canDelete = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can View Analytics'),
              value: _canViewAnalytics,
              onChanged: (value) => setState(() => _canViewAnalytics = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Can Respond to Inquiries'),
              value: _canRespondToInquiries,
              onChanged: (value) => setState(() => _canRespondToInquiries = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
