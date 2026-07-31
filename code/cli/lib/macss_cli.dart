/// Public API for the `macss` CLI.
///
/// [runMacss] is the single entry point — called by `bin/main.dart` and by tests.
library;

import 'dart:io' as io;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import 'assets.dart';
import 'src/api/graphql/compile_runner.dart';
import 'modules/api/api_builder.dart';
import 'modules/global/global_builder.dart';
import 'modules/issue/issue_builder.dart';
import 'modules/specification/specification_builder.dart';

/// `--help` / `-h` are left to the SDK, which routes every help request itself
/// (including the focused `macss <command> --help`). Only `--version` / `-v`
/// need normalizing, since the SDK has no version convention.
List<String> normalizeMacssArgs(List<String> args) {
  if (args.length == 1 && (args.first == '--version' || args.first == '-v')) {
    return const ['version'];
  }
  return args;
}

/// Configures the CLI, registers all commands, and dispatches [args].
///
/// Returns a process exit code.
Future<int> runMacss(
  List<String> args, {
  io.IOSink? stdout,
  io.IOSink? stderr,
  GraphqlCompileRunner? graphqlCompileRunner,
}) async {
  final cli = ModularCli();
  final normalizedArgs = normalizeMacssArgs(args);
  final output = stdout ?? io.stdout;
  final error = stderr ?? io.stderr;

  final assetsRoot = p.dirname(p.dirname(io.Platform.resolvedExecutable));
  final assets = Assets(root: assetsRoot);

  cli.module('', (m) => buildGlobalModule(m, assets: assets));
  cli.module(
    'api',
    (m) => buildApiModule(m, runner: graphqlCompileRunner),
  );
  cli.module(
    'specification',
    (m) => buildSpecificationModule(m, assets: assets),
  );
  cli.module('issue', (m) => buildIssueModule(m, assets: assets));

  final routeStdout = _isApiGraphqlCompileRoute(normalizedArgs) &&
          !_isJsonMode(normalizedArgs)
      ? error
      : output;

  return cli.run(normalizedArgs, stdout: routeStdout, stderr: error);
}

bool _isApiGraphqlCompileRoute(List<String> args) {
  return args.length >= 3 &&
      args[0] == 'api' &&
      args[1] == 'graphql' &&
      args[2] == 'compile';
}

bool _isJsonMode(List<String> args) {
  return args.contains('--json');
}
