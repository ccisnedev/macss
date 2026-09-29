import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

/// `uninstall` is no longer macss's own command: it is
/// `modular_cli_sdk`'s `InstallationPlugin`, configured with macss's own
/// repository/executable/alias/assets in `lib/macss_cli.dart`. This tests the
/// SDK's real `UninstallCommand`/`UninstallInput`/`UninstallOutput`/
/// `PlatformOps`, configured the way macss configures them.
const _config = CliInstallationConfig(
  repository: 'ccisnedev/macss',
  executable: 'macss',
  alias: 'ma',
  assets: {
    'windows': 'macss-windows-x64.zip',
    'linux': 'macss-linux-x64.tar.gz',
  },
);

/// Fake PlatformOps for testing — records calls without touching the system.
class FakePlatformOps implements PlatformOps {
  final List<String> calls = [];
  final String? fakeEnvValue;

  FakePlatformOps({this.fakeEnvValue});

  @override
  String get binaryName => 'macss';

  @override
  String get assetName => 'macss-linux-x64.tar.gz';

  @override
  Future<void> expandArchive(String archivePath, String destDir) async =>
      calls.add('expandArchive($archivePath, $destDir)');

  @override
  String? getEnvVariable(String name) {
    calls.add('getEnvVariable($name)');
    return fakeEnvValue;
  }

  @override
  Future<void> setEnvVariable(String name, String value) async =>
      calls.add('setEnvVariable($name, $value)');

  @override
  Future<ProcessResult> runPostInstall(
    String installDir, {
    Duration? timeout,
  }) async {
    calls.add('runPostInstall($installDir)');
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<void> scheduleDeletion(String dir) async =>
      calls.add('scheduleDeletion($dir)');
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_uninstall_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('UninstallCommand', () {
    // `InstallationPlugin.setup()` registers `uninstall` with no explicit
    // `contract:`, which defaults to `CliContract.none`: an empty contract
    // still rejects an undeclared option before execute() runs, so this
    // never touches PATH or schedules any deletion.
    test('rejects an undeclared option (empty contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['uninstall', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains("unknown option '--bogus'"));
    });

    test('exits 0', () async {
      final ops = FakePlatformOps();
      final output = await applyCommand(
        UninstallCommand(
          UninstallInput(installDir: tempDir.path),
          config: _config,
          platformOps: ops,
        ),
      );
      expect(output.exitCode, 0);
    });

    test('message confirms uninstall', () async {
      final ops = FakePlatformOps();
      final output = await applyCommand(
        UninstallCommand(
          UninstallInput(installDir: tempDir.path),
          config: _config,
          platformOps: ops,
        ),
      );
      expect(output.toText(), contains('Uninstalled'));
    });

    test('schedules deletion of install directory', () async {
      final ops = FakePlatformOps();
      await applyCommand(
        UninstallCommand(
          UninstallInput(installDir: tempDir.path),
          config: _config,
          platformOps: ops,
        ),
      );
      expect(ops.calls, contains('scheduleDeletion(${tempDir.path})'));
    });

    test('removes bin dir from PATH when present', () async {
      final binDir = p.join(tempDir.path, 'bin');
      final sep = Platform.isWindows ? ';' : ':';
      final otherA = Platform.isWindows ? r'C:\other' : '/other';
      final otherB = Platform.isWindows ? r'C:\more' : '/more';
      final fakePath = '$otherA$sep$binDir$sep$otherB';

      final ops = FakePlatformOps(fakeEnvValue: fakePath);
      await applyCommand(
        UninstallCommand(
          UninstallInput(installDir: tempDir.path),
          config: _config,
          platformOps: ops,
        ),
      );

      expect(ops.calls, contains('getEnvVariable(PATH)'));
      final expectedNew = '$otherA$sep$otherB';
      expect(ops.calls, contains('setEnvVariable(PATH, $expectedNew)'));
    });

    test('does not call setEnvVariable when bin dir not in PATH', () async {
      final sep = Platform.isWindows ? ';' : ':';
      final otherA = Platform.isWindows ? r'C:\other' : '/other';
      final otherB = Platform.isWindows ? r'C:\more' : '/more';

      final ops = FakePlatformOps(fakeEnvValue: '$otherA$sep$otherB');
      await applyCommand(
        UninstallCommand(
          UninstallInput(installDir: tempDir.path),
          config: _config,
          platformOps: ops,
        ),
      );

      expect(ops.calls, contains('getEnvVariable(PATH)'));
      expect(ops.calls.where((c) => c.startsWith('setEnvVariable')), isEmpty);
    });
  });
}
