part of 'profile_page.dart';

enum _ProfilePostGridMode { posted, saved, liked }

class _ProfilePostGrid extends StatefulWidget {
  const _ProfilePostGrid({
    required this.fetcher,
    required this.mode,
    required this.profileUserId,
    required this.refreshVersion,
    this.onPostDeleted,
  });

  final Future<List<FeedPost>> Function() fetcher;
  final _ProfilePostGridMode mode;
  final String profileUserId;
  final int refreshVersion;
  final VoidCallback? onPostDeleted;

  @override
  State<_ProfilePostGrid> createState() => _ProfilePostGridState();
}

class _ProfilePostGridState extends State<_ProfilePostGrid> {
  static final Map<String, List<FeedPost>> _postedPostsCache = {};

  late Future<List<FeedPost>> _future;
  Future<List<FeedPost>>? _appliedFuture;
  List<FeedPost> _posts = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == _ProfilePostGridMode.posted) {
      _posts = _orderedPostedPostsFromMemoryCache();
      _restoreCachedPostedPosts();
    }
    _future = _fetchPostsWithRatios();
    PostInteractionSync.latest.addListener(_handlePostInteractionUpdate);
  }

  @override
  void dispose() {
    PostInteractionSync.latest.removeListener(_handlePostInteractionUpdate);
    super.dispose();
  }

  void _handlePostInteractionUpdate() {
    final update = PostInteractionSync.latest.value;
    if (!mounted || update == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final canInsertForProfile = widget.profileUserId == currentUserId;
    final insertIfMissing = canInsertForProfile &&
        ((widget.mode == _ProfilePostGridMode.liked && update.post.isLiked) ||
            (widget.mode == _ProfilePostGridMode.saved && update.post.isSaved));

    final hadPost = _posts.any((post) => post.id == update.postId);
    final updatedPosts = update.applyToPosts(
      _posts,
      insertIfMissing: insertIfMissing,
    );
    if (updatedPosts == _posts) return;
    final orderedPosts = widget.mode == _ProfilePostGridMode.posted
        ? orderProfilePosts(updatedPosts)
        : updatedPosts;

    setState(() {
      _posts = orderedPosts;
    });
    if (widget.mode == _ProfilePostGridMode.posted && update.isDeleted) {
      _postedPostsCache[widget.profileUserId] = List<FeedPost>.of(orderedPosts);
      unawaited(_cachePostedPosts(orderedPosts));
      if (hadPost) widget.onPostDeleted?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _ProfilePostGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fetcher != widget.fetcher ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      if (widget.mode == _ProfilePostGridMode.posted) {
        _posts = _orderedPostedPostsFromMemoryCache(fallback: _posts);
      }
      _future = _fetchPostsWithRatios();
      _appliedFuture = null;
    }
  }

  List<FeedPost> _orderedPostedPostsFromMemoryCache({
    List<FeedPost> fallback = const <FeedPost>[],
  }) {
    final cached = _postedPostsCache[widget.profileUserId] ?? fallback;
    return orderProfilePosts(
      cached.where((post) => post.moderationStatus != 'removed'),
    );
  }

  Future<List<FeedPost>> _fetchPostsWithRatios() async {
    if (!await _hasInternetConnection()) {
      throw const SocketException('No internet connection');
    }
    var posts = await widget.fetcher().timeout(
          const Duration(seconds: 5),
        );
    if (widget.mode == _ProfilePostGridMode.posted) {
      posts = orderProfilePosts(posts);
    }
    await PostCardRatioPreloader.preload(posts);
    unawaited(
      PostImageDiskCache.cacheUrls(
        posts.take(12).expand((post) => post.imageUrls),
      ),
    );
    if (widget.mode == _ProfilePostGridMode.posted) {
      _postedPostsCache[widget.profileUserId] = List<FeedPost>.of(posts);
      await _cachePostedPosts(posts);
    }
    return posts;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _restoreCachedPostedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postedPostsCacheKey);
    if (raw == null || raw.isEmpty || !mounted || _posts.isNotEmpty) return;
    try {
      final rows = (jsonDecode(raw) as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(FeedPost.fromCacheMap)
          .where((post) => post.moderationStatus != 'removed');
      final orderedRows = orderProfilePosts(rows);
      _postedPostsCache[widget.profileUserId] = orderedRows;
      if (mounted && _posts.isEmpty) {
        setState(() {
          _posts = orderedRows;
        });
      }
    } catch (_) {
      await prefs.remove(_postedPostsCacheKey);
    }
  }

  Future<void> _cachePostedPosts(List<FeedPost> posts) async {
    final visiblePosts =
        posts.where((post) => post.moderationStatus != 'removed').toList();
    await PostImageDiskCache.cacheUrls(
      visiblePosts
          .map((post) => post.imageUrls.firstOrNull)
          .whereType<String>(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _postedPostsCacheKey,
      jsonEncode(visiblePosts.map((post) => post.toCacheMap()).toList()),
    );
  }

  String get _postedPostsCacheKey =>
      'profile_posted_posts_cache_${widget.profileUserId}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeedPost>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData && _appliedFuture != _future) {
          _appliedFuture = _future;
          _posts = snapshot.data ?? <FeedPost>[];
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _posts.isEmpty) {
          return const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: PostWaterfallSkeleton(),
          );
        }

        if (snapshot.hasError &&
            _posts.isEmpty &&
            widget.mode == _ProfilePostGridMode.posted &&
            friendlyErrorTitle(snapshot.error) == 'No internet connection') {
          return const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: PostWaterfallSkeleton(),
          );
        }

        if (snapshot.hasError && _posts.isEmpty) {
          return _ProfileGridError(error: snapshot.error);
        }

        if (_posts.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.45,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No posts yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: PostWaterfallGrid(
            posts: _posts,
            cardBuilder: (context, post) {
              return FeedCard(
                key: ValueKey('profile_post_${post.id}'),
                post: post,
                heroTag: 'profile_post_${post.id}',
                showQuickActions: false,
                enableQuickActions: false,
                onToggleQuickActions: () {},
                onResult: (_) {},
              );
            },
          ),
        );
      },
    );
  }
}

class _ProfileGridError extends StatelessWidget {
  const _ProfileGridError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.38,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  friendlyErrorTitle(error),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friendlyErrorMessage(error),
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
