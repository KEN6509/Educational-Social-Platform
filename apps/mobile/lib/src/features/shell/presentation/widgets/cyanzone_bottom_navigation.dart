import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_tokens.dart';
import '../../../../core/widgets/unread_badge.dart';

class CyanZoneBottomNavigation extends StatelessWidget {
  const CyanZoneBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.chatBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int chatBadgeCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.floatingNavigationOuterMargin,
        AppLayout.floatingNavigationOuterMargin,
        AppLayout.floatingNavigationOuterMargin,
        AppLayout.floatingNavigationOuterMargin + bottomInset,
      ),
      child: SizedBox(
        height: AppLayout.floatingNavigationHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.navigation),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180B1F3E),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
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
                  icon: Icons.supervised_user_circle_outlined,
                  selectedIcon: Icons.supervised_user_circle_rounded,
                  label: 'Parent-Child',
                  selected: selectedIndex == 1,
                  onTap: () => onTap(1),
                ),
                _CreateNavButton(
                  selected: selectedIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavButton(
                  icon: Icons.mode_comment_outlined,
                  selectedIcon: Icons.mode_comment_rounded,
                  label: 'Chats',
                  selected: selectedIndex == 3,
                  onTap: () => onTap(3),
                  badgeCount: chatBadgeCount,
                ),
                _NavButton(
                  icon: Icons.account_circle_outlined,
                  selectedIcon: Icons.account_circle_rounded,
                  label: 'Profile',
                  selected: selectedIndex == 4,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateNavButton extends StatelessWidget {
  const _CreateNavButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Create',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 58,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.control),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x260B1F3E),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.add_rounded,
            color: selected ? AppColors.surface : AppColors.navy,
            size: 31,
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.navy : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.compact),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.compact),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: selected ? 28 : 26,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 2,
                    right: 4,
                    child: UnreadBadge(count: badgeCount),
                  ),
                if (selected)
                  Positioned(
                    bottom: 1,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
