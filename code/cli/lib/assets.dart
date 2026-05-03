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
}
