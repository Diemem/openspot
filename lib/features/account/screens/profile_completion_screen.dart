import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  // ✅ Removed unused _universityController

  File? _selectedImage;
  bool _isUploading = false;
  String? _photoUrl;
  String? _role;

  @override
  void initState() {
    super.initState();
    // ✅ FIX 1: Proper async loading with Future.microtask
    Future.microtask(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted || profile == null) return;

      setState(() {
        _role = profile['role'] as String?;
        _phoneController.text = profile['phone'] ?? '';
        _bioController.text = profile['bio'] ?? '';
        _locationController.text = profile['location'] ?? '';
        _photoUrl = profile['photo_url'];
      });
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadPhoto() async {
    if (_selectedImage == null) return _photoUrl;

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return null;

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'profile_photos/$fileName';

      // ✅ FIX 2: Add upsert: true and proper file options
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(
            path, 
            _selectedImage!,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint('Photo upload error: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      // ✅ FIX 3: Don't overwrite photo_url with null
      final uploadedPhoto = await _uploadPhoto();

      // Save profile
      await ref.read(authNotifierProvider.notifier).updateProfile({
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        // ✅ Only update photo_url if we have a new one
        if (uploadedPhoto != null) 'photo_url': uploadedPhoto,
      });

      if (mounted) {
        // ✅ FIX 7: Guard _role usage
        if ((_role ?? '') == 'landlord') {
          context.push('/phone-verification/${_phoneController.text.trim()}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX 6: Optimize ref.watch to prevent unnecessary rebuilds
    final name = ref.watch(
      currentUserProvider.select(
        (user) => user?.userMetadata?['full_name'] as String? ?? 'User',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              // ✅ FIX 5: Keyboard-safe padding
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              children: [
                const Text(
                  'Let\'s set up your profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This helps others know more about you',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),

                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!) as ImageProvider
                              : _photoUrl != null
                                  ? NetworkImage(_photoUrl!) as ImageProvider
                                  : null,
                          child: _selectedImage == null && _photoUrl == null
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 32),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isUploading ? Colors.grey : AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+254 712 345 678',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    // ✅ FIX 4: Better phone validation for Kenya
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }

                    final cleaned = value.replaceAll(' ', '').replaceAll('-', '');
                    if (!RegExp(r'^\+254\d{9}$').hasMatch(cleaned)) {
                      return 'Enter a valid Kenyan number (+254...)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us about yourself...',
                    prefixIcon: Icon(Icons.person),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Bio is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Nairobi, Kenya',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _isUploading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Profile'),
                ),

                const SizedBox(height: 16),

                // Skip Button
                TextButton(
                  onPressed: _isUploading ? null : () => context.go('/'),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),

          // ✅ FIX 9: Upload UX feedback overlay
          if (_isUploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Updating profile...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    // ✅ FIX 8: Removed unused _universityController.dispose()
    super.dispose();
  }
}
