/// Windows implementation of [PlatformOps].
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_ops.dart';

class WindowsPlatformOps implements PlatformOps {
  @override
  String get binaryName => 'macss.exe';

  @override
  String get assetName => 'macss-windows-x64.zip';

  @override
  Future<void> expandArchive(String archivePath, String destDir) async {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -Path "$archivePath" -DestinationPath "$destDir" -Force',
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell',
        ['Expand-Archive'],
        'Failed to extract archive: ${result.stderr}',
        result.exitCode,
      );
    }
  }

  @override
  String? getEnvVariable(String name) {
    final result = Process.runSync('powershell', [
      '-NoProfile',
      '-Command',
      '[System.Environment]::GetEnvironmentVariable("$name", "User")',
    ]);
    if (result.exitCode != 0) return null;
    final value = (result.stdout as String).trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> setEnvVariable(String name, String value) async {
    Process.runSync('powershell', [
      '-NoProfile',
      '-Command',
      '[System.Environment]::SetEnvironmentVariable("$name", "$value", "User")',
    ]);
  }

  @override
  Future<void> selfReplace(
    String newBinaryPath,
    String currentBinaryPath,
  ) async {
    final bakPath = '$currentBinaryPath.bak';
    final bakFile = File(bakPath);
    if (bakFile.existsSync()) bakFile.deleteSync();
    File(currentBinaryPath).renameSync(bakPath);
    File(newBinaryPath).copySync(currentBinaryPath);
    try {
      if (bakFile.existsSync()) bakFile.deleteSync();
    } on FileSystemException {
      // Still locked — will be cleaned up on next upgrade
    }
  }

  @override
  Future<void> runPostInstall(String installDir) async {
    await Process.run(p.join(installDir, 'bin', binaryName), ['version']);
  }

  @override
  Future<void> scheduleDeletion(String dir) async {
    final currentExe = File(Platform.resolvedExecutable);
    final bakPath = '${Platform.resolvedExecutable}.bak';
    try {
      currentExe.renameSync(bakPath);
    } on FileSystemException {
      // Best effort
    }
    final bat = File(p.join(Directory.systemTemp.path, 'macss_cleanup.cmd'));
    bat.writeAsStringSync(
      '@echo off\r\n'
      'timeout /t 2 /nobreak >nul\r\n'
      'rmdir /s /q "$dir"\r\n'
      'del "%~f0"\r\n',
    );
    await Process.start(
      'cmd.exe',
      ['/c', bat.path],
      mode: ProcessStartMode.detached,
    );
  }
}
