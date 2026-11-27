import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/src/run_from_source.dart';

/// Running the CLI under the Dart VM (`dart run bin/main.dart`) resolves its
/// assets relative to the VM, finds none, and reports a broken installation
/// with the remedy of replacing the real one (#53). The entry point refuses
/// instead, and says where the dev build is.
void main() {
  group('isRunningFromSource', () {
    for (final exe in const [
      r'C:\tools\dart-sdk\bin\dart.exe',
      '/usr/lib/dart/bin/dart',
      r'C:\tools\dart-sdk\bin\DART.EXE',
    ]) {
      test('$exe is the Dart VM', () {
        expect(isRunningFromSource(exe), isTrue);
      });
    }

    for (final exe in const [
      r'C:\repo\code\cli\dist\bin\macss.exe',
      '/home/u/.macss/bin/macss',
      '/home/u/.macss/bin/ma',
      '/opt/dart/bin/dartfmt-wrapper',
    ]) {
      test('$exe is a compiled build', () {
        expect(isRunningFromSource(exe), isFalse);
      });
    }
  });

  group('the refusal', () {
    test('names the build scripts and the dev build, and nothing misleading',
        () {
      expect(runFromSourceExitCode, 78);
      expect(runFromSourceRefusal, contains('scripts/build.ps1'));
      expect(runFromSourceRefusal, contains('scripts/build.sh'));
      expect(runFromSourceRefusal, contains('dist/bin/macss'));
      expect(runFromSourceRefusal, isNot(contains('missing')));
      expect(runFromSourceRefusal, isNot(contains('upgrade --apply')));
    });
  });

  group('dart run bin/main.dart', () {
    for (final args in const [
      ['doctor'],
      ['version'],
    ]) {
      test('${args.join(' ')} refuses with 78 and runs no command', () async {
        // Tests run from code/cli.
        final result = await Process.run(
          Platform.resolvedExecutable,
          ['run', 'bin/main.dart', ...args],
        );
        final err = result.stderr as String;

        expect(result.exitCode, 78);
        expect(err, contains('scripts/build.ps1'));
        expect(err, contains('scripts/build.sh'));
        expect(err, contains('dist/bin/macss'));
        expect(err, isNot(contains('missing')));
        expect(err, isNot(contains('upgrade --apply')));
        expect(result.stdout as String, isEmpty);
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  group('code/cli/README.md', () {
    final readme = File('README.md').readAsStringSync();

    test('documents the dev build', () {
      expect(readme, contains('scripts/build.ps1'));
      expect(readme, contains('scripts/build.sh'));
      expect(readme, contains('dist/bin/macss'));
    });

    test('says dart run does not resolve the assets', () {
      expect(readme, contains('dart run bin/main.dart'));
      expect(readme, contains('assets'));
    });
  });
}
