import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../posts/presentation/create_post_page.dart';
import '../../posts/presentation/home_feed_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _homeKey = GlobalKey<HomeFeedPageState>();
  int _index = 0;

  void _handlePostCreated() {
    setState(() => _index = 0);
    _homeKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeFeedPage(key: _homeKey),
      const _ComingSoonPage(
        icon: Icons.family_restroom_outlined,
        title: 'Parent-Child',
        message:
            'Linking, check-ins, screen time, and SOS alerts are next in Phase 4.',
      ),
      CreatePostPage(onPostCreated: _handlePostCreated),
      const _ComingSoonPage(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chats',
        message: 'A safe learning chat experience will be added after posts.',
      ),
      const _ProfilePreviewPage(),
    ];

    return Scaffold(
      appBar: _index == 0 ? const _HomeAppBar() : null,
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: _CyanZoneNavBar(
        selectedIndex: _index,
        onTap: (value) {
          if (value == 0 && _index == 0) {
            _homeKey.currentState?.refresh();
            return;
          }
          setState(() => _index = value);
        },
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      centerTitle: true,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton.filledTonal(
          tooltip: 'Filter',
          onPressed: () => _showComingSoonSheet(
            context,
            title: 'Filter',
            message: 'Category filters will be connected after the feed loop.',
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ),
      title: Image.asset(
        'assets/images/logo.png',
        height: 36,
        semanticLabel: 'CyanZone logo',
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filledTonal(
            tooltip: 'Search',
            onPressed: () => _showComingSoonSheet(
              context,
              title: 'Search',
              message: 'Search for posts and users will be added soon.',
            ),
            icon: const Icon(Icons.search_rounded),
          ),
        ),
      ],
    );
  }

  void _showComingSoonSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
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
            ],
          ),
        );
      },
    );
  }
}

class _CyanZoneNavBar extends StatelessWidget {
  const _CyanZoneNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1ECEE))),
        boxShadow: [
          BoxShadow(
            color: Color(0x140B1F3E),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset > 0 ? 2 : 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavButton(
                icon: Icons.family_restroom_outlined,
                selectedIcon: Icons.family_restroom_rounded,
                label: 'Parent-Child',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _CreateNavButton(
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavButton(
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                selected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavButton(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                selected: selectedIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0B1F3E) : const Color(0xFF6E828A);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? const Color(0xFFE7F8F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 54,
            height: 48,
            child: Icon(
              selected ? selectedIcon : icon,
              color: color,
              size: selected ? 27 : 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateNavButton extends StatelessWidget {
  const _CreateNavButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Create',
      child: Material(
        color: const Color(0xFF0B1F3E),
        shape: const CircleBorder(),
        elevation: selected ? 4 : 1,
        shadowColor: const Color(0x550B1F3E),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF4490AD)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
          ],
        ),
      ),
    );
  }
}

class _ProfilePreviewPage extends StatelessWidget {
  const _ProfilePreviewPage();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDEBED)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE7F8F5),
                  child: Icon(Icons.person_rounded, color: Color(0xFF4490AD)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? 'CyanZone user',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Profile tabs will connect to posts, saves, and likes soon.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF536A74),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
