part of 'set_password_page.dart';

class _SetPasswordBody extends StatelessWidget {
  const _SetPasswordBody({
    required this.currentPasswordController,
    required this.passwordController,
    required this.confirmController,
    required this.passwordStatus,
    required this.isProcessing,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final PasswordPolicyResult passwordStatus;
  final bool isProcessing;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.section,
      ),
      child: Column(
        children: [
          _PasswordInput(
            fieldKey: const ValueKey('current-password-field'),
            label: 'Current Password',
            controller: currentPasswordController,
            hint: 'Enter current password',
          ),
          const SizedBox(height: AppSpacing.lg),
          _PasswordInput(
            fieldKey: const ValueKey('new-password-field'),
            label: 'New Password',
            controller: passwordController,
            hint: 'Enter new password',
            onChanged: onPasswordChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PasswordInput(
            fieldKey: const ValueKey('confirm-password-field'),
            label: 'Confirm New Password',
            controller: confirmController,
            hint: 'Confirm new password',
          ),
          const SizedBox(height: AppSpacing.lg),
          PasswordChecklist(status: passwordStatus),
          const SizedBox(height: AppSpacing.sm),
          const _PasswordGuidance(),
          const SizedBox(height: AppSpacing.lg),
          _PasswordSubmitButton(
            isProcessing: isProcessing,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          key: fieldKey,
          controller: controller,
          obscureText: true,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
          decoration: appInputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _PasswordGuidance extends StatelessWidget {
  const _PasswordGuidance();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Your new password must be different from your current password.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PasswordSubmitButton extends StatelessWidget {
  const _PasswordSubmitButton({
    required this.isProcessing,
    required this.onPressed,
  });

  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.6),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
