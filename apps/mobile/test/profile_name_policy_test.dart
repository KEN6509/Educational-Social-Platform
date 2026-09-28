import 'package:cyanzone_mobile/src/core/validation/profile_name_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes surrounding whitespace', () {
    expect(ProfileNamePolicy.normalize('  Ken Chan  '), 'Ken Chan');
  });

  test('accepts one through twenty-four trimmed characters', () {
    expect(ProfileNamePolicy.validate('K'), isNull);
    expect(
      ProfileNamePolicy.validate(List.filled(24, 'K').join()),
      isNull,
    );
  });

  test('rejects empty, whitespace-only, and overlong names', () {
    expect(ProfileNamePolicy.validate(''), ProfileNamePolicy.requiredError);
    expect(ProfileNamePolicy.validate('   '), ProfileNamePolicy.requiredError);
    expect(
      ProfileNamePolicy.validate(List.filled(25, 'K').join()),
      ProfileNamePolicy.lengthError,
    );
  });
}
