/// Linux implementation of [PlatformOps].
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_ops.dart';

class LinuxPlatformOps implements PlatformOps {
  @override
  String get binaryName => 'macss';

  @override
  String get assetName => 'macss-linux-x64.tar.gz';

  @override
  Future<void> expandArchive(String archivePath, String destDir) async {
    final result = await Process.run('tar', [
      'xzf',
      archivePath,
      '-C',
      destDir,
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'tar',
        ['xzf', archivePath],
        'Failed to extract archive: ${result.stderr}',
        result.exitCode,
      );
    }
  }

  @override
  String? getEnvVariable(String name) => Platform.environment[name];

  @override
  Future<void> setEnvVariable(String name, String value) async {
    // On Linux, persistent env vars require modifying shell profiles.
    // The install.sh script handles PATH setup during installation.
  }

  @override
  Future<void> selfReplace(
    String newBinaryPath,
    String currentBinaryPath,
  ) async {
    final bakPath = '$currentBinaryPath.bak';
    File(currentBinaryPath).renameSync(bakPath);
    File(newBinaryPath).copySync(currentBinaryPath);
    await Process.run('chmod', ['+x', currentBinaryPath]);
    try {
      File(bakPath).deleteSync();
    } on FileSystemException {
      // Best effort
    }
  }

  @override
  Future<void> runPostInstall(String installDir) async {
    await Process.run(p.join(installDir, 'bin', binaryName), ['version']);
  }

  @override
  Future<void> scheduleDeletion(String dir) async {
    await Process.start('rm', ['-rf', dir], mode: ProcessStartMode.detached);
  }
}
