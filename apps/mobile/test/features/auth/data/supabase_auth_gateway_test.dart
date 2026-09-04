import 'package:cyanzone_mobile/src/features/auth/data/supabase_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('exposes one stable authentication-state stream', () {
    final gateway = SupabaseAuthGateway(
      SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
      ),
    );

    final firstRead = gateway.signedInChanges;
    final secondRead = gateway.signedInChanges;

    expect(identical(firstRead, secondRead), isTrue);
  });
}
