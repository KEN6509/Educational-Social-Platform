import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/feed_post.dart';
import '../data/posts_repository.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => HomeFeedPageState();
}

class HomeFeedPageState extends State<HomeFeedPage> {
  late final PostsRepository _repository;
  late Future<List<FeedPost>> _future;
  List<FeedPost> _cachedPosts = const [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _repository = PostsRepository(Supabase.instance.client);
    _future = _repository.fetchFeed();
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
      _future = _repository.fetchFeed();
    });
    try {
      await _future;
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeedPost>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedPosts = snapshot.data!;
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && _cachedPosts.isEmpty) {
          return _FeedMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Feed needs a quick refresh',
            message: snapshot.error.toString(),
            actionLabel: 'Try again',
            onAction: refresh,
          );
        }

        final posts = snapshot.data ?? _cachedPosts;
        if (posts.isEmpty) {
          return _FeedMessage(
            icon: Icons.auto_stories_outlined,
            title: 'Create your first learning post',
            message:
                'Share notes, questions, diagrams, or study tips. Your post will appear here while it waits for review.',
            actionLabel: 'Refresh',
            onAction: refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _InlineWarning(message: snapshot.error.toString()),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => _FeedCard(
                    key: ValueKey(posts[index].id),
                    post: posts[index],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF9A5B00)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Showing cached posts. Refresh issue: $message',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7A4A00),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.post, super.key});

  final FeedPost post;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _showQuickActions = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;

    return Card(
      elevation: 2,
      shadowColor: const Color(0x160B1F3E),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE6F0F1)),
      ),
      child: InkWell(
        onLongPress: () {
          setState(() => _showQuickActions = !_showQuickActions);
        },
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PostImage(url: post.imageUrls.firstOrNull),
                  if (post.isPending)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusBadge(
                        label: 'Pending',
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                  if (_showQuickActions)
                    Positioned.fill(
                      child: _QuickActionsOverlay(
                        onDismiss: () {
                          setState(() => _showQuickActions = false);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFE7F8F5),
                        child: Text(
                          post.authorName.characters.first.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF2C7189),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF536A74),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 15,
                        color: Color(0xFF6E828A),
                      ),
                    ],
                  ),
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: post.tags.take(2).map(_MiniTag.new).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsOverlay extends StatelessWidget {
  const _QuickActionsOverlay({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x990B1F3E),
      child: Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _QuickActionButton(
              icon: Icons.sentiment_dissatisfied_rounded,
              label: 'Dislike',
              onTap: onDismiss,
            ),
            _QuickActionButton(
              icon: Icons.flag_outlined,
              label: 'Report',
              onTap: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0B1F3E)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF0B1F3E),
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7FBF5), Color(0xFFDDEFF5)],
          ),
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: Color(0xFF4490AD),
          size: 38,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFE7F4F6),
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF4490AD)),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF2C7189),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF9A5B00)),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7A4A00),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onAction,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 72),
          Icon(icon, size: 54, color: const Color(0xFF4490AD)),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF536A74),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
