import 'package:test/test.dart';

import 'package:macss_cli/modules/global/commands/version.dart';

void main() {
  group('macss version', () {
    test('returns current version string', () async {
      final command = VersionCommand(VersionInput());
      final output = await command.execute();

      expect(output.exitCode, 0);
      expect(output.version, macssVersion);
      expect(output.version, isNotEmpty);
    });

    test('version matches semver format', () {
      expect(macssVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('toText returns version string', () async {
      final command = VersionCommand(VersionInput());
      final output = await command.execute();
      expect(output.toText(), macssVersion);
    });
  });
}
