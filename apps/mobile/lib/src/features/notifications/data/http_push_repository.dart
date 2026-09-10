import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../domain/push_destination.dart';

typedef PushAccessTokenReader = Future<String?> Function();

class HttpPushRepository {
  HttpPushRepository({
    required this.accessToken,
    Uri? baseUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 12),
  })  : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client(),
        _timeout = timeout;

  final PushAccessTokenReader accessToken;
  final Uri _baseUrl;
  final http.Client _client;
  final Duration _timeout;

  Future<void> registerDevice({
    required String deviceId,
    required String token,
    required bool enabled,
  }) async {
    await _send(
      'PUT',
      '/push/devices',
      body: {'deviceId': deviceId, 'token': token, 'enabled': enabled},
    );
  }

  Future<void> deactivateDevice(String deviceId) async {
    await _send('DELETE', '/push/devices/${Uri.encodeComponent(deviceId)}');
  }

  Future<ResolvedPushDestination?> resolveDestination(
      PushDestination destination) async {
    final response = await _send(
      'GET',
      '/push/events/${destination.sourceTable}/${Uri.encodeComponent(destination.sourceId)}',
      expectBody: true,
    );
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return ResolvedPushDestination.tryParse(map);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool expectBody = false,
  }) async {
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A signed-in session is required for push delivery.');
    }
    final headers = <String, String>{
      'Authorization': 'Bearer ${token.trim()}',
      'Content-Type': 'application/json',
    };
    final uri = _baseUrl.replace(
      path: '${_baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}$path',
    );
    final request = switch (method) {
      'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => _client.delete(uri, headers: headers),
      'GET' => _client.get(uri, headers: headers),
      _ => throw ArgumentError('Unsupported push method'),
    };
    final response = await request.timeout(_timeout);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (expectBody && response.body.isEmpty)) {
      throw StateError('Push service request failed (${response.statusCode}).');
    }
    return response;
  }
}
