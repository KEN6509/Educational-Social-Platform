import 'package:cyanzone_mobile/src/features/auth/presentation/legal_document_page.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/legal_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders document metadata and sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentPage(
          title: 'Privacy Policy',
          version: LegalPolicy.privacyVersion,
          effectiveDate: LegalPolicy.effectiveDateLabel,
          sections: privacySections,
        ),
      ),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Version 1.0'), findsOneWidget);
    expect(find.text('How we use information'), findsOneWidget);
  });
}
