import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

void main() {
  group('macss help', () {
    test('lists every registered command from the SDK catalog', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['help'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      final out = await stdout.text();
      expect(code, 0);
      // SDK-rendered catalog: one source of help that cannot drift from the
      // set of registered commands.
      expect(out, contains('Global options:'));
      for (final route in const [
        'create',
        'doctor',
        'upgrade',
        'uninstall',
        'version',
        'api graphql compile',
      ]) {
        expect(out, contains(route), reason: '$route must appear in help');
      }
    });

    test('normalizes --version and -v to the version command', () {
      expect(normalizeMacssArgs(const ['--version']), equals(const ['version']));
      expect(normalizeMacssArgs(const ['-v']), equals(const ['version']));
    });

    test('leaves --help for the SDK to route', () {
      expect(normalizeMacssArgs(const ['--help']), equals(const ['--help']));
      expect(normalizeMacssArgs(const ['-h']), equals(const ['-h']));
    });
  });
}
