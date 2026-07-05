# Activity and New Followers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the redesigned New Followers and Activity notification pages with 30-day follower dedupe, richer activity rows, filter dropdowns, profile/post navigation, and backend support for comment replies/comment likes.

**Architecture:** Keep the feature inside the existing chat notification module. Extend `ChatNotification` and `ChatRepository` with small, testable helpers for filtering, dedupe, and activity mapping; then update `NotificationSectionsPage` to render New Followers and Activity with section-specific rows. Update `supabase/chat.sql` notification triggers/types so the client receives explicit activity events.

**Tech Stack:** Flutter, Dart, Supabase/PostgREST, PL/pgSQL, `flutter_test`.

---

## Files and responsibilities

- `apps/mobile/lib/src/features/chat/data/chat_models.dart`
  - Extend `ChatNotification` metadata and add computed helpers for activity/follower display.
- `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
  - Select richer notification data.
  - Add pure filtering helpers for New Followers and Activity category filtering.
  - Add post fetching helper for Activity row navigation.
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
  - Replace generic notification list with section-specific New Followers and Activity UI.
  - Add Activity filter dropdown.
  - Add follower row profile navigation and activity row post navigation.
- `supabase/chat.sql`
  - Add `comment_reply` and `comment_like` notification types.
  - Update comment trigger logic.
  - Add comment-like trigger.
- `apps/mobile/test/chat_models_test.dart`
  - Cover model parsing and display helpers.
- `apps/mobile/test/chat_repository_test.dart`
  - Cover pure filter/dedupe/category helpers and source-level select checks where Supabase mocking is not available.
- `apps/mobile/test/chat_widgets_test.dart`
  - Cover Activity/New Followers UI behavior.
- `apps/mobile/test/chat_sql_migration_test.dart`
  - Cover SQL trigger/type additions.

---

### Task 1: Extend `ChatNotification` metadata and display helpers

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/data/chat_models.dart`
- Test: `apps/mobile/test/chat_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Add these tests inside the existing `group('ChatNotification', () { ... })` block in `apps/mobile/test/chat_models_test.dart`.

```dart
test('parses post and comment metadata for activity notifications', () {
  final notification = ChatNotification.fromMap({
    'id': 'notification-activity-1',
    'type': 'comment_reply',
    'actor_id': 'actor-1',
    'post_id': 'post-1',
    'comment_id': 'comment-1',
    'title': 'Reply',
    'body': 'Someone replied',
    'created_at': '2026-07-05T10:15:00Z',
    'profiles': {'name': 'Ming', 'avatar_url': 'https://cdn/actor.png'},
    'posts': {
      'author_id': 'author-1',
      'profiles': {'avatar_url': 'https://cdn/post-author.png'},
      'post_images': [
        {
          'public_url': 'https://cdn/second.png',
          'position': 1,
        },
        {
          'public_url': 'https://cdn/first.png',
          'position': 0,
        },
      ],
    },
  });

  expect(notification.postId, 'post-1');
  expect(notification.commentId, 'comment-1');
  expect(notification.actorName, 'Ming');
  expect(notification.actorAvatarUrl, 'https://cdn/actor.png');
  expect(notification.postFirstImageUrl, 'https://cdn/first.png');
  expect(notification.postAuthorAvatarUrl, 'https://cdn/post-author.png');
  expect(notification.activityLabel, 'replied to your comment');
  expect(notification.activityGroup, NotificationActivityGroup.comments);
});

test('maps mention notifications to green mention activity group', () {
  final notification = ChatNotification.fromMap({
    'id': 'notification-mention-1',
    'type': 'mention',
    'title': 'Mention',
    'body': 'Someone mentioned you',
    'created_at': '2026-07-05T10:15:00Z',
  });

  expect(notification.activityLabel, 'mentioned you');
  expect(notification.activityGroup, NotificationActivityGroup.mentions);
});
```

- [ ] **Step 2: Run model tests and verify they fail**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_models_test.dart
```

