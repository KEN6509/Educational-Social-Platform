import 'package:flutter/material.dart';

import 'legal_policy.dart';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.sections,
    super.key,
  });

  final String title;
  final String version;
  final String effectiveDate;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: _documentContent(
          theme,
          version: version,
          effectiveDate: effectiveDate,
          sections: sections,
        ),
      ),
    );
  }
}

class RegistrationLegalDocumentsPage extends StatelessWidget {
  const RegistrationLegalDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Terms and Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _DocumentTitle(title: 'Terms and Conditions', theme: theme),
          const SizedBox(height: 12),
          ..._documentContent(
            theme,
            version: LegalPolicy.termsVersion,
            effectiveDate: LegalPolicy.effectiveDateLabel,
            sections: termsSections,
          ),
          const Divider(height: 44),
          _DocumentTitle(title: 'Privacy Policy', theme: theme),
          const SizedBox(height: 12),
          ..._documentContent(
            theme,
            version: LegalPolicy.privacyVersion,
            effectiveDate: LegalPolicy.effectiveDateLabel,
            sections: privacySections,
          ),
        ],
      ),
    );
  }
}

class _DocumentTitle extends StatelessWidget {
  const _DocumentTitle({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

List<Widget> _documentContent(
  ThemeData theme, {
  required String version,
  required String effectiveDate,
  required List<LegalSection> sections,
}) {
  return [
    Text('Version $version', style: theme.textTheme.titleMedium),
    const SizedBox(height: 4),
    Text(
      'Effective $effectiveDate',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 24),
    for (final section in sections) ...[
      Semantics(
        header: true,
        child: Text(
          section.heading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        section.body,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      const SizedBox(height: 20),
    ],
  ];
}
