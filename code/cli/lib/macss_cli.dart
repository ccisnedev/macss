/// Public API for the `macss` CLI.
///
/// [runMacss] is the single entry point — called by `bin/main.dart` and by tests.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import 'assets.dart';
import 'modules/global/global_builder.dart';

/// Configures the CLI, registers all commands, and dispatches [args].
///
/// Returns a process exit code.
Future<int> runMacss(List<String> args) async {
  final cli = ModularCli();

  final assetsRoot = p.dirname(p.dirname(Platform.resolvedExecutable));
  final assets = Assets(root: assetsRoot);

  cli.module('', (m) => buildGlobalModule(m, assets: assets));

  return cli.run(args);
}
