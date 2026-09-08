abstract interface class PendingRegistrationStore {
  Future<String?> readEmail();

  Future<void> saveEmail(String email);

  Future<void> clear();
}
