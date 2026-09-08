import 'package:cyanzone_mobile/src/app_dependencies.dart';
import 'package:cyanzone_mobile/src/features/auth/data/supabase_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('production dependencies use the Supabase authentication adapter', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );

    final dependencies = AppDependencies.production(
      client,
      apiBaseUrl: Uri.parse('https://api.cyanzone.test'),
    );

    expect(dependencies.authGateway, isA<SupabaseAuthGateway>());
  });
}
