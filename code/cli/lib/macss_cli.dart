/// Public API for the `macss` CLI.
///
/// [runMacss] is the single entry point — called by `bin/main.dart` and by tests.
library;

import 'dart:io' as io;

import 'package:datajack/datajack.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';
import 'package:path/path.dart' as p;

import 'assets.dart';
import 'src/api/graphql/compile_runner.dart';
import 'modules/api/api_builder.dart';
import 'modules/delivery/delivery_builder.dart';
import 'modules/dod/dod_builder.dart';
import 'modules/dor/dor_builder.dart';
import 'modules/global/global_builder.dart';
import 'modules/project/project_builder.dart';
import 'modules/requisition/requisition_builder.dart';
import 'modules/specification/specification_builder.dart';
import 'modules/verification/verification_builder.dart';

/// The name this CLI writes into every ledger row it creates, and the name the
/// other consumers see in a `block` when they meet one of its artifacts.
///
/// Not the executable's name by coincidence: it is the identity that makes PRD
/// 10.2 state 5 answerable on a machine `macss`, `inquiry` and `skillwire_cli`
/// all deploy into.
const macssConsumerName = 'macss';

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
  String? workingDirectory,
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
    (m) => buildApiModule(
      m,
      runner: graphqlCompileRunner,
      workingDirectory: workingDirectory,
    ),
  );
  cli.module(
    'specification',
    (m) => buildSpecificationModule(m, assets: assets),
  );
  cli.module('dor', (m) => buildDorModule(m, assets: assets));
  cli.module('dod', (m) => buildDodModule(m, assets: assets));
  cli.module('delivery', (m) => buildDeliveryModule(m, assets: assets));
  cli.module(
    'verification',
    (m) => buildVerificationModule(m, assets: assets),
  );
  // R12.1 — the same `skill` module every consumer mounts, from `datajack`.
  // `consumer` is what makes a shared machine work: every ledger row this CLI
  // writes says `macss`, so `inquiry` and `skillwire_cli` meeting one of these
  // artifacts report it as owned rather than overwriting it.
  // Its own resolution, not macss's `Assets` root: `Workspace` knows the two
  // layouts a modular_cli_sdk CLI has — beside the compiled binary, and the
  // working copy when run from source with `dart run`.
  final workspace = Workspace.detect();
  cli.module(
    'skill',
    (m) => buildSkillModule(
      m,
      consumer: macssConsumerName,
      workspace: workspace,
      catalogue: Catalogue.read(
        workspace.assetsRoot,
        validator: SkillValidator(reservedNames: workspace.matrix.reservedNames),
      ),
    ),
  );
  cli.module('project', (m) => buildProjectModule(m, assets: assets));
  cli.module(
    'requisition',
    (m) => buildRequisitionModule(m, assets: assets),
  );

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
