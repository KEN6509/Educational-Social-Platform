import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../data/user_profile.dart';
import '../data/profile_repository.dart';
import '../../media/presentation/device_photo_picker_page.dart';
import 'avatar_crop_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({required this.profile, super.key});

  final UserProfile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final ProfileRepository _profileRepository;
  File? _selectedImage;
  bool _isSaving = false;
  bool _isCheckingConnection = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _profileRepository = ProfileRepository(Supabase.instance.client);
    _checkConnection();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final images = await Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        builder: (_) => const DevicePhotoPickerPage(
          maxSelection: 1,
          allowCamera: true,
        ),
      ),
    );
    final XFile? image = images?.isEmpty ?? true ? null : images!.first;
    if (image != null) {
      if (!mounted) return;
      final imageBytes = await image.readAsBytes();
      if (!mounted) return;
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => AvatarCropPage(imageBytes: imageBytes),
        ),
      );
      if (croppedBytes == null) return;
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File(
        '${tempDir.path}/profile-avatar-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      setState(() {
        _selectedImage = croppedFile;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;
      final userId = widget.profile.id;
      String? avatarUrl = widget.profile.avatarUrl;

      // Handle Image Upload if new image selected
      if (_selectedImage != null) {
        const fileName = 'avatar.jpg';
        final filePath = '$userId/$fileName';

        // Upload/Replace avatar (one account, one avatar logic)
        await client.storage.from('avatars').upload(
              filePath,
              _selectedImage!,
              fileOptions: const FileOptions(upsert: true),
            );

        // Get public URL
        avatarUrl = client.storage.from('avatars').getPublicUrl(filePath);
      }

      // Update Profile Info
      await _profileRepository.updateProfile(
        userId: userId,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorTitle(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _checkConnection() async {
    try {
      if (!await _hasInternetConnection()) {
        throw const SocketException('No internet connection');
      }
      await _profileRepository
          .fetchProfile(widget.profile.id)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _isCheckingConnection = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingConnection = false;
        _loadError = e;
      });
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded,
              size: 24, color: Color(0xFF1E293B)),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_loadError == null && !_isCheckingConnection && _isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_loadError == null && !_isCheckingConnection)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF4490AD),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loadError != null
          ? _EditProfileLoadError(error: _loadError, onRetry: _checkConnection)
          : _isCheckingConnection
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Avatar Section (TikTok style)
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                    child: ClipOval(
                                      child: _selectedImage != null
                                          ? Image.file(_selectedImage!,
                                              fit: BoxFit.cover)
                                          : widget.profile.avatarUrl != null
                                              ? Image.network(
                                                  widget.profile.avatarUrl!,
                                                  fit: BoxFit.cover)
                                              : Center(
                                                  child: Text(
                                                    widget.profile.name
                                                        .characters.first
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 32,
                                                      color: Color(0xFF2C7189),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                    ),
                                  ),
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _pickImage,
                              child: const Text(
                                'Change Photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Modern Input Fields
                      _buildModernInput(
                        label: 'Username',
                        controller: _nameController,
                        hint: 'Enter your name',
                        maxLength: 24,
                      ),
                      _buildModernInput(
                        label: 'Bio',
                        controller: _bioController,
                        hint: 'Add a bio to your profile',
                        maxLines: 5,
                        maxLength: 150,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildModernInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: 1,
            maxLength: maxLength,
            inputFormatters: maxLength == null
                ? null
                : [LengthLimitingTextInputFormatter(maxLength)],
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
            decoration: appInputDecoration(
              hintText: hint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (maxLength != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      '${value.text.length}/$maxLength',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditProfileLoadError extends StatelessWidget {
  const _EditProfileLoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 140, 24, 24),
      children: [
        Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 14),
        Text(
          friendlyErrorTitle(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0B1F3E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friendlyErrorMessage(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B1F3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
