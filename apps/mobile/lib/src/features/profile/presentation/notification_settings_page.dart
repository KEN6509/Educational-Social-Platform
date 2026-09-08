import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef NotificationPreferenceLoader = Future<Map<String, bool>> Function();
typedef NotificationPreferenceSaver = Future<void> Function(
  Map<String, bool> preferences,
);

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.loadNotificationPreferences,
    this.saveNotificationPreferences,
  });

  final NotificationPreferenceLoader? loadNotificationPreferences;
  final NotificationPreferenceSaver? saveNotificationPreferences;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late Future<_NotificationPreferenceState> _preferencesFuture;

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
          'Notification',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<_NotificationPreferenceState>(
        future: _preferencesFuture,
        builder: (context, snapshot) {
          final prefs = snapshot.data ?? const _NotificationPreferenceState();
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionHeader('IN-APP NOTIFICATIONS'),
                _SettingsGroup(
                  children: [
                    _PreferenceSwitch(
                      icon: Icons.notifications_none_rounded,
                      title: 'In-app notifications',
                      subtitle:
                          'Control all CyanZone badges and notification lists.',
                      value: prefs.inAppEnabled,
                      enabled: !isLoading,
                      onChanged: (value) => _updatePreference(
                        prefs,
                        'in_app_enabled',
                        value,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'Phone push notifications are not enabled yet.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('NOTIFICATION TYPES'),
                _SettingsGroup(
                  children: [
                    _PreferenceSwitch(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Chat badges',
                      value: prefs.chatEnabled,
                      enabled: !isLoading && prefs.inAppEnabled,
                      onChanged: (value) => _updatePreference(
                        prefs,
                        'chat_enabled',
                        value,
                      ),
                    ),
                    const _SettingsDivider(),
                    _PreferenceSwitch(
                      icon: Icons.notifications_active_outlined,
                      title: 'Activity messages',
                      value: prefs.activityEnabled,
                      enabled: !isLoading && prefs.inAppEnabled,
                      onChanged: (value) => _updatePreference(
                        prefs,
                        'activity_enabled',
                        value,
                      ),
                    ),
                    const _SettingsDivider(),
                    _PreferenceSwitch(
                      icon: Icons.shield_outlined,
                      title: 'System notifications',
                      value: prefs.systemEnabled,
                      enabled: !isLoading && prefs.inAppEnabled,
                      onChanged: (value) => _updatePreference(
                        prefs,
                        'system_enabled',
                        value,
                      ),
                    ),
                    const _SettingsDivider(),
                    _PreferenceSwitch(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'New followers',
                      value: prefs.followersEnabled,
                      enabled: !isLoading && prefs.inAppEnabled,
                      onChanged: (value) => _updatePreference(
                        prefs,
                        'followers_enabled',
                        value,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 52);
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: Icon(icon, size: 22, color: const Color(0xFF334155)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.35,
              ),
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: const Color(0xFF4490AD),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFE2E8F0),
      onChanged: enabled ? onChanged : null,
    );
  }
}
