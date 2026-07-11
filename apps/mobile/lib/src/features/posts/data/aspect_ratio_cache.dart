import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent cache for image aspect ratios to prevent layout jumps in masonry grids.
class AspectRatioCache {
  static SharedPreferences? _prefs;
  static final Map<String, double> _memoryCache = {};

  /// Initializes the underlying storage.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Retrieves the cached aspect ratio for a given image URL.
  /// Checks memory cache first, then persistent storage.
  static double? get(String url) {
    if (_memoryCache.containsKey(url)) return _memoryCache[url];
    final value = _prefs?.getDouble('ar_$url');
    if (value != null) _memoryCache[url] = value;
    return value;
  }

  /// Persists the aspect ratio for a given image URL.
  static void set(String url, double ratio) {
    if (_memoryCache[url] == ratio) return;
    _memoryCache[url] = ratio;
    _prefs?.setDouble('ar_$url', ratio);
  }
}
