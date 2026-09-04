import 'package:flutter/material.dart';

import 'legal_document_page.dart';
import 'legal_policy.dart';

class RegistrationConsentField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final error =
        showError ? 'Accept the Terms and Privacy Policy to continue.' : null;

    return Semantics(
      container: true,
      label: 'Registration consent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const ValueKey('registration-consent-checkbox'),
                value: value,
                onChanged: (next) => onChanged(next ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('I agree to the '),
                      TextButton(
                        onPressed: () => _openTerms(context),
                        child: const Text('Terms and Conditions'),
                      ),
                      const Text(' and '),
                      TextButton(
                        onPressed: () => _openPrivacy(context),
                        child: const Text('Privacy Policy'),
                      ),
                      const Text('.'),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  void _openTerms(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LegalDocumentPage(
          title: 'Terms and Conditions',
          version: LegalPolicy.termsVersion,
          effectiveDate: LegalPolicy.effectiveDateLabel,
          sections: termsSections,
        ),
      ),
    );
  }

  void _openPrivacy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LegalDocumentPage(
          title: 'Privacy Policy',
          version: LegalPolicy.privacyVersion,
          effectiveDate: LegalPolicy.effectiveDateLabel,
          sections: privacySections,
        ),
      ),
    );
  }
}