Expected: fails because `postId`, `commentId`, `postFirstImageUrl`, `postAuthorAvatarUrl`, `activityLabel`, and `NotificationActivityGroup` do not exist yet.

- [ ] **Step 3: Add enum and model fields**

In `apps/mobile/lib/src/features/chat/data/chat_models.dart`, near the existing `NotificationSection` enum, add:

```dart
enum NotificationActivityGroup { likesFavorites, comments, mentions, other }
```

Update `ChatNotification` constructor and fields:

```dart
class ChatNotification {
  const ChatNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.actorId,
    this.actorName,
    this.actorAvatarUrl,
    this.postId,
    this.commentId,
    this.postFirstImageUrl,
    this.postAuthorAvatarUrl,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? actorId;
  final String? actorName;
  final String? actorAvatarUrl;
  final String? postId;
  final String? commentId;
  final String? postFirstImageUrl;
  final String? postAuthorAvatarUrl;
```

- [ ] **Step 4: Add activity helpers and parsing**

Still in `ChatNotification`, add:

```dart
  NotificationActivityGroup get activityGroup {
    switch (type) {
      case 'like':
      case 'favorite':
        return NotificationActivityGroup.likesFavorites;
      case 'comment':
      case 'comment_reply':
      case 'comment_like':
        return NotificationActivityGroup.comments;
      case 'mention':
        return NotificationActivityGroup.mentions;
      default:
        return NotificationActivityGroup.other;
    }
  }

  String get activityLabel {
    switch (type) {
      case 'like':
        return 'liked your post';
      case 'favorite':
        return 'saved your post';
      case 'comment':
        return 'commented on your post';
      case 'comment_reply':
        return 'replied to your comment';
      case 'comment_like':
        return 'liked your comment';
      case 'mention':
        return 'mentioned you';
      default:
        return body;
    }
  }
```

In `ChatNotification.fromMap`, before returning, parse post data:

```dart
    final post = (map['posts'] ?? map['posts!notifications_post_id_fkey'])
        as Map<String, dynamic>?;
    final postImages = (post?['post_images'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort(
        (a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0),
      );
    final postAuthorProfile =
        (post?['profiles'] ?? post?['profiles!posts_author_id_fkey'])
            as Map<String, dynamic>?;
```

Then add these constructor arguments:

```dart
      postId: _nullableStringValue(map['post_id'] ?? map['postId']),
      commentId: _nullableStringValue(map['comment_id'] ?? map['commentId']),
      postFirstImageUrl: _nullableStringValue(
        postImages.isEmpty ? map['post_first_image_url'] : postImages.first['public_url'],
      ),
      postAuthorAvatarUrl: _nullableStringValue(
        postAuthorProfile?['avatar_url'] ?? map['post_author_avatar_url'],
      ),
```

- [ ] **Step 5: Run model tests and verify they pass**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_models_test.dart
```

Expected: all `chat_models_test.dart` tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_models.dart apps/mobile/test/chat_models_test.dart
git commit -m "feat: enrich chat notification model"
```

---

### Task 2: Add repository filtering helpers and richer notification select

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Test: `apps/mobile/test/chat_repository_test.dart`

- [ ] **Step 1: Write failing repository helper tests**

Add these tests to `apps/mobile/test/chat_repository_test.dart` inside `group('ChatRepository', () { ... })`.

