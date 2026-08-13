import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/upgrade.dart';
import 'package:macss_cli/modules/global/commands/version.dart';
import 'package:macss_cli/targets/platform_ops.dart';

import 'support/memory_sink.dart';

void main() {
  // Replacing an installation takes seconds and several megabytes. The plan
  // says what *will* happen; this is the only thing that says it *is*
  // happening, and there is nothing else on the terminal until it finishes.
  //
  // It was lost once — the rewrite that turned upgrade into steps dropped six
  // stderr lines, and nothing noticed, because nothing asserted them. That is
  // what this group is for.
  group('macss upgrade says what it is doing while it does it', () {
    late Directory root;
    late MemorySink progress;

    setUp(() {
      root = Directory.systemTemp.createTempSync('macss_upgrade_progress_');
      progress = MemorySink();
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    /// A stand-in for the binary being replaced.
    ///
    /// **Never `Platform.resolvedExecutable`.** Under `dart test` that is the
    /// Dart VM, and the Windows branch of this step renames the running
    /// executable aside — which is exactly how the Dart SDK's own `dart.exe`
    /// once ended up as `dart.exe.bak`, taking the toolchain with it.
    late String fakeBinary;

    Future<String> replace() async {
      fakeBinary = p.join(root.path, 'bin', 'macss.exe');
      File(fakeBinary)
        ..createSync(recursive: true)
        ..writeAsStringSync('the outgoing binary');

      await ReplaceInstallation(
        platformOps: _RecordingOps(),
        installDir: p.join(root.path, 'install'),
        from: '0.10.0',
        to: '0.11.0',
        asset: 'macss-windows-x64.zip',
        downloadUrl: 'https://example.invalid/macss-windows-x64.zip',
        download: (url, destination) async =>
            File(destination).writeAsStringSync('an archive'),
        progress: progress.sink,
        runningExecutable: fakeBinary,
      ).perform(StepContext(const {}));
      return progress.text();
    }

    test('names the asset and the versions before it downloads', () async {
      final said = await replace();

      expect(said, contains('Downloading macss-windows-x64.zip'));
      expect(said, contains('0.10.0'));
      expect(said, contains('0.11.0'));
    });

    test('says when it extracts, and where', () async {
      final said = await replace();

      expect(said, contains('Extracting into'));
      expect(said, contains(p.join(root.path, 'install')));
    });

    test('says when it verifies', () async {
      expect(await replace(), contains('Verifying installation'));
    });

    test('in the order the work happens', () async {
      final said = await replace();

      expect(said.indexOf('Downloading'), lessThan(said.indexOf('Extracting')));
      expect(said.indexOf('Extracting'), lessThan(said.indexOf('Verifying')));
    });

    // On Windows the outgoing binary cannot be overwritten in place, so it is
    // moved aside and cleaned up afterwards. The step acts on the executable it
    // was *given* — anything else, in a test, is the Dart VM.
    test('moves the outgoing binary aside and cleans it up', () async {
      await replace();

      expect(File(fakeBinary).existsSync(), isFalse,
          reason: 'it was moved aside to make room for the new one');
      expect(File('$fakeBinary.bak').existsSync(), isFalse,
          reason: 'and the backup is not left behind');
    }, testOn: 'windows');

    // stderr, not stdout: `--json` has to stay machine-readable, and a progress
    // line in the middle of a JSON document is not.
    test('none of it reaches the output the command returns', () async {
      final stdout = MemorySink();

      await runMacss(
        const ['upgrade', '--plan'],
        stdout: stdout.sink,
        stderr: MemorySink().sink,
      );

      expect(await stdout.text(), isNot(contains('Downloading')));
    });
  });

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
      // The three change flags are not here: the SDK declares them on every
      // command, so a command that also carried them would be publishing the
      // same contract twice.
      final input = UpgradeInput(installDir: '/fake/dir');

      expect(input.toJson(), {'installDir': '/fake/dir'});
    });

    test('UpgradeOutput reports no upgrade when already latest', () {
      final output = UpgradeOutput(
        previousVersion: macssVersion,
        newVersion: macssVersion,
        upgraded: false,
        reason: 'Already on the latest version',
      );
      expect(output.exitCode, 0);
      expect(output.upgraded, isFalse);
      expect(output.toJson()['reason'], contains('latest'));
    });

    test('UpgradeOutput reports successful upgrade', () {
      final output = UpgradeOutput(
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
        previousVersion: macssVersion,
        newVersion: macssVersion,
        upgraded: false,
        reason: 'Already on the latest version',
      );
      expect(output.toText(), equals('Already on the latest version'));
    });
  });
}

/// A [PlatformOps] that does nothing but remember it was asked.
class _RecordingOps implements PlatformOps {
  final List<String> calls = [];

  @override
  String get binaryName => 'macss.exe';

  @override
  String get assetName => 'macss-windows-x64.zip';

  @override
  Future<void> expandArchive(String archivePath, String destDir) async =>
      calls.add('expandArchive');

  @override
  String? getEnvVariable(String name) => null;

  @override
  Future<void> setEnvVariable(String name, String value) async {}

  @override
  Future<void> selfReplace(String a, String b) async {}

  @override
  Future<void> runPostInstall(String installDir) async =>
      calls.add('runPostInstall');

  @override
  Future<void> scheduleDeletion(String dir) async {}
}
