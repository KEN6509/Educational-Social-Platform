import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cyanzone_mobile/src/features/posts/data/http_content_moderation_gateway.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';

void main() {
  test('posts target id with the Supabase bearer token and parses approval',
      () async {
    late http.Request captured;
    final gateway = HttpContentModerationGateway(
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      accessToken: () async => 'member-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'targetType': 'post',
            'targetId': 'post-1',
            'moderationRevision': 2,
            'status': 'approved',
            'caseState': 'approved',
            'riskScore': 12,
            'reason': 'safe',
            'retryAllowed': false,
          }),
          200,
        );
      }),
    );

    final result = await gateway.moderatePost('post-1');

    expect(captured.url.path, '/moderation/posts/post-1');
    expect(captured.headers['authorization'], 'Bearer member-token');
    expect(captured.body, isEmpty);
    expect(result.state, ContentModerationState.approved);
    expect(result.targetId, 'post-1');
  });

  test('maps admin review and rejection states', () async {
    final gateway = HttpContentModerationGateway(
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      accessToken: () async => 'token',
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'targetType': 'comment',
              'targetId': 'comment-1',
              'moderationRevision': 1,
              'status': 'pending',
              'caseState': 'admin_review',
              'riskScore': 50,
              'reason': 'Needs review',
              'retryAllowed': false,
            }),
            200,
          )),
    );

    expect((await gateway.moderateComment('comment-1')).state,
        ContentModerationState.adminReview);
  });

  test('maps retryable provider failure and cooldown', () async {
    final gateway = HttpContentModerationGateway(
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      accessToken: () async => 'token',
      client: MockClient((request) async => http.Response(
            jsonEncode({'error': 'provider unavailable', 'retryAllowed': true}),
            503,
          )),
    );

    await expectLater(
      gateway.moderatePost('post-1'),
      throwsA(isA<ContentModerationFailure>().having(
        (error) => error.retryAllowed,
        'retryAllowed',
        true,
      )),
    );
  });

  test('keeps a cooldown response retryable for the persistent queue', () async {
    final gateway = HttpContentModerationGateway(
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      accessToken: () async => 'token',
      client: MockClient((request) async => http.Response(
            jsonEncode({'error': 'cooldown'}),
            429,
          )),
    );

    await expectLater(
      gateway.moderatePost('post-1'),
      throwsA(
        isA<ContentModerationFailure>()
            .having((error) => error.retryAllowed, 'retryAllowed', true)
            .having(
              (error) => error.message,
              'message',
              'Please wait before retrying moderation.',
            ),
      ),
    );
  });

  test('requires a session and rejects malformed responses', () async {
    final missingSession = HttpContentModerationGateway(
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      accessToken: () async => null,
      client: MockClient((request) async => http.Response('', 200)),
    );
    await expectLater(missingSession.moderatePost('post-1'),
        throwsA(isA<ContentModerationFailure>()));

    final malformed = HttpContentModerationGateway(
      baseUrl: Uri.parse('https://api.cyanzone.test'),
      accessToken: () async => 'token',
      client: MockClient((request) async => http.Response('{}', 200)),
    );
    await expectLater(malformed.moderatePost('post-1'),
        throwsA(isA<ContentModerationFailure>()));
  });

  for (final transportError in <Object>[
    const SocketException('Failed host lookup'),
    http.ClientException('Connection closed'),
    TimeoutException('Request timed out'),
  ]) {
    test('maps ${transportError.runtimeType} to a retryable failure', () async {
      final gateway = HttpContentModerationGateway(
        baseUrl: Uri.parse('https://api.cyanzone.test'),
        accessToken: () async => 'token',
        client: MockClient((request) async => throw transportError),
      );

      await expectLater(
        gateway.moderatePost('post-1'),
        throwsA(
          isA<ContentModerationFailure>()
              .having((error) => error.retryAllowed, 'retryAllowed', true)
              .having(
                (error) => error.message,
                'message',
                'Unable to reach CyanZone moderation. Please try again.',
              ),
        ),
      );
    });
  }
}
