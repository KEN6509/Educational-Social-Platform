import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'set_password_page.dart';

typedef NotificationPreferenceLoader = Future<Map<String, bool>> Function();
typedef NotificationPreferenceSaver = Future<void> Function(
  Map<String, bool> preferences,
);
typedef SignOutAction = Future<void> Function();

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.loadNotificationPreferences,
    this.saveNotificationPreferences,
    this.signOut,
  });

  final NotificationPreferenceLoader? loadNotificationPreferences;
  final NotificationPreferenceSaver? saveNotificationPreferences;
  final SignOutAction? signOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<_NotificationPreferenceState> _preferencesFuture;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = _loadPreferences();
  }

  Future<_NotificationPreferenceState> _loadPreferences() async {
    final injectedLoader = widget.loadNotificationPreferences;
    if (injectedLoader != null) {
      return _NotificationPreferenceState.fromMap(await injectedLoader());
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const _NotificationPreferenceState();

    final row = await Supabase.instance.client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return const _NotificationPreferenceState();
    return _NotificationPreferenceState.fromMap(row);
  }

  Future<void> _updatePreference(
    _NotificationPreferenceState current,
    String key,
    bool value,
  ) async {
    final next = current.copyWithKey(key, value);
    setState(() {
      _preferencesFuture = Future.value(next);
    });

    try {
      final injectedSaver = widget.saveNotificationPreferences;
      if (injectedSaver != null) {
        await injectedSaver(next.toMap());
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('notification_preferences').upsert({
        'user_id': userId,
        'in_app_enabled': next.inAppEnabled,
        'chat_enabled': next.chatEnabled,
        'activity_enabled': next.activityEnabled,
        'system_enabled': next.systemEnabled,
        'followers_enabled': next.followersEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferencesFuture = Future.value(current);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update notification setting.'),
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    if (_isSigningOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of CyanZone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
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
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('IN-APP NOTIFICATIONS'),
            FutureBuilder<_NotificationPreferenceState>(
              future: _preferencesFuture,
              builder: (context, snapshot) {
                final prefs =
                    snapshot.data ?? const _NotificationPreferenceState();
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                return _buildSection([
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'These settings control CyanZone in-app badges and notification lists. Phone push notifications are not enabled yet.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  _PreferenceSwitch(
                    title: 'In-app notifications',
                    value: prefs.inAppEnabled,
                    enabled: !isLoading,
                    onChanged: (value) =>
                        _updatePreference(prefs, 'in_app_enabled', value),
                  ),
                  _PreferenceSwitch(
                    title: 'Chat badges',
                    value: prefs.chatEnabled,
                    enabled: !isLoading && prefs.inAppEnabled,
                    onChanged: (value) =>
                        _updatePreference(prefs, 'chat_enabled', value),
                  ),
                  _PreferenceSwitch(
                    title: 'Activity messages',
                    value: prefs.activityEnabled,
                    enabled: !isLoading && prefs.inAppEnabled,
                    onChanged: (value) =>
                        _updatePreference(prefs, 'activity_enabled', value),
                  ),
                  _PreferenceSwitch(
                    title: 'System notifications',
                    value: prefs.systemEnabled,
                    enabled: !isLoading && prefs.inAppEnabled,
                    onChanged: (value) =>
                        _updatePreference(prefs, 'system_enabled', value),
                  ),
                  _PreferenceSwitch(
                    title: 'New followers',
                    value: prefs.followersEnabled,
                    enabled: !isLoading && prefs.inAppEnabled,
                    onChanged: (value) =>
                        _updatePreference(prefs, 'followers_enabled', value),
                  ),
                ]);
              },
            ),
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

class _NotificationPreferenceState {
  const _NotificationPreferenceState({
    this.inAppEnabled = true,
    this.chatEnabled = true,
    this.activityEnabled = true,
    this.systemEnabled = true,
    this.followersEnabled = true,
  });

  final bool inAppEnabled;
  final bool chatEnabled;
  final bool activityEnabled;
  final bool systemEnabled;
  final bool followersEnabled;

  factory _NotificationPreferenceState.fromMap(Map<String, dynamic> map) {
    return _NotificationPreferenceState(
      inAppEnabled: map['in_app_enabled'] as bool? ?? true,
      chatEnabled: map['chat_enabled'] as bool? ?? true,
      activityEnabled: map['activity_enabled'] as bool? ?? true,
      systemEnabled: map['system_enabled'] as bool? ?? true,
      followersEnabled: map['followers_enabled'] as bool? ?? true,
    );
  }

  _NotificationPreferenceState copyWithKey(String key, bool value) {
    return _NotificationPreferenceState(
      inAppEnabled: key == 'in_app_enabled' ? value : inAppEnabled,
      chatEnabled: key == 'chat_enabled' ? value : chatEnabled,
      activityEnabled: key == 'activity_enabled' ? value : activityEnabled,
      systemEnabled: key == 'system_enabled' ? value : systemEnabled,
      followersEnabled: key == 'followers_enabled' ? value : followersEnabled,
    );
  }

  Map<String, bool> toMap() {
    return {
      'in_app_enabled': inAppEnabled,
      'chat_enabled': chatEnabled,
      'activity_enabled': activityEnabled,
      'system_enabled': systemEnabled,
      'followers_enabled': followersEnabled,
    };
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: const Color(0xFF4490AD),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFE2E8F0),
      onChanged: enabled ? onChanged : null,
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
