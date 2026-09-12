import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../data/user_profile.dart';
import '../data/profile_repository.dart';
import '../../media/presentation/device_photo_picker_page.dart';
import 'avatar_crop_page.dart';

part 'edit_profile_widgets.dart';

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
        AppFeedback.showError(context, friendlyErrorTitle(e));
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
                  color: AppColors.cyan,
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
              : _EditProfileBody(
                  profile: widget.profile,
                  selectedImage: _selectedImage,
                  nameController: _nameController,
                  bioController: _bioController,
                  onPickImage: _pickImage,
                ),
    );
  }
}
