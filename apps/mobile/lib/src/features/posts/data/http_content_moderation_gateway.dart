import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/content_moderation.dart';

typedef AccessTokenReader = Future<String?> Function();

final class HttpContentModerationGateway implements ContentModerationGateway {
  HttpContentModerationGateway({
    required this.baseUrl,
    required this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final AccessTokenReader accessToken;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<ContentModerationResult> moderatePost(String postId) {
    return _moderate('/moderation/posts/$postId');
  }

  @override
  Future<ContentModerationResult> moderateComment(String commentId) {
    return _moderate('/moderation/comments/$commentId');
  }

  Future<ContentModerationResult> _moderate(String path) async {
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw const ContentModerationFailure(
          'Please sign in before moderating content.');
    }

    late final http.Response response;
    try {
      response = await _client.post(
        baseUrl.resolve(path),
        headers: {
          'authorization': 'Bearer ${token.trim()}',
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      ).timeout(timeout);
    } on SocketException catch (_) {
      throw _transportFailure();
    } on http.ClientException catch (_) {
      throw _transportFailure();
    } on TimeoutException catch (_) {
      throw _transportFailure();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapFailure(response);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Moderation response is not an object.');
      }
      return ContentModerationResult(
        targetId: body['targetId'] as String,
        revision: (body['moderationRevision'] as num).toInt(),
        state: _stateFromJson(body['caseState'] as String),
        riskScore: (body['riskScore'] as num?)?.toDouble(),
        reason: body['reason'] as String?,
        retryAllowed: body['retryAllowed'] as bool? ?? false,
      );
    } catch (_) {
      throw const ContentModerationFailure(
          'CyanZone returned an invalid moderation response.');
    }
  }

  ContentModerationFailure _transportFailure() {
    return const ContentModerationFailure(
      'Unable to reach CyanZone moderation. Please try again.',
      retryAllowed: true,
    );
  }

  ContentModerationFailure _mapFailure(http.Response response) {
    var message = 'Unable to complete content moderation.';
    var retryAllowed = false;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['error'] is String) {
        message = body['error'] as String;
      }
      retryAllowed =
          body is Map<String, dynamic> && body['retryAllowed'] == true;
    } catch (_) {
      // Keep the safe fallback message.
    }
    if (response.statusCode == 429) {
      retryAllowed = true;
      message = 'Please wait before retrying moderation.';
    }
    if (response.statusCode == 503) {
      retryAllowed = true;
      message = 'Moderation is temporarily unavailable. Please try again.';
    }
    return ContentModerationFailure(
      message,
      retryAllowed: retryAllowed,
      statusCode: response.statusCode,
    );
  }

  ContentModerationState _stateFromJson(String value) {
    return switch (value) {
      'processing' => ContentModerationState.processing,
      'admin_review' => ContentModerationState.adminReview,
      'approved' => ContentModerationState.approved,
      'rejected' => ContentModerationState.rejected,
      'failed' => ContentModerationState.failed,
      'superseded' => ContentModerationState.superseded,
      _ => throw const FormatException('Unknown moderation state.'),
    };
  }
}
