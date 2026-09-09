import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import 'notification_settings_page.dart';
import 'set_password_page.dart';
import 'verified_badge_page.dart';
import '../../notifications/application/push_notification_coordinator.dart';
import '../../notifications/presentation/push_notification_scope.dart';

typedef SignOutAction = Future<void> Function();

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.loadNotificationPreferences,
    this.saveNotificationPreferences,
    this.signOut,
    this.verifiedBadgePageBuilder,
    this.pushNotificationCoordinator,
  });

  final NotificationPreferenceLoader? loadNotificationPreferences;
  final NotificationPreferenceSaver? saveNotificationPreferences;
  final SignOutAction? signOut;
  final WidgetBuilder? verifiedBadgePageBuilder;
  final PushNotificationCoordinator? pushNotificationCoordinator;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSigningOut = false;

  Future<void> _confirmLogout() async {
    if (_isSigningOut) return;

    final shouldLogout = await showAppConfirmationDialog(
      context: context,
      icon: Icons.logout_rounded,
      iconColor: const Color(0xFFE11D48),
      iconBackgroundColor: const Color(0xFFFFE4E6),
      title: 'Log out?',
      message: 'Are you sure you want to log out of CyanZone?',
      primaryLabel: 'Log out',
      primaryColor: const Color(0xFFE11D48),
    );
    if (shouldLogout != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await (widget.pushNotificationCoordinator ??
              PushNotificationScope.maybeOf(context))
          ?.beforeSignOut();
      await (widget.signOut ?? Supabase.instance.client.auth.signOut).call();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not log out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildSectionHeader('ACCOUNT'),
            _buildSection([
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Account Security',
                subtitle: 'Change password',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SetPasswordPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 48),
              _SettingsTile(
                icon: Icons.verified_rounded,
                title: 'Verified Badge',
                subtitle: 'Requirements and application',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: widget.verifiedBadgePageBuilder ??
                          (_) => const VerifiedBadgePage(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('GENERAL'),
            _buildSection([
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notification',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationSettingsPage(
                        loadNotificationPreferences:
                            widget.loadNotificationPreferences,
                        saveNotificationPreferences:
                            widget.saveNotificationPreferences,
                        pushNotificationCoordinator:
                            widget.pushNotificationCoordinator ??
                                PushNotificationScope.maybeOf(context),
                      ),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection([
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                titleColor: const Color(0xFFE11D48),
                showChevron: false,
                onTap: _confirmLogout,
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.showChevron = true,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: titleColor ?? const Color(0xFF475569),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? const Color(0xFF1E293B),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
