import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/profile/data/user_profile.dart';

void main() {
  test('parses follow state for another user profile', () {
    final profile = UserProfile.fromMap({
      'id': 'user-2',
      'email': 'learner@example.com',
      'name': 'Learner',
      'is_following': true,
      'post_count': 3,
      'follower_count': 9,
      'following_count': 4,
    });

    expect(profile.isFollowing, isTrue);
    expect(profile.followerCount, 9);
  });
}
