import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/src/version.dart';

import 'support/memory_sink.dart';

/// `upgrade` is no longer macss's own command: it is
/// `modular_cli_sdk`'s `InstallationPlugin`, configured with macss's own
/// repository/executable/alias/assets in `lib/macss_cli.dart`. What used to
/// be macss's own `UpgradeCommand`/`UpgradeInput`/`UpgradeOutput`/
/// `ReplaceInstallation`/`PlatformOps` now come from
/// `package:modular_cli_sdk/modular_cli_sdk.dart`; this file tests the SDK's
/// real classes, configured the way macss configures them, rather than
/// reimplementing macss's own deleted ones.
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
    late _RecordingOps ops;

    setUp(() {
      root = Directory.systemTemp.createTempSync('macss_upgrade_progress_');
      progress = MemorySink();
      ops = _RecordingOps();
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
        platformOps: ops,
        installDir: p.join(root.path, 'install'),
        from: '0.10.0',
        to: '0.11.0',
        asset: 'macss-windows-x64.zip',
        downloadUrl: 'https://example.invalid/macss-windows-x64.zip',
        downloader: (url, destination) async =>
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

    // macss's own `ReplaceInstallation` verifies the freshly extracted
    // binary inline, hard-fail, right after extraction: this is
    // `verifyAfterInstall: true`, the SDK's default, matching macss exactly.
    test('says when it verifies, by default (matching macss)', () async {
      expect(await replace(), contains('Verifying installation'));
    });

    test('in the order the work happens', () async {
      final said = await replace();

      expect(said.indexOf('Downloading'), lessThan(said.indexOf('Extracting')));
      expect(said.indexOf('Extracting'), lessThan(said.indexOf('Verifying')));
    });

    test('calls runPostInstall with the install directory', () async {
      await replace();

      expect(
        ops.calls,
        contains('runPostInstall(${p.join(root.path, 'install')})'),
      );
    });

    // macss's own `runPostInstall` never inspects the child's exit code, but
    // nothing catches a failure to even launch it (a missing binary throws),
    // which is what makes the check a hard failure in practice.
    test(
      'a failed verification fails the upgrade, hard-fail like macss',
      () async {
        ops = _RecordingOps(runPostInstallError: Exception('no such file'));

        expect(() => replace(), throwsA(isA<Exception>()));
      },
    );

    // On Windows the outgoing binary cannot be overwritten in place, so it is
    // moved aside and cleaned up afterwards. The step acts on the executable it
    // was *given* — anything else, in a test, is the Dart VM.
    test('moves the outgoing binary aside and cleans it up', () async {
      await replace();

      expect(
        File(fakeBinary).existsSync(),
        isFalse,
        reason: 'it was moved aside to make room for the new one',
      );
      expect(
        File('$fakeBinary.bak').existsSync(),
        isFalse,
        reason: 'and the backup is not left behind',
      );
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
    // `InstallationPlugin.setup()` registers `upgrade` with no explicit
    // `contract:`, which defaults to `CliContract.none`: an empty contract
    // still rejects an undeclared option before execute() runs.
    test('rejects an undeclared option (empty contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['upgrade', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains("unknown option '--bogus'"));
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
///
/// Matches the SDK's own `FakePlatformOps` shape
/// (`modular_cli_sdk` `test/plugins/installation_doubles.dart`): a calls list
/// a test asserts against, rather than a mock framework.
class _RecordingOps implements PlatformOps {
  _RecordingOps({this.runPostInstallError});

  final List<String> calls = [];
  final Object? runPostInstallError;

  @override
  String get binaryName => 'macss.exe';

  @override
  String get assetName => 'macss-windows-x64.zip';

  @override
  Future<void> expandArchive(String archivePath, String destDir) async =>
      calls.add('expandArchive($archivePath, $destDir)');

  @override
  String? getEnvVariable(String name) => null;

  @override
  Future<void> setEnvVariable(String name, String value) async {}

  @override
  Future<ProcessResult> runPostInstall(
    String installDir, {
    Duration? timeout,
  }) async {
    calls.add('runPostInstall($installDir)');
    if (runPostInstallError != null) throw runPostInstallError!;
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<void> scheduleDeletion(String dir) async {}
}
