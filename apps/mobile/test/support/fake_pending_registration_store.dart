import 'package:cyanzone_mobile/src/features/auth/domain/pending_registration_store.dart';

final class FakePendingRegistrationStore implements PendingRegistrationStore {
  String? email;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> saveEmail(String email) async {
    this.email = email.trim().toLowerCase();
  }

  @override
  Future<void> clear() async {
    email = null;
  }
}
