import 'package:flutter_dotenv/flutter_dotenv.dart';

final class ApiConfig {
  const ApiConfig._();

  static Uri get baseUrl => requireBaseUrl();

  static Uri requireBaseUrl() {
    final raw = dotenv.env['API_BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) {
      throw StateError('API_BASE_URL is required for the CyanZone API.');
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw StateError('API_BASE_URL must be a valid absolute URL.');
    }
    return parsed;
  }
}
