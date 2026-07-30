import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/password_policy.dart';
import '../../../core/theme/app_input_decoration.dart';

typedef PasswordReauthenticator = Future<String?> Function(
  String email,
  String currentPassword,
);
typedef PasswordUpdater = Future<void> Function(String newPassword);

class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({
    super.key,
    this.currentUserEmail,
    this.currentUserId,
    this.reauthenticate,
    this.updatePassword,
  });

  final String? currentUserEmail;
  final String? currentUserId;
  final PasswordReauthenticator? reauthenticate;
  final PasswordUpdater? updatePassword;

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isProcessing = false;
  PasswordPolicyResult _passwordStatus = PasswordPolicy.evaluate('');

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _defaultReauthenticate(
    String email,
    String currentPassword,
  ) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    return response.user?.id;
  }

  Future<void> _defaultUpdatePassword(String newPassword) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (currentPassword.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showMessage('Please fill in all three password fields.');
      return;
    }

    final policyError = PasswordPolicy.validationError(password);
    if (policyError != null) {
      _showMessage(policyError);
      return;
    }

    if (password != confirm) {
      _showMessage('New passwords do not match.');
      return;
    }

    if (password == currentPassword) {
      _showMessage(
        'Choose a new password that differs from your current password.',
      );
      return;
    }

    var email = widget.currentUserEmail;
    var currentUserId = widget.currentUserId;
    if (email == null || currentUserId == null) {
      final auth = Supabase.instance.client.auth;
      email ??= auth.currentUser?.email;
      currentUserId ??= auth.currentUser?.id;
    }
    if (email == null || currentUserId == null) {
      _showMessage('Your session has expired. Please log in again.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final verifiedUserId =
          await (widget.reauthenticate ?? _defaultReauthenticate)
              .call(email, currentPassword);
      if (verifiedUserId != currentUserId) {
        _showMessage('Current password is incorrect.');
        return;
      }

      await (widget.updatePassword ?? _defaultUpdatePassword).call(password);
      if (mounted) {
        _showMessage('Password updated successfully');
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) {
        final message = error.message.toLowerCase();
        _showMessage(
          message.contains('invalid login credentials') ||
                  message.contains('invalid credentials')
              ? 'Current password is incorrect.'
              : 'Could not verify current password. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not update password. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Color(0xFF1E293B)),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            _buildPasswordField(
              fieldKey: const ValueKey('current-password-field'),
              label: 'Current Password',
              controller: _currentPasswordController,
              hint: 'Enter current password',
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              fieldKey: const ValueKey('new-password-field'),
              label: 'New Password',
              controller: _passwordController,
              hint: 'Enter new password',
              onChanged: (value) {
                setState(() {
                  _passwordStatus = PasswordPolicy.evaluate(value);
                });
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              fieldKey: const ValueKey('confirm-password-field'),
              label: 'Confirm New Password',
              controller: _confirmController,
              hint: 'Confirm new password',
            ),
            const SizedBox(height: 16),
            _PasswordChecklist(status: _passwordStatus),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your new password must be different from your current password.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1F3E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor:
                      const Color(0xFF0B1F3E).withValues(alpha: 0.6),
                ),
                child: _isProcessing
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
  }) {
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
              color: Color(0xFF64748B),
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

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.status});

  final PasswordPolicyResult status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _PasswordRule(
            label: 'At least 12 characters',
            isMet: status.hasMinimumLength,
          ),
          _PasswordRule(
            label: 'Contains an uppercase letter',
            isMet: status.hasUppercase,
          ),
          _PasswordRule(
            label: 'Contains a lowercase letter',
            isMet: status.hasLowercase,
          ),
          _PasswordRule(
            label: 'Contains a number',
            isMet: status.hasNumber,
          ),
          _PasswordRule(
            label: 'Contains a symbol such as . or _',
            isMet: status.hasSymbol,
          ),
        ],
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({
    required this.label,
    required this.isMet,
  });

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? const Color(0xFF15803D) : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
