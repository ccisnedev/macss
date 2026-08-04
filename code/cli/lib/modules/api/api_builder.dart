import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'graphql/commands/compile.dart';
import '../../src/api/graphql/compile_runner.dart';

/// [workingDirectory] defaults to the process's own.
///
/// It exists so a test exercising the CWD-relative defaults (`code/db`,
/// `.modular_api/graphql`) can name a directory instead of assigning to
/// `Directory.current`. That assignment is process-wide, and `dart test` runs
/// suites concurrently in one process — it was making `books_layout_test`, which
/// resolves `../books` as it loads, fail at random.
void buildApiModule(
  ModuleBuilder m, {
  GraphqlCompileRunner? runner,
  String? workingDirectory,
}) {
  m.command<GraphqlCompileInput, GraphqlCompileOutput>(
    'graphql compile',
    (req) => GraphqlCompileCommand(
      GraphqlCompileInput.fromCliRequest(req,
          workingDirectory: workingDirectory),
      runner: runner,
    ),
    description: 'Compile GraphQL artifacts for modular_api',
    params: GraphqlCompileInput.params,
  );
}