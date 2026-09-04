import 'package:flutter/material.dart';

import '../../../core/security/password_policy.dart';
import '../../../core/widgets/password_checklist.dart';
import '../domain/auth_gateway.dart';
import '../domain/registration_request.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.authGateway,
    super.key,
  });

  final AuthGateway authGateway;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  var _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  PasswordPolicyResult _passwordStatus = PasswordPolicy.evaluate('');
  String? _message;
  bool _isSuccessMessage = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _isSuccessMessage = false;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegistering) {
        final outcome = await widget.authGateway.register(
          RegistrationRequest(
            name: _nameController.text.trim(),
            email: email,
            password: password,
            termsVersion: '',
            privacyVersion: '',
            consentAcceptedAt: DateTime.fromMillisecondsSinceEpoch(
              0,
              isUtc: true,
            ),
          ),
        );

        if (outcome == RegistrationOutcome.confirmationRequired && mounted) {
          setState(() {
            _message =
                'Account created. Check your email if confirmation is enabled.';
            _isSuccessMessage = true;
          });
        }
      } else {
        await widget.authGateway.signIn(email: email, password: password);
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeAuthMode(bool isRegistering) {
    if (_isLoading || _isRegistering == isRegistering) {
      return;
    }

    setState(() {
      _isRegistering = isRegistering;
      _message = null;
      _isSuccessMessage = false;
      _showConfirmPassword = false;
      _passwordStatus = PasswordPolicy.evaluate(_passwordController.text);
      _formKey = GlobalKey<FormState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF58E1B5),
                Color(0xFF4490AD),
                Color(0xFF0B1F3E),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BrandMark(),
                            const SizedBox(height: 18),
                            Text(
                              'Beyond the Blue, Inside the Zone.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isRegistering
                                  ? 'Create your CyanZone account. Parent links and creator access happen after signup.'
                                  : 'Log in to continue learning, posting, and staying connected with supervision built in.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _AuthPanel(
                              isRegistering: _isRegistering,
                              isLoading: _isLoading,
                              message: _message,
                              isSuccessMessage: _isSuccessMessage,
                              formKey: _formKey,
                              nameController: _nameController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              confirmPasswordController:
                                  _confirmPasswordController,
                              showPassword: _showPassword,
                              showConfirmPassword: _showConfirmPassword,
                              passwordStatus: _passwordStatus,
                              onModeChanged: _changeAuthMode,
                              onPasswordChanged: (value) {
                                setState(() {
                                  _passwordStatus =
                                      PasswordPolicy.evaluate(value);
                                });
                              },
                              onTogglePassword: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              onToggleConfirmPassword: () => setState(
                                () => _showConfirmPassword =
                                    !_showConfirmPassword,
                              ),
                              onSubmit: _submit,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _TrustPill(
                                  icon: Icons.shield_outlined,
                                  label: 'AI moderation',
                                ),
                                _TrustPill(
                                  icon: Icons.family_restroom_outlined,
                                  label: 'Parent linked',
                                ),
                                _TrustPill(
                                  icon: Icons.school_outlined,
                                  label: 'Learning first',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330B1F3E),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/logo_transparent.png',
              semanticLabel: 'CyanZone logo',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'CyanZone',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.isRegistering,
    required this.isLoading,
    required this.message,
    required this.isSuccessMessage,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.showPassword,
    required this.showConfirmPassword,
    required this.passwordStatus,
    required this.onModeChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSubmit,
  });

  final bool isRegistering;
  final bool isLoading;
  final String? message;
  final bool isSuccessMessage;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool showPassword;
  final bool showConfirmPassword;
  final PasswordPolicyResult passwordStatus;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D061A33),
            blurRadius: 34,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthModeSwitch(
                isRegistering: isRegistering,
                isEnabled: !isLoading,
                onChanged: onModeChanged,
              ),
              const SizedBox(height: 20),
              if (isRegistering) ...[
                TextFormField(
                  key: const ValueKey('register-name-field'),
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    helperText: 'This appears on your profile.',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.length < 2) {
                      return 'Enter your name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                key: ValueKey(
                  isRegistering ? 'register-email-field' : 'login-email-field',
                ),
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: ValueKey(
                  isRegistering
                      ? 'register-password-field'
                      : 'login-password-field',
                ),
                controller: passwordController,
                obscureText: !showPassword,
                textInputAction:
                    isRegistering ? TextInputAction.next : TextInputAction.done,
                autofillHints: isRegistering
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: showPassword ? 'Hide password' : 'Show password',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (!isRegistering) {
                    return password.isEmpty ? 'Enter your password.' : null;
                  }
                  return PasswordPolicy.validationError(password);
                },
                onChanged: isRegistering ? onPasswordChanged : null,
                onFieldSubmitted: (_) {
                  if (!isRegistering) {
                    onSubmit();
                  }
                },
              ),
              if (isRegistering) ...[
                const SizedBox(height: 14),
                PasswordChecklist(status: passwordStatus),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('register-confirm-password-field'),
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      tooltip: showConfirmPassword
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: onToggleConfirmPassword,
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => onSubmit(),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isRegistering
                            ? Icons.arrow_forward_rounded
                            : Icons.login_rounded,
                      ),
                label: Text(isRegistering ? 'Create account' : 'Log in'),
              ),
              if (message != null) ...[
                const SizedBox(height: 14),
                _AuthMessage(
                  message: message!,
                  isSuccess: isSuccessMessage,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.isRegistering,
    required this.isEnabled,
    required this.onChanged,
  });

  final bool isRegistering;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E8EA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              icon: Icons.login_rounded,
              label: 'Log in',
              selected: !isRegistering,
              enabled: isEnabled,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _AuthModeButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Create account',
              selected: isRegistering,
              enabled: isEnabled,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? const Color(0xFF0B1F3E) : const Color(0xFF536A74);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 18),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: foreground,
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({
    required this.message,
    required this.isSuccess,
  });

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF087F5B) : const Color(0xFFB42318);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSuccess ? const Color(0xFFEAF8F1) : const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline
                  : Icons.error_outline_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
