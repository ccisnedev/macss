import 'package:test/test.dart';

import 'package:macss_cli/src/version_check.dart';

void main() {
  group('isNewerVersion', () {
    test('returns true when remote major is higher', () {
      expect(isNewerVersion('2.0.0', '1.0.0'), isTrue);
    });

    test('returns true when remote minor is higher', () {
      expect(isNewerVersion('0.1.0', '0.0.9'), isTrue);
    });

    test('returns true when remote patch is higher', () {
      expect(isNewerVersion('0.0.2', '0.0.1'), isTrue);
    });

    test('returns false when versions are equal', () {
      expect(isNewerVersion('0.0.1', '0.0.1'), isFalse);
    });

    test('returns false when remote is lower', () {
      expect(isNewerVersion('0.0.1', '0.0.2'), isFalse);
    });

    test('returns false for malformed semver', () {
      expect(isNewerVersion('not-a-version', '0.0.1'), isFalse);
      expect(isNewerVersion('0.0.1', 'not-a-version'), isFalse);
    });
  });
}
