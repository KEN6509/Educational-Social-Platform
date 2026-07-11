class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.isContentCreator = false,
    this.isAdmin = false,
    this.isFollowing = false,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final bool isContentCreator;
  final bool isAdmin;
  final bool isFollowing;
  final int postCount;
  final int followerCount;
  final int followingCount;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      isContentCreator: map['is_content_creator'] as bool? ?? false,
      isAdmin: map['is_admin'] as bool? ?? false,
      isFollowing: map['is_following'] as bool? ?? false,
      postCount: map['post_count'] as int? ?? 0,
      followerCount: map['follower_count'] as int? ?? 0,
      followingCount: map['following_count'] as int? ?? 0,
    );
  }

  UserProfile copyWith({
    bool? isFollowing,
    int? followerCount,
    int? followingCount,
  }) {
    return UserProfile(
      id: id,
      email: email,
      name: name,
      avatarUrl: avatarUrl,
      bio: bio,
      isContentCreator: isContentCreator,
      isAdmin: isAdmin,
      isFollowing: isFollowing ?? this.isFollowing,
      postCount: postCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
