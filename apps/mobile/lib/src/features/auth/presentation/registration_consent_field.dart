import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'legal_document_page.dart';

class RegistrationConsentField extends StatefulWidget {
  const RegistrationConsentField({
    required this.value,
    required this.showError,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  State<RegistrationConsentField> createState() =>
      _RegistrationConsentFieldState();
}

class _RegistrationConsentFieldState extends State<RegistrationConsentField> {
  late final TapGestureRecognizer _legalDocumentRecognizer;

  @override
  void initState() {
    super.initState();
    _legalDocumentRecognizer = TapGestureRecognizer()
      ..onTap = _openLegalDocuments;
  }

  @override
  void dispose() {
    _legalDocumentRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = widget.showError
        ? 'Accept the Terms and Privacy Policy to continue.'
        : null;

    return Semantics(
      container: true,
      label: 'Registration consent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: const ValueKey('registration-consent-checkbox'),
                value: widget.value,
                onChanged: (next) => widget.onChanged(next ?? false),
              ),
              Expanded(
                child: Text.rich(
                  key: const ValueKey('registration-consent-text'),
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms and Conditions and Privacy Policy',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: _legalDocumentRecognizer,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  void _openLegalDocuments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RegistrationLegalDocumentsPage(),
      ),
    );
  }
}
