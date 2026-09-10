import 'push_destination.dart';

enum PushAuthorizationStatus { denied, authorized, provisional }

class PushMessage {
  const PushMessage(
      {required this.title, required this.body, required this.data});

  final String title;
  final String body;
  final Map<String, dynamic> data;
}

abstract interface class PushNotificationGateway {
  Future<PushAuthorizationStatus> requestAuthorization();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onForegroundMessage;
  Stream<PushDestination> get onMessageOpened;
  Future<PushDestination?> get initialMessage;
  Future<void> showForeground(PushMessage message);
}

class NoopPushNotificationGateway implements PushNotificationGateway {
  const NoopPushNotificationGateway();

  @override
  Future<PushAuthorizationStatus> requestAuthorization() async =>
      PushAuthorizationStatus.denied;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();

  @override
  Stream<PushDestination> get onMessageOpened => const Stream.empty();

  @override
  Future<PushDestination?> get initialMessage async => null;

  @override
  Future<void> showForeground(PushMessage message) async {}
}