```dart
test('filters new followers to latest 30 days and one actor per local day', () {
  final now = DateTime(2026, 7, 5, 12);
  final notifications = [
    ChatNotification.fromMap({
      'id': 'old',
      'type': 'new_follower',
      'actor_id': 'u1',
      'title': 'New follower',
      'body': 'followed',
      'created_at': '2026-05-01T10:00:00',
    }),
    ChatNotification.fromMap({
      'id': 'same-day-old',
      'type': 'new_follower',
      'actor_id': 'u2',
      'title': 'New follower',
      'body': 'followed',
      'created_at': '2026-07-05T09:00:00',
    }),
    ChatNotification.fromMap({
      'id': 'same-day-new',
      'type': 'new_follower',
      'actor_id': 'u2',
      'title': 'New follower',
      'body': 'followed',
      'created_at': '2026-07-05T11:00:00',
    }),
    ChatNotification.fromMap({
      'id': 'different-day',
      'type': 'new_follower',
      'actor_id': 'u2',
      'title': 'New follower',
      'body': 'followed',
      'created_at': '2026-07-04T11:00:00',
    }),
  ];

  final filtered = ChatRepository.visibleNewFollowerNotifications(
    notifications,
    now: now,
  );

  expect(filtered.map((item) => item.id), [
    'same-day-new',
    'different-day',
  ]);
});

test('filters activity notifications by category', () {
  final notifications = [
    ChatNotification.fromMap({
      'id': 'like',
      'type': 'like',
      'title': 'Like',
      'body': 'Like',
      'created_at': '2026-07-05T10:00:00',
    }),
    ChatNotification.fromMap({
      'id': 'comment',
      'type': 'comment_reply',
      'title': 'Reply',
      'body': 'Reply',
      'created_at': '2026-07-05T10:00:00',
    }),
    ChatNotification.fromMap({
      'id': 'mention',
      'type': 'mention',
      'title': 'Mention',
      'body': 'Mention',
      'created_at': '2026-07-05T10:00:00',
    }),
  ];

  expect(
    ChatRepository.filterActivityNotifications(
      notifications,
      NotificationActivityFilter.likesFavorites,
    ).map((item) => item.id),
    ['like'],
  );
  expect(
    ChatRepository.filterActivityNotifications(
      notifications,
      NotificationActivityFilter.comments,
    ).map((item) => item.id),
    ['comment'],
  );
  expect(
    ChatRepository.filterActivityNotifications(
      notifications,
      NotificationActivityFilter.mentions,
    ).map((item) => item.id),
    ['mention'],
  );
});

test('notification select includes post image and post author avatar data', () {
  final source = File('lib/src/features/chat/data/chat_repository.dart')
      .readAsStringSync();

  expect(source, contains('post_id'));
  expect(source, contains('comment_id'));
  expect(source, contains('posts!notifications_post_id_fkey'));
  expect(source, contains('post_images(public_url, position)'));
  expect(source, contains('profiles!posts_author_id_fkey(avatar_url)'));
});
```

Add this import at the top:

```dart
import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
```

- [ ] **Step 2: Run repository tests and verify they fail**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart
```

Expected: fails because the helper enum/functions and select columns do not exist.

- [ ] **Step 3: Add activity filter enum and helpers**

In `apps/mobile/lib/src/features/chat/data/chat_repository.dart`, near the top-level class area before `class ChatRepository`, add:

```dart
enum NotificationActivityFilter {
  all('Activity'),
  likesFavorites('Likes & Favorites'),
  comments('Comments'),
  mentions('Mentions');

  const NotificationActivityFilter(this.label);

