/// Where each AI assistant keeps its skills, in the user's home directory.
///
/// Skills are deployed once per machine, not once per repository: a project-local
/// copy would have to be refreshed in every clone, which is the opposite of a
/// rare operation.
///
/// Only hosts whose skill directory convention is actually known are listed.
/// Guessing a path here would create directories in a user's home that no tool
/// ever reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The assistants `--host` accepts.
const supportedHosts = <String>['claude', 'opencode'];

/// Where [host] is deployed to, and the directory whose presence means [host] is
/// actually installed on this machine.
class HostPaths {
  /// The directory MACSS writes `<skill>/SKILL.md` into.
  final String skillsDirectory;

  /// The assistant's own config root. Its absence means the assistant is not
  /// installed, so an unqualified deploy skips it rather than creating a tree
  /// nothing will read.
  final String markerDirectory;

  const HostPaths({required this.skillsDirectory, required this.markerDirectory});
}

/// Resolves the paths for [host], or null when the host is unknown or the home
/// directory cannot be determined.
HostPaths? hostPaths(String host, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'];
  if (home == null || home.isEmpty) return null;

  return switch (host) {
    'claude' => HostPaths(
        skillsDirectory: p.join(home, '.claude', 'skills'),
        markerDirectory: p.join(home, '.claude'),
      ),
    'opencode' => HostPaths(
        skillsDirectory: p.join(home, '.config', 'opencode', 'skill'),
        markerDirectory: p.join(home, '.config', 'opencode'),
      ),
    _ => null,
  };
}

/// The supported hosts that appear to be installed on this machine.
///
/// Used when no `--host` is given, so a bare `macss skill deploy` refreshes
/// every assistant the user actually has.
List<String> detectHosts({Map<String, String>? environment}) => [
      for (final host in supportedHosts)
        if (_isInstalled(host, environment)) host,
    ];

bool _isInstalled(String host, Map<String, String>? environment) {
  final paths = hostPaths(host, environment: environment);
  return paths != null && Directory(paths.markerDirectory).existsSync();
}
