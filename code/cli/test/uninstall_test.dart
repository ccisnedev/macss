import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/uninstall.dart';
import 'package:macss_cli/targets/platform_ops.dart';

import 'support/memory_sink.dart';

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
  Future<void> selfReplace(
    String newBinaryPath,
    String currentBinaryPath,
  ) async =>
      calls.add('selfReplace($newBinaryPath, $currentBinaryPath)');

  @override
  Future<void> runPostInstall(String installDir) async =>
      calls.add('runPostInstall($installDir)');

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
    // The empty contract rejects the flag before execute() runs, so this never
    // touches PATH or schedules any deletion.
    test('rejects an undeclared option (empty params contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['uninstall', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('exits 0', () async {
      final ops = FakePlatformOps();
      final cmd = UninstallCommand(
        UninstallInput(installDir: tempDir.path, flags: const ChangeFlags(apply: true, autoapprove: true)),
        platformOps: ops,
      );
      final output = await cmd.execute();
      expect(output.exitCode, 0);
    });

    test('message confirms uninstall', () async {
      final ops = FakePlatformOps();
      final cmd = UninstallCommand(
        UninstallInput(installDir: tempDir.path, flags: const ChangeFlags(apply: true, autoapprove: true)),
        platformOps: ops,
      );
      final output = await cmd.execute();
      expect(output.message, contains('uninstalled'));
    });

    test('schedules deletion of install directory', () async {
      final ops = FakePlatformOps();
      final cmd = UninstallCommand(
        UninstallInput(installDir: tempDir.path, flags: const ChangeFlags(apply: true, autoapprove: true)),
        platformOps: ops,
      );
      await cmd.execute();
      expect(ops.calls, contains('scheduleDeletion(${tempDir.path})'));
    });

    test('removes bin dir from PATH when present', () async {
      final binDir = p.join(tempDir.path, 'bin');
      final sep = Platform.isWindows ? ';' : ':';
      final otherA = Platform.isWindows ? r'C:\other' : '/other';
      final otherB = Platform.isWindows ? r'C:\more' : '/more';
      final fakePath = '$otherA$sep$binDir$sep$otherB';

      final ops = FakePlatformOps(fakeEnvValue: fakePath);
      final cmd = UninstallCommand(
        UninstallInput(installDir: tempDir.path, flags: const ChangeFlags(apply: true, autoapprove: true)),
        platformOps: ops,
      );
      await cmd.execute();

      expect(ops.calls, contains('getEnvVariable(PATH)'));
      final expectedNew = '$otherA$sep$otherB';
      expect(ops.calls, contains('setEnvVariable(PATH, $expectedNew)'));
    });

    test('does not call setEnvVariable when bin dir not in PATH', () async {
      final sep = Platform.isWindows ? ';' : ':';
      final otherA = Platform.isWindows ? r'C:\other' : '/other';
      final otherB = Platform.isWindows ? r'C:\more' : '/more';

      final ops = FakePlatformOps(fakeEnvValue: '$otherA$sep$otherB');
      final cmd = UninstallCommand(
        UninstallInput(installDir: tempDir.path, flags: const ChangeFlags(apply: true, autoapprove: true)),
        platformOps: ops,
      );
      await cmd.execute();

      expect(ops.calls, contains('getEnvVariable(PATH)'));
      expect(
        ops.calls.where((c) => c.startsWith('setEnvVariable')),
        isEmpty,
      );
    });
  });
}
