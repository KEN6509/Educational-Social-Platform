part of 'edit_profile_page.dart';

class _EditProfileBody extends StatelessWidget {
  const _EditProfileBody({
    required this.profile,
    required this.selectedImage,
    required this.nameController,
    required this.bioController,
    required this.onPickImage,
  });

  final UserProfile profile;
  final File? selectedImage;
  final TextEditingController nameController;
  final TextEditingController bioController;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          _EditProfileAvatar(
            profile: profile,
            selectedImage: selectedImage,
            onTap: onPickImage,
          ),
          const SizedBox(height: 48),
          _EditProfileInput(
            label: 'Username',
            controller: nameController,
            hint: 'Enter your name',
            maxLength: 24,
          ),
          _EditProfileInput(
            label: 'Bio',
            controller: bioController,
            hint: 'Add a bio to your profile',
            maxLines: 5,
            maxLength: 150,
          ),
        ],
      ),
    );
  }
}

class _EditProfileAvatar extends StatelessWidget {
  const _EditProfileAvatar({
    required this.profile,
    required this.selectedImage,
    required this.onTap,
  });

  final UserProfile profile;
  final File? selectedImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceMuted,
                  ),
                  child: ClipOval(
                    child: selectedImage != null
                        ? Image.file(selectedImage!, fit: BoxFit.cover)
                        : profile.avatarUrl != null
                            ? Image.network(profile.avatarUrl!,
                                fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  profile.name.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Color(0xFF2C7189),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
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
            onTap: onTap,
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
    );
  }
}

class _EditProfileInput extends StatelessWidget {
  const _EditProfileInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.textSecondary,
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
                        color: AppColors.textMuted,
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
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friendlyErrorMessage(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
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
              backgroundColor: AppColors.navy,
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
