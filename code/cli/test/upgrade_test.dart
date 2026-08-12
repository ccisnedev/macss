import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/upgrade.dart';
import 'package:macss_cli/modules/global/commands/version.dart';

import 'support/memory_sink.dart';

void main() {
  group('macss upgrade', () {
    // The empty contract rejects the flag before execute() runs, so this never
    // touches the network or the install directory.
    test('rejects an undeclared option (empty params contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['upgrade', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('UpgradeInput serializes correctly', () {
      final input = UpgradeInput(
        installDir: '/fake/dir',
        flags: const ChangeFlags(apply: true, autoapprove: true),
      );

      expect(input.toJson(), {
        'installDir': '/fake/dir',
        'plan': false,
        'apply': true,
        'autoapprove': true,
      });
    });

    test('UpgradeOutput reports no upgrade when already latest', () {
      final output = UpgradeOutput(
        message: 'Already on the latest version',
        previousVersion: macssVersion,
        newVersion: macssVersion,
        upgraded: false,
      );
      expect(output.exitCode, 0);
      expect(output.upgraded, isFalse);
      expect(output.toJson()['message'], contains('latest'));
    });

    test('UpgradeOutput reports successful upgrade', () {
      final output = UpgradeOutput(
        message: 'Upgraded',
        previousVersion: '0.0.1',
        newVersion: '0.0.2',
        upgraded: true,
      );
      expect(output.exitCode, 0);
      expect(output.upgraded, isTrue);
      expect(output.previousVersion, '0.0.1');
      expect(output.newVersion, '0.0.2');
    });

    test('toText returns checkmark message when upgraded', () {
      final output = UpgradeOutput(
        message: 'Upgraded',
        previousVersion: '0.0.1',
        newVersion: '0.0.2',
        upgraded: true,
      );
      expect(output.toText(), contains('✓'));
      expect(output.toText(), contains('0.0.1'));
      expect(output.toText(), contains('0.0.2'));
    });

    test('toText returns plain message when not upgraded', () {
      final output = UpgradeOutput(
        message: 'Already on the latest version',
        previousVersion: macssVersion,
        newVersion: macssVersion,
        upgraded: false,
      );
      expect(output.toText(), equals('Already on the latest version'));
    });
  });
}
