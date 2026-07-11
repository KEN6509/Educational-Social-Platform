import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/profile/data/profile_repository.dart';

void main() {
  test('profile repository exposes relationship select columns for social lists', () {
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
}
