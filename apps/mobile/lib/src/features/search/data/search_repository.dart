import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../posts/data/feed_post.dart';
import '../../posts/data/posts_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart';

class SearchResults {
  const SearchResults({
    required this.posts,
    required this.profiles,
  });

  final List<FeedPost> posts;
  final List<UserProfile> profiles;

  SearchResults withPostUpdate(
    String postId,
    Map<String, dynamic> result,
  ) {
    var changed = false;
    final updatedPosts = posts.map((post) {
      if (post.id != postId) return post;
      changed = true;
      return post.copyWith(
        likeCount: result['likeCount'] as int? ?? post.likeCount,
        dislikeCount: result['dislikeCount'] as int? ?? post.dislikeCount,
        commentCount: result['commentCount'] as int? ?? post.commentCount,
        saveCount: result['saveCount'] as int? ?? post.saveCount,
        shareCount: result['shareCount'] as int? ?? post.shareCount,
        isLiked: result['isLiked'] as bool? ?? post.isLiked,
        isDisliked: result['isDisliked'] as bool? ?? post.isDisliked,
        isSaved: result['isSaved'] as bool? ?? post.isSaved,
        dislikeHiddenUntil: result['dislikeHiddenUntil'] as DateTime? ??
            post.dislikeHiddenUntil,
      );
    }).toList();

    if (!changed) return this;
    return SearchResults(posts: updatedPosts, profiles: profiles);
  }

  SearchResults withProfileUpdate(UserProfile updatedProfile) {
    var changed = false;
    final updatedProfiles = profiles.map((profile) {
      if (profile.id != updatedProfile.id) return profile;
      changed = true;
      return updatedProfile;
    }).toList();

    if (!changed) return this;
    return SearchResults(posts: posts, profiles: updatedProfiles);
  }
}

class SearchRepository {
  SearchRepository(this._client, this._prefs);

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxHistoryLimit = 20;

  /// Loads recent searches from local storage
  List<String> getLocalRecentSearches() {
    return _prefs.getStringList(_recentSearchesKey) ?? [];
  }

  /// Saves a search query locally and logs it to the server
  Future<void> saveAndLogSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    // 1. Local caching (Strict 20 records limit)
    final searches = getLocalRecentSearches();
    // Remove if exists to move to top
    searches.removeWhere((s) => s.toLowerCase() == trimmedQuery.toLowerCase());
    // Insert at start
    searches.insert(0, trimmedQuery);
    // Strict limit check
    if (searches.length > _maxHistoryLimit) {
      searches.removeRange(_maxHistoryLimit, searches.length);
    }
    await _prefs.setStringList(_recentSearchesKey, searches);

    // 2. Server logging (Trigger in SQL handles the 20 records limit)
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.from('search_logs').insert({
          'user_id': userId,
          'query': trimmedQuery,
        });
      } catch (e) {
        // Silently fail or use a proper logger in the future
      }
    }
  }

  /// Fetches hybrid search results (For You, Posts, Profiles)
  Future<SearchResults> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const SearchResults(posts: [], profiles: []);
    }

    final profiles = await _searchProfiles(trimmedQuery);
    final posts = await _searchPosts(
      trimmedQuery,
      authorIds: profiles.map((profile) => profile.id).toList(),
    );
    // Sort by likes for "For You" weighted logic (highest count of likes)
    posts.sort((a, b) => b.likeCount.compareTo(a.likeCount));

    return SearchResults(
      posts: posts,
      profiles: profiles,
    );
  }

  Future<List<FeedPost>> _searchPosts(
    String query, {
    List<String> authorIds = const [],
  }) async {
    final textResponse = await _client
        .from('posts')
        .select(PostsRepository.feedSelectColumns)
        .eq('moderation_status', 'approved')
        .or('title.ilike.%$query%,content.ilike.%$query%')
        .order('created_at', ascending: false);

    final authorResponse = authorIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
            .from('posts')
            .select(PostsRepository.feedSelectColumns)
            .eq('moderation_status', 'approved')
            .inFilter('author_id', authorIds)
            .order('created_at', ascending: false);

    final userId = _client.auth.currentUser?.id;
    final byId = <String, FeedPost>{};
    for (final json in [...textResponse as List, ...authorResponse as List]) {
      final post = FeedPost.fromMap(json as Map<String, dynamic>, userId);
      byId[post.id] = post;
    }
    return byId.values.toList();
  }

  Future<List<UserProfile>> _searchProfiles(String query) async {
    final response = await _client
        .from('profiles')
        .select(ProfileRepository.profileCountSelectColumns)
        .or('name.ilike.%$query%,bio.ilike.%$query%')
        .limit(50);

    final followingIds = await _fetchCurrentUserFollowingIds();
    return (response as List).map((json) {
      final profileMap = Map<String, dynamic>.from(json as Map);
      final postCountData = profileMap['post_count'] as List?;
      final followerCountData = profileMap['follower_count'] as List?;
      final followingCountData = profileMap['following_count'] as List?;
      profileMap['post_count'] =
          postCountData?.firstOrNull?['count'] as int? ?? 0;
      profileMap['follower_count'] =
          followerCountData?.firstOrNull?['count'] as int? ?? 0;
      profileMap['following_count'] =
          followingCountData?.firstOrNull?['count'] as int? ?? 0;
      profileMap['is_following'] = followingIds.contains(profileMap['id']);
      return UserProfile.fromMap(profileMap);
    }).toList();
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

  /// Removes a specific search from local history
  Future<void> removeLocalSearch(String query) async {
    final searches = getLocalRecentSearches();
    searches.remove(query);
    await _prefs.setStringList(_recentSearchesKey, searches);
  }

  /// Clears all local search history
  Future<void> clearLocalHistory() async {
    await _prefs.remove(_recentSearchesKey);
  }
}
