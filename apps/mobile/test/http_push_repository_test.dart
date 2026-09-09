import 'dart:convert';

import 'package:cyanzone_mobile/src/features/notifications/data/http_push_repository.dart';
import 'package:cyanzone_mobile/src/features/notifications/domain/push_destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _RecordingClient extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'destination': {
          'version': '1',
          'sourceTable': 'notifications',
          'sourceId': 'source-1',
          'route': 'conversation',
          'conversationId': 'conversation-1',
        },
      }))),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  test('resolves a destination with the current bearer session', () async {
    final client = _RecordingClient();
    final repository = HttpPushRepository(
      accessToken: () async => 'member-token',
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      client: client,
    );

    const requested = PushDestination(
      sourceTable: 'notifications',
      sourceId: 'source-1',
      route: PushRoute.post,
    );
    final resolved = await repository.resolveDestination(requested);

    expect(resolved?.route, PushRoute.conversation);
    expect(client.request?.url.toString(),
        'https://api.cyanzone.test/push/events/notifications/source-1');
    expect(client.request?.headers['authorization'], 'Bearer member-token');
  });
}
