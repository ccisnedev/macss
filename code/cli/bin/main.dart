/// Entry point for the `macss` CLI.
///
/// Delegates to [runMacss] to keep the binary thin and testable, after
/// refusing to run under the Dart VM (see `run_from_source.dart`). The check
/// lives here and not in [runMacss] because tests call [runMacss] in-process,
/// where the executable is the Dart VM by design.
library;

import 'dart:io';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/src/run_from_source.dart';

Future<void> main(List<String> args) async {
  if (isRunningFromSource(Platform.resolvedExecutable)) {
    stderr.write(runFromSourceRefusal);
    exit(runFromSourceExitCode);
  }
  final code = await runMacss(args);
  exit(code);
}
