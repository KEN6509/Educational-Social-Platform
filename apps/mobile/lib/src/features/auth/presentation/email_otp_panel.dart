import 'package:flutter/material.dart';

import 'registration_controller.dart';
import 'registration_otp_field.dart';

class EmailOtpPanel extends StatelessWidget {
  const EmailOtpPanel({
    required this.state,
    required this.tokenController,
    required this.onTokenChanged,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
    super.key,
  });

  final RegistrationState state;
  final TextEditingController tokenController;
  final ValueChanged<String> onTokenChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isBusy = state.isBusy;
    final seconds = state.resendSecondsRemaining;

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
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('registration-otp-header'),
              children: [
                IconButton(
                  tooltip: 'Change email',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: isBusy ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enter the 6-digit code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0B1F3E),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a verification code to ${state.pendingEmail ?? ''}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF536A74),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 18),
            RegistrationOtpField(
              controller: tokenController,
              enabled: !isBusy,
              onChanged: onTokenChanged,
              onSubmitted: (_) => onVerify(),
            ),
            if (state.message != null) ...[
              const SizedBox(height: 14),
              _OtpMessage(
                message: state.message!,
                isSuccess: state.isSuccessMessage,
              ),
            ],
            const SizedBox(height: 18),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: tokenController,
              builder: (context, value, _) {
                final canVerify = value.text.trim().length == 6;
                return FilledButton.icon(
                  onPressed: canVerify && !isBusy ? onVerify : null,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Verify Email'),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: seconds == 0 && !isBusy ? onResend : null,
              child: Text(
                seconds == 0 ? 'Resend code' : 'Resend code in ${seconds}s',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpMessage extends StatelessWidget {
  const _OtpMessage({required this.message, required this.isSuccess});

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
