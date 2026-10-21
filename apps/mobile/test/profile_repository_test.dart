import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cyanzone_mobile/src/features/profile/data/profile_repository.dart';

void main() {
  test(
      'profile repository exposes relationship select columns for social lists',
      () {
    expect(
      ProfileRepository.profileCountSelectColumns,
      contains('follower_count:follows!follows_following_id_fkey(count)'),
    );
    expect(
      ProfileRepository.followerSelectColumns,
      contains('profiles!follows_follower_id_fkey'),
    );
    expect(
      ProfileRepository.followingSelectColumns,
      contains('profiles!follows_following_id_fkey'),
    );
  });

  test('profile update reports failure when no profile row was changed',
      () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        if (request.headers['prefer']?.contains('return=representation') ==
            true) {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'}, request: request);
        }
        return http.Response('', 204, request: request);
      }),
    );

    await expectLater(
      ProfileRepository(client).updateProfile(userId: 'user-1', name: 'Name'),
      throwsStateError,
    );
  });

  test('checks whether the new avatar URL is stored on the profile', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(
          '{"avatar_url":"https://example.supabase.co/new-avatar.jpg"}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    expect(
      await ProfileRepository(client).isCurrentAvatarUrl(
        userId: 'user-1',
        avatarUrl: 'https://example.supabase.co/new-avatar.jpg',
      ),
      isTrue,
    );
    expect(
      await ProfileRepository(client).isCurrentAvatarUrl(
        userId: 'user-1',
        avatarUrl: 'https://example.supabase.co/another-avatar.jpg',
      ),
      isFalse,
    );
  });
}
