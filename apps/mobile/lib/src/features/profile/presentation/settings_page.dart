import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/theme/app_design_tokens.dart';
import 'notification_settings_page.dart';
import 'set_password_page.dart';
import 'verified_badge_page.dart';
import '../../notifications/application/push_notification_coordinator.dart';
import '../../notifications/presentation/push_notification_scope.dart';

part 'settings_widgets.dart';

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
      iconColor: AppColors.error,
      iconBackgroundColor: const Color(0xFFFFE4E6),
      title: 'Log out?',
      message: 'Are you sure you want to log out of CyanZone?',
      primaryLabel: 'Log out',
      primaryColor: AppColors.error,
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
        AppFeedback.showError(context, 'Could not log out. Please try again.');
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
            _SettingsSectionHeader(title: 'ACCOUNT'),
            _SettingsSection(children: [
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
            _SettingsSectionHeader(title: 'GENERAL'),
            _SettingsSection(children: [
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
            _SettingsSection(children: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                titleColor: AppColors.error,
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
}
