abstract final class LegalPolicy {
  static const termsVersion = '1.0';
  static const privacyVersion = '1.0';
  static const effectiveDateLabel = '4 September 2026';
}

final class LegalSection {
  const LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

const termsSections = <LegalSection>[
  LegalSection(
    'Using CyanZone',
    'Use CyanZone responsibly and provide accurate account information. Do not use the service to break the law, harm another person, impersonate someone, or interfere with the service.',
  ),
  LegalSection(
    'Your content',
    'You are responsible for the content you submit. CyanZone may review, limit, or remove content that is unsafe, unlawful, or against the platform rules.',
  ),
  LegalSection(
    'Parent supervision',
    'Parent supervision features work only after an account link is accepted. Linked parents may receive the supervision information described in the app.',
  ),
  LegalSection(
    'SOS and safety tools',
    'SOS and Check-In features are support tools. They do not replace local emergency services. Contact emergency services when immediate help is required.',
  ),
  LegalSection(
    'Account action',
    'CyanZone may restrict or suspend an account that seriously or repeatedly breaks these terms. You may request account deletion through the project administrator.',
  ),
  LegalSection(
    'Changes',
    'A future version may update these terms. CyanZone will identify the new version and effective date when another acceptance is required.',
  ),
];

const privacySections = <LegalSection>[
  LegalSection(
    'Information we collect',
    'CyanZone stores account and profile details, content and interactions, reports, notifications, and accepted parent-child links. It also records the policy versions and time accepted during registration.',
  ),
  LegalSection(
    'Location and supervision data',
    'Location is collected only when a user chooses Check-In or activates SOS and grants permission. Check-In stores one location. An active SOS may update location while CyanZone remains open. Linked parents can view the related supervision record.',
  ),
  LegalSection(
    'How we use information',
    'Information is used to provide accounts, social and learning features, parent supervision, safety tools, moderation, notifications, support, and service security.',
  ),
  LegalSection(
    'Service providers',
    'CyanZone uses required service providers such as Supabase to store data and operate authentication. Information is shared only as needed to operate these services or meet a legal requirement.',
  ),
  LegalSection(
    'Retention and security',
    'Information is kept while needed for the account, safety, moderation, or project records. Reasonable safeguards are used, but no online system can guarantee complete security.',
  ),
  LegalSection(
    'Your choices',
    'You may update supported profile information in the app. Requests to access, correct, or delete other account data can be made through the project administrator.',
  ),
];
