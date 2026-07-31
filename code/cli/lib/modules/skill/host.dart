/// Where each AI assistant expects to find its skills.
///
/// MACSS deploys to a project-local `.skills/` directory by default, which no
/// assistant auto-detects but every assistant can be pointed at. `--host` is the
/// opt-in for people who want auto-detection from the assistant's own location.
///
/// Only hosts whose skill directory convention is actually known are listed.
/// Guessing a path here would create directories in a user's home that no tool
/// ever reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The assistants `--host` accepts.
const supportedHosts = <String>['claude', 'opencode'];

/// The absolute skills directory for [host], or null when the home directory
/// cannot be resolved.
String? hostSkillsDirectory(String host, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'];
  if (home == null || home.isEmpty) return null;

  return switch (host) {
    'claude' => p.join(home, '.claude', 'skills'),
    'opencode' => p.join(home, '.config', 'opencode', 'skill'),
    _ => null,
  };
}