  final String label;
}
```

Inside `ChatRepository`, add static helpers:

```dart
  static List<ChatNotification> visibleNewFollowerNotifications(
    List<ChatNotification> notifications, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final cutoff = reference.subtract(const Duration(days: 30));
    final byActorDay = <String, ChatNotification>{};

    for (final notification in notifications) {
      if (notification.section != NotificationSection.followers ||
          notification.createdAt.isBefore(cutoff) ||
          notification.actorId == null) {
        continue;
      }
      final local = notification.createdAt;
      final key =
          '${notification.actorId}-${local.year}-${local.month}-${local.day}';
      final existing = byActorDay[key];
      if (existing == null ||
          notification.createdAt.isAfter(existing.createdAt)) {
        byActorDay[key] = notification;
      }
    }

    final result = byActorDay.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static List<ChatNotification> filterActivityNotifications(
    List<ChatNotification> notifications,
    NotificationActivityFilter filter,
  ) {
    if (filter == NotificationActivityFilter.all) {
      return notifications
          .where((item) => item.section == NotificationSection.activity)
          .toList();
    }

    final expectedGroup = switch (filter) {
      NotificationActivityFilter.likesFavorites =>
        NotificationActivityGroup.likesFavorites,
      NotificationActivityFilter.comments => NotificationActivityGroup.comments,
      NotificationActivityFilter.mentions => NotificationActivityGroup.mentions,
      NotificationActivityFilter.all => NotificationActivityGroup.other,
    };

    return notifications
        .where(
          (item) =>
              item.section == NotificationSection.activity &&
              item.activityGroup == expectedGroup,
        )
        .toList();
  }
```

- [ ] **Step 4: Extend notification select and follower fetch**

Replace `_notificationSelectColumns` with:

```dart
  static const _notificationSelectColumns =
      'id, type, actor_id, post_id, comment_id, title, body, created_at, read_at, '
      'profiles!notifications_actor_id_fkey(name, avatar_url), '
      'posts!notifications_post_id_fkey(author_id, '
      'profiles!posts_author_id_fkey(avatar_url), '
      'post_images(public_url, position))';
```

In `fetchNotifications`, after `_notificationListFromResponse(response)`, apply follower dedupe only for follower section:

```dart
    final notifications = _notificationListFromResponse(response);
    if (section == NotificationSection.followers) {
      return visibleNewFollowerNotifications(notifications);
    }
    return notifications;
```

- [ ] **Step 5: Run repository tests and verify they pass**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart
```

Expected: all `chat_repository_test.dart` tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/test/chat_repository_test.dart
git commit -m "feat: filter social notifications"
```

---

### Task 3: Redesign New Followers UI and profile navigation

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing widget test**

Add this test to `apps/mobile/test/chat_widgets_test.dart`.

```dart
testWidgets('New Followers rows open follower profile and show latest label',
    (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationSectionsPage(
        initialSection: NotificationSection.followers,
        loadNotifications: (_) async => [
          ChatNotification.fromMap({
            'id': 'follower-1',
            'type': 'new_follower',
            'actor_id': 'user-follower-1',
            'title': 'New follower',
            'body': 'Someone started following you',
            'created_at': '2026-07-05T08:30:00',
            'profiles': {
              'name': 'Alicia',
              'avatar_url': 'https://cdn/alicia.png',
            },
          }),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('New Followers'), findsOneWidget);
  expect(find.text('Alicia'), findsOneWidget);
  expect(find.textContaining('Started following you'), findsOneWidget);

  await tester.tap(find.text('Alicia'));
  await tester.pumpAndSettle();

  expect(find.text('Alicia'), findsWidgets);
});
```

- [ ] **Step 2: Run widget test and verify it fails**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "New Followers rows open follower profile"
```

Expected: fails because row tap navigation is not implemented.

- [ ] **Step 3: Import profile page and add row tap**

In `notification_sections_page.dart`, add:

```dart
import '../../profile/presentation/profile_page.dart';
```

Add helper method in `_NotificationSectionsPageState`:

```dart
  void _openFollowerProfile(ChatNotification notification) {
    final actorId = notification.actorId;
    if (actorId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: actorId,
          initialName: notification.actorName,
          initialAvatarUrl: notification.actorAvatarUrl,
        ),
      ),
    );
  }
```

In the follower `ListTile`, set:

```dart
                  onTap: isFollower
                      ? () => _openFollowerProfile(notification)
                      : null,
```

Keep `_FollowerActionButton` as `trailing` so its own tap behavior remains separate.

- [ ] **Step 4: Run widget test and verify it passes**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "New Followers rows open follower profile"
```

Expected: test passes.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: open follower profiles from notifications"
```

---

### Task 4: Add Activity filter dropdown and rich activity rows

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing Activity UI test**

Add this test to `apps/mobile/test/chat_widgets_test.dart`.

```dart
testWidgets('Activity page shows filter dropdown and rich activity row',
    (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationSectionsPage(
        initialSection: NotificationSection.activity,
        loadNotifications: (_) async => [
          ChatNotification.fromMap({
            'id': 'activity-1',
            'type': 'mention',
            'actor_id': 'actor-1',
            'post_id': 'post-1',
            'title': 'Mention',
            'body': 'Someone mentioned you',
            'created_at': '2026-07-05T08:30:00',
            'profiles': {
              'name': 'Kenny',
              'avatar_url': 'https://cdn/kenny.png',
            },
            'posts': {
              'author_id': 'post-author-1',
              'profiles': {'avatar_url': 'https://cdn/post-author.png'},
              'post_images': [
                {'public_url': 'https://cdn/post.png', 'position': 0}
              ],
            },
          }),
          ChatNotification.fromMap({
            'id': 'activity-2',
            'type': 'like',
            'actor_id': 'actor-2',
            'post_id': 'post-2',
            'title': 'Like',
            'body': 'Someone liked your post',
            'created_at': '2026-07-05T08:00:00',
            'profiles': {'name': 'Ming'},
          }),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Activity'), findsWidgets);
  expect(find.text('Kenny'), findsOneWidget);
  expect(find.text('mentioned you'), findsOneWidget);
  expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);

  await tester.tap(find.text('Activity').last);
  await tester.pumpAndSettle();
  expect(find.text('Likes & Favorites'), findsOneWidget);
  expect(find.text('Comments'), findsOneWidget);
  expect(find.text('Mentions'), findsOneWidget);

  await tester.tap(find.text('Mentions'));
  await tester.pumpAndSettle();

  expect(find.text('Kenny'), findsOneWidget);
  expect(find.text('Ming'), findsNothing);
});
```

- [ ] **Step 2: Run Activity widget test and verify it fails**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "Activity page shows filter dropdown"
```

Expected: fails because filter dropdown/rich rows are not implemented.

- [ ] **Step 3: Add Activity filter state**

In `_NotificationSectionsPageState`, add:

```dart
  NotificationActivityFilter _activityFilter = NotificationActivityFilter.all;
  bool _showActivityFilters = false;
```

Change `_title` for activity:

```dart
      case NotificationSection.activity:
        return 'Activity';
```

In `build`, wrap the body in a `Stack` so the dropdown can overlay the list:

```dart
        body: Stack(
          children: [
            FutureBuilder<List<ChatNotification>>(
              future: _future,
              builder: (context, snapshot) {
                // existing body logic, modified in next steps
              },
            ),
            if (_section == NotificationSection.activity && _showActivityFilters)
              _ActivityFilterDropdown(
                selected: _activityFilter,
                onDismiss: () => setState(() => _showActivityFilters = false),
                onSelect: (filter) {
                  setState(() {
                    _activityFilter = filter;
                    _showActivityFilters = false;
                  });
                },
              ),
          ],
        ),
```

- [ ] **Step 4: Add app bar filter chip for Activity**

Replace app bar `title` with:

```dart
          title: _section == NotificationSection.activity
              ? _ActivityFilterChip(
                  label: _activityFilter.label,
                  isExpanded: _showActivityFilters,
                  onTap: () => setState(
                    () => _showActivityFilters = !_showActivityFilters,
                  ),
                )
              : Text(_title, style: chatAppBarTitleStyle),
```

Add widget:

```dart
class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({
    required this.label,
    required this.isExpanded,
    required this.onTap,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: chatAppBarTitleStyle),
          const SizedBox(width: 4),
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF111827),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add dropdown panel**

Add widget:

```dart
class _ActivityFilterDropdown extends StatelessWidget {
  const _ActivityFilterDropdown({
    required this.selected,
    required this.onSelect,
    required this.onDismiss,
  });

  final NotificationActivityFilter selected;
  final ValueChanged<NotificationActivityFilter> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.12),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: NotificationActivityFilter.values.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 20,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final filter = NotificationActivityFilter.values[index];
                  return ListTile(
                    onTap: () => onSelect(filter),
                    title: Text(
                      filter.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    trailing: filter == selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF0B1F3E),
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Filter notifications and add activity row builder**

Before rendering the list, transform:

```dart
            var notifications = snapshot.data ?? const [];
            if (_section == NotificationSection.activity) {
              notifications = ChatRepository.filterActivityNotifications(
                notifications,
                _activityFilter,
              );
            }
```

Replace the `ListTile` branch with:

```dart
                if (_section == NotificationSection.activity) {
                  return _ActivityNotificationTile(
                    notification: notification,
                    onTap: () => _openActivityPost(notification),
                  );
                }
```

Add helper:

```dart
  Future<void> _openActivityPost(ChatNotification notification) async {
    final postId = notification.postId;
    if (postId == null) return;
    try {
      final post = await _repo.fetchPostForNotification(postId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }
```

Add imports:

```dart
import '../../posts/presentation/post_detail_page.dart';
```

- [ ] **Step 7: Add repository post helper**

In `chat_repository.dart`, import posts classes:

```dart
import '../../posts/data/feed_post.dart';
import '../../posts/data/posts_repository.dart';
```

Add:

```dart
  Future<FeedPost> fetchPostForNotification(String postId) {
    return PostsRepository(_client).fetchPostById(postId);
  }
```

- [ ] **Step 8: Add `_ActivityNotificationTile`**

Add widget:

```dart
class _ActivityNotificationTile extends StatelessWidget {
  const _ActivityNotificationTile({
    required this.notification,
    required this.onTap,
  });

  final ChatNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actorName = notification.actorName ?? 'Someone';
    return InkWell(
      onTap: notification.postId == null ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            _ActivityAvatar(notification: notification, name: actorName),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    height: 1.25,
                  ),
                  children: [
                    TextSpan(
                      text: actorName,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' ${notification.activityLabel}'),
                    TextSpan(
                      text:
                          ' · ${_formatNotificationTime(notification.createdAt)}',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ActivityPostPreview(notification: notification),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Add avatar badge and preview widgets**

Add:

```dart
class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({required this.notification, required this.name});

  final ChatNotification notification;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChatAvatar(name: name, avatarUrl: notification.actorAvatarUrl),
        Positioned(
          right: -2,
          bottom: -2,
          child: _ActivityBadge(notification: notification),
        ),
      ],
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.notification});

  final ChatNotification notification;

  @override
  Widget build(BuildContext context) {
    final data = switch (notification.type) {
      'like' => (
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE5484D),
        ),
      'favorite' => (
          icon: Icons.bookmark_rounded,
          color: const Color(0xFFEAB308),
        ),
      'mention' => (
          icon: Icons.alternate_email_rounded,
          color: const Color(0xFF16A34A),
        ),
      'comment_like' => (
          icon: Icons.favorite_rounded,
          color: const Color(0xFF2563EB),
        ),
      _ => (
          icon: Icons.mode_comment_rounded,
          color: const Color(0xFF2563EB),
        ),
    };

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: data.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(data.icon, size: 11, color: Colors.white),
    );
  }
}

class _ActivityPostPreview extends StatelessWidget {
  const _ActivityPostPreview({required this.notification});

  final ChatNotification notification;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        notification.postFirstImageUrl ?? notification.postAuthorAvatarUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFF1F5F9),
        child: imageUrl == null
            ? const Icon(
                Icons.article_outlined,
                color: Color(0xFF94A3B8),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.article_outlined,
                  color: Color(0xFF94A3B8),
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run Activity widget test and verify it passes**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "Activity page shows filter dropdown"
```

Expected: test passes.

- [ ] **Step 11: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: redesign activity notifications"
```

---

### Task 5: Update SQL notification types and comment rules

**Files:**
- Modify: `supabase/chat.sql`
- Test: `apps/mobile/test/chat_sql_migration_test.dart`

- [ ] **Step 1: Write failing SQL migration tests**

Add this test to `apps/mobile/test/chat_sql_migration_test.dart`.

```dart
test('chat SQL supports comment reply and comment like activity notifications',
    () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();

  expect(sql, contains("'comment_reply'"));
  expect(sql, contains("'comment_like'"));
  expect(sql, contains('notify_comment_like'));
  expect(sql, contains('notify_comment_like_on_insert'));
  expect(sql, contains('new.parent_comment_id'));
  expect(sql, contains('parent.author_id'));
  expect(sql, contains('comment_likes'));
  expect(sql, contains('liked your comment'));
  expect(sql, contains('replied to your comment'));
});
```

- [ ] **Step 2: Run SQL test and verify it fails**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_sql_migration_test.dart --name "comment reply and comment like"
```

Expected: fails because new types/triggers are missing.

- [ ] **Step 3: Update notification type check**

In `supabase/chat.sql`, update both notification type check definitions to include:

```sql
'comment_reply'
'comment_like'
```

The final check should include:

```sql
check (type in (
  'chat_message',
  'like',
  'favorite',
  'comment',
  'comment_reply',
  'comment_like',
  'mention',
  'system',
  'new_follower'
));
```

- [ ] **Step 4: Replace comment notification function body**

In `public.notify_post_comment()`, keep the post author lookup and mention insert, but add parent comment lookup:

```sql
declare
  v_post_author_id uuid;
  v_parent_author_id uuid;
begin
  select p.author_id into v_post_author_id
  from public.posts p
  where p.id = new.post_id;

  if new.parent_comment_id is not null then
    select parent.author_id into v_parent_author_id
    from public.comments parent
    where parent.id = new.parent_comment_id;
  end if;
```

For post author notifications, insert:

```sql
  if v_post_author_id is not null and v_post_author_id <> new.author_id then
    insert into public.notifications (
      user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload
    )
    select
      v_post_author_id,
      case when new.parent_comment_id is null then 'comment' else 'comment_reply' end,
      new.author_id,
      new.post_id,
      new.id,
      case when new.parent_comment_id is null then 'New comment' else 'New reply' end,
      case when new.parent_comment_id is null then 'commented on your post' else 'replied to a comment on your post' end,
      'open_post',
      jsonb_build_object('post_id', new.post_id, 'comment_id', new.id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_post_author_id
    ), true);
  end if;
```

For direct comment owner reply notifications, add:

```sql
  if v_parent_author_id is not null
    and v_parent_author_id <> new.author_id
    and v_parent_author_id is distinct from v_post_author_id
  then
    insert into public.notifications (
      user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload
    )
    select
      v_parent_author_id,
      'comment_reply',
      new.author_id,
      new.post_id,
      new.id,
      'New reply',
      'replied to your comment',
      'open_post',
      jsonb_build_object('post_id', new.post_id, 'comment_id', new.id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_parent_author_id
    ), true);
  end if;
```

Keep mention behavior, but set its body to:

```sql
'mentioned you'
```

- [ ] **Step 5: Add comment-like trigger function**

Add after `notify_post_comment()`:

```sql
create or replace function public.notify_comment_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_comment_author_id uuid;
  v_post_id uuid;
begin
  select c.author_id, c.post_id
  into v_comment_author_id, v_post_id
  from public.comments c
  where c.id = new.comment_id;

  if v_comment_author_id is not null and v_comment_author_id <> new.user_id then
    insert into public.notifications (
      user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload
    )
    select
      v_comment_author_id,
      'comment_like',
      new.user_id,
      v_post_id,
      new.comment_id,
      'Comment liked',
      'liked your comment',
      'open_post',
      jsonb_build_object('post_id', v_post_id, 'comment_id', new.comment_id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_comment_author_id
    ), true)
      and not exists (
        select 1
        from public.notifications existing
        where existing.user_id = v_comment_author_id
          and existing.type = 'comment_like'
          and existing.actor_id = new.user_id
          and existing.comment_id = new.comment_id
      );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_comment_like_on_insert on public.comment_likes;
create trigger notify_comment_like_on_insert
after insert on public.comment_likes
for each row execute function public.notify_comment_like();
```

- [ ] **Step 6: Run SQL test and verify it passes**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_sql_migration_test.dart --name "comment reply and comment like"
```

Expected: test passes.

- [ ] **Step 7: Commit**

```powershell
git add supabase/chat.sql apps/mobile/test/chat_sql_migration_test.dart
git commit -m "feat: add comment activity notifications"
```

---

### Task 6: Polish empty/error states and run full verification

**Files:**
- Modify if needed: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Test: existing chat tests

- [ ] **Step 1: Ensure empty states are section/filter specific**

In `notification_sections_page.dart`, add helper:

```dart
  ({String title, String subtitle, IconData icon}) get _emptyState {
    if (_section == NotificationSection.followers) {
      return (
        title: 'No recent followers',
        subtitle: 'Followers from the last 30 days will appear here.',
        icon: Icons.group_outlined,
      );
    }
    if (_section == NotificationSection.activity) {
      return (
        title: 'No activity',
        subtitle: _activityFilter == NotificationActivityFilter.all
            ? 'Likes, saves, comments, and mentions will appear here.'
            : 'No ${_activityFilter.label.toLowerCase()} yet.',
        icon: Icons.notifications_none_rounded,
      );
    }
    return (
      title: 'No notifications',
      subtitle: 'New updates will appear here when something happens.',
      icon: Icons.notifications_none_rounded,
    );
  }
```

Use `_emptyState` in the `notifications.isEmpty` branch:

```dart
              final emptyState = _emptyState;
              return ChatEmptyState(
                title: emptyState.title,
                subtitle: emptyState.subtitle,
                icon: emptyState.icon,
              );
```

- [ ] **Step 2: Run focused chat tests**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_models_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_sql_migration_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Format changed Dart files**

Run:

```powershell
cd apps/mobile
dart format lib/src/features/chat/data/chat_models.dart lib/src/features/chat/data/chat_repository.dart lib/src/features/chat/presentation/notification_sections_page.dart test/chat_models_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_sql_migration_test.dart
```

Expected: formatter completes without errors.

- [ ] **Step 4: Analyze**

Run:

```powershell
cd apps/mobile
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 5: Run full tests**

Run:

```powershell
cd apps/mobile
flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 6: Commit verification polish**

If Task 6 changed files:

```powershell
git add apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart
git commit -m "polish: refine notification empty states"
```

If Task 6 only ran verification and changed nothing, do not create an empty commit.

---

## Self-review notes

- Spec coverage:
  - New Followers 30-day filtering and same-day actor dedupe: Task 2.
  - New Followers profile navigation: Task 3.
  - Activity title/filter dropdown: Task 4.
  - Activity badge colors and labels: Tasks 1 and 4.
  - Activity right-side post preview: Tasks 1, 2, and 4.
  - Activity post navigation: Task 4.
  - Comment owner/post owner notification rules: Task 5.
  - Comment-like notification support: Task 5.
  - System Notifications left out of scope: no task changes system behavior except shared empty-state fallback.
- Placeholder scan:
  - No `TBD`, `TODO`, or unspecified "handle later" implementation steps remain.
- Type consistency:
  - `NotificationActivityGroup` lives in `chat_models.dart`.
  - `NotificationActivityFilter` lives in `chat_repository.dart`.
  - `ChatNotification.activityLabel` and `activityGroup` are used by repository/UI.
  - `ChatRepository.visibleNewFollowerNotifications`, `filterActivityNotifications`, and `fetchPostForNotification` have matching task references.
