import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/help.dart';

void main() {
  group('HelpCommand', () {
    test('returns the global CLI help summary', () async {
      final output = await HelpCommand(HelpInput()).execute();

      expect(output.exitCode, ExitCode.ok);
      expect(output.toText(), contains('Usage:'));
      expect(output.toText(), contains('macss help'));
      expect(output.toText(), contains('Root commands:'));
      expect(output.toText(), contains('Modules:'));
      expect(output.toText(), contains('api graphql compile'));
      expect(output.toText(), contains('create'));
    });

    test('normalizes global help flags to the help command', () {
      expect(normalizeMacssArgs(const ['--help']), equals(const ['help']));
      expect(normalizeMacssArgs(const ['-h']), equals(const ['help']));
      expect(normalizeMacssArgs(const ['help']), equals(const ['help']));
      expect(
        normalizeMacssArgs(const ['api', 'graphql', 'compile']),
        equals(const ['api', 'graphql', 'compile']),
      );
    });
  });
}