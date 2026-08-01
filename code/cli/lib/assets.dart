/// Reads framework assets (templates) from disk.
///
/// Assets live alongside the compiled binary in an `assets/` folder.
/// In production, [root] is derived from `Platform.resolvedExecutable`.
/// In tests, [root] is a temporary directory.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class Assets {
  final String root;

  Assets({required this.root});

  /// Resolves [relativePath] under `<root>/assets/`.
  String path(String relativePath) =>
      p.join(root, 'assets', p.joinAll(relativePath.split('/')));

  /// Reads the file at [relativePath] as a UTF-8 string.
  String loadString(String relativePath) =>
      File(path(relativePath)).readAsStringSync();

  /// Returns true if the file at [relativePath] exists under `<root>/assets/`.
  bool fileExists(String relativePath) =>
      File(path(relativePath)).existsSync();

  /// Returns true if the directory at [relativePath] exists under `<root>/assets/`.
  bool directoryExists(String relativePath) =>
      Directory(path(relativePath)).existsSync();

  /// Lists the immediate child directory names under `<root>/assets/[relativePath]`.
  ///
  /// Sorted, so callers that stamp files in this order behave identically on
  /// every platform — `listSync` order is filesystem-dependent and CI runs on
  /// both Linux and Windows.
  ///
  /// Throws [FileSystemException] when the directory is missing, matching
  /// [loadString]. Guard with [directoryExists] when absence is expected.
  List<String> listDirectory(String relativePath) =>
      Directory(path(relativePath))
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList()
        ..sort();
}
