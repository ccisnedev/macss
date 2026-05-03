/// Cross-platform abstraction for OS-specific shell operations.
library;

import 'dart:io' show Platform;

import 'linux_platform_ops.dart';
import 'windows_platform_ops.dart';

/// Abstract contract for platform-specific operations.
abstract class PlatformOps {
  /// The compiled binary name for this platform (e.g. `macss.exe` or `macss`).
  String get binaryName;

  /// The release asset name for this platform (e.g. `macss-windows-x64.zip`).
  String get assetName;

  /// Extract an archive to [destDir].
  Future<void> expandArchive(String archivePath, String destDir);

  /// Read a system environment variable. Returns `null` if not set.
  String? getEnvVariable(String name);

  /// Write a system environment variable.
  Future<void> setEnvVariable(String name, String value);

  /// Replace the currently running binary with a new one.
  Future<void> selfReplace(String newBinaryPath, String currentBinaryPath);

  /// Run post-install steps (verify version) using the correct binary.
  Future<void> runPostInstall(String installDir);

  /// Schedule deletion of a directory after the current process exits.
  Future<void> scheduleDeletion(String dir);

  /// Factory that returns the correct implementation for the current OS.
  factory PlatformOps.current() {
    if (Platform.isWindows) return WindowsPlatformOps();
    if (Platform.isLinux) return LinuxPlatformOps();
    throw UnsupportedError(
      'PlatformOps: unsupported OS "${Platform.operatingSystem}"',
    );
  }
}
