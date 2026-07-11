import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PostImageDiskCache {
  const PostImageDiskCache._();

  static final Map<String, File> _memoryFiles = {};
  static final Map<String, Future<File?>> _inFlight = {};

  static File? peek(String url) => _memoryFiles[url];

  static void remember(String url, File file) {
    _memoryFiles[url] = file;
  }

  static Future<void> cacheUrls(Iterable<String> urls) async {
    final uniqueUrls = urls.where((url) => url.isNotEmpty).toSet();
    await Future.wait(uniqueUrls.map(cacheUrl));
  }

  static Future<File?> cachedFile(String url) async {
    final remembered = peek(url);
    if (remembered != null && remembered.existsSync()) return remembered;
    final file = await _fileForUrl(url);
    if (!file.existsSync()) return null;
    remember(url, file);
    return file;
  }

  static Future<File?> cacheUrl(String url) async {
    final active = _inFlight[url];
    if (active != null) return active;

    final future = _cacheUrl(url);
    _inFlight[url] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(url);
    }
  }

  static Future<File?> _cacheUrl(String url) async {
    final existing = await cachedFile(url);
    if (existing != null) return existing;

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
      final file = await _fileForUrl(url);
      await file.writeAsBytes(bytes, flush: true);
      remember(url, file);
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> _fileForUrl(String url) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory('${directory.path}/post_image_cache');
    if (!cacheDirectory.existsSync()) {
      cacheDirectory.createSync(recursive: true);
    }
    return File('${cacheDirectory.path}/${_stableKey(url)}.img');
  }

  static String _stableKey(String value) {
    final encoded = utf8.encode(value);
    var hash = 0x811c9dc5;
    for (final byte in encoded) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
