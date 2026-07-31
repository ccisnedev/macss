import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/version.dart';

import 'support/memory_sink.dart';

void main() {
  group('macss version', () {
    test('rejects an undeclared option (empty params contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['version', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

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
