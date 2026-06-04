import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'graphql/commands/compile.dart';
import '../../src/api/graphql/compile_runner.dart';

void buildApiModule(ModuleBuilder m, {GraphqlCompileRunner? runner}) {
  m.command<GraphqlCompileInput, GraphqlCompileOutput>(
    'graphql compile',
    (req) => GraphqlCompileCommand(
      GraphqlCompileInput.fromCliRequest(req),
      runner: runner,
    ),
    description: 'Compile GraphQL artifacts for modular_api',
  );
}