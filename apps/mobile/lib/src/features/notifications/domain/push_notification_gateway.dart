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
