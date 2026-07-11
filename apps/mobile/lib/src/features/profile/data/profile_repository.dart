import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  static const profileCountSelectColumns = '''
    *,
    post_count:posts!posts_author_id_fkey(count),
    follower_count:follows!follows_following_id_fkey(count),
    following_count:follows!follows_follower_id_fkey(count)
  ''';

  static const followerSelectColumns =
      'profiles!follows_follower_id_fkey(id, email, name, avatar_url, bio, is_content_creator, is_admin)';

  static const followingSelectColumns =
      'profiles!follows_following_id_fkey(id, email, name, avatar_url, bio, is_content_creator, is_admin)';

  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select(profileCountSelectColumns)
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;

    // Extract counts from nested count objects
    final profileMap = Map<String, dynamic>.from(response);

    final approvedPosts = await _client
        .from('posts')
        .select('id')
        .eq('author_id', userId)
        .eq('moderation_status', 'approved');
    profileMap['post_count'] = (approvedPosts as List).length;

    // Follower count
    final followerCountData = profileMap['follower_count'] as List?;
    profileMap['follower_count'] =
        followerCountData?.firstOrNull?['count'] as int? ?? 0;

    // Following count
    final followingCountData = profileMap['following_count'] as List?;
    profileMap['following_count'] =
        followingCountData?.firstOrNull?['count'] as int? ?? 0;

    profileMap['is_following'] = await isFollowing(userId);

    return UserProfile.fromMap(profileMap);
  }

  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) return false;

    final existing = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return existing != null;
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('You need to log in to follow users.');
    }
    if (currentUserId == targetUserId) return false;

    final existing = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId);
      return false;
    }

    await _client.from('follows').insert({
      'follower_id': currentUserId,
      'following_id': targetUserId,
    });
    return true;
  }

  Future<bool> followUser(String targetUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('You need to log in to follow users.');
    }
    if (currentUserId == targetUserId) return false;
    if (await isFollowing(targetUserId)) return true;

    try {
      await _client.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': targetUserId,
      });
    } catch (_) {
      if (await isFollowing(targetUserId)) return true;
      rethrow;
    }
    return true;
  }

  Future<List<UserProfile>> fetchFollowers(String userId) async {
    final response = await _client
        .from('follows')
        .select(followerSelectColumns)
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    return _profilesFromFollowRows(
      response.cast<Map<String, dynamic>>(),
      'profiles',
    );
  }

  Future<List<UserProfile>> fetchFollowing(String userId) async {
    final response = await _client
        .from('follows')
        .select(followingSelectColumns)
        .eq('follower_id', userId)
        .order('created_at', ascending: false);

    return _profilesFromFollowRows(
      response.cast<Map<String, dynamic>>(),
      'profiles',
    );
  }

  Future<List<UserProfile>> _profilesFromFollowRows(
    List<Map<String, dynamic>> rows,
    String profileKey,
  ) async {
    final profiles = rows
        .map((row) => row[profileKey])
        .whereType<Map<String, dynamic>>()
        .map(UserProfile.fromMap)
        .toList();

    final followingIds = await _fetchCurrentUserFollowingIds();
    return profiles
        .map((profile) => profile.copyWith(
              isFollowing: followingIds.contains(profile.id),
            ))
        .toList();
  }

  Future<Set<String>> _fetchCurrentUserFollowingIds() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return <String>{};

    final response = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', currentUserId);

    return response
        .cast<Map<String, dynamic>>()
        .map((row) => row['following_id'] as String)
        .toSet();
  }

  Future<void> updateProfile({
    required String userId,
    String? name,
    String? bio,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', userId);
  }
}
