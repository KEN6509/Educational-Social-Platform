import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileAvatarCache {
  const ProfileAvatarCache._();

  static final Map<String, Uint8List> _memoryBytes = {};
  static final Map<String, String> _memoryUrls = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Uint8List? peek(String userId) => _memoryBytes[userId];

  static void remember(
    String userId,
    Uint8List bytes, {
    String? url,
  }) {
    _memoryBytes[userId] = bytes;
    if (url != null && url.isNotEmpty) {
      _memoryUrls[userId] = url;
    }
  }

  static Future<Uint8List?> restore(String userId) async {
    final remembered = peek(userId);
    if (remembered != null) return remembered;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      remember(
        userId,
        bytes,
        url: prefs.getString(_urlKey(userId)),
      );
      return bytes;
    } catch (_) {
      await prefs.remove(_key(userId));
      return null;
    }
  }

  static Future<Uint8List?> restoreOrFetch({
    required String userId,
    required String? url,
  }) async {
    final cached = await restore(userId);
    if (cached != null) return cached;
    return cacheFromUrl(userId: userId, url: url);
  }

  static Future<Uint8List?> cacheFromUrl({
    required String userId,
    required String? url,
  }) async {
    final active = _inFlight[userId];
    if (active != null) return active;
    final future = _cacheFromUrl(userId: userId, url: url);
    _inFlight[userId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(userId);
    }
  }

  static Future<Uint8List?> _cacheFromUrl({
    required String userId,
    required String? url,
  }) async {
    if (url == null || url.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
      await prefs.remove(_urlKey(userId));
      _memoryBytes.remove(userId);
      _memoryUrls.remove(userId);
      return null;
    }

    final cached = peek(userId);
    final prefs = await SharedPreferences.getInstance();
    final cachedUrl = _memoryUrls[userId] ?? prefs.getString(_urlKey(userId));
    if (cached != null && cachedUrl == url) return cached;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      final typedBytes = Uint8List.fromList(bytes);
      await prefs.setString(_key(userId), base64Encode(typedBytes));
      await prefs.setString(_urlKey(userId), url);
      remember(userId, typedBytes, url: url);
      return typedBytes;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _key(String userId) => 'profile_avatar_cache_$userId';
  static String _urlKey(String userId) => 'profile_avatar_url_cache_$userId';
}
