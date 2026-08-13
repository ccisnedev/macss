/// Running `api graphql compile` and reading its answer, however it arrives.
library;

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';

/// The exit code and message a run produces, whether it succeeded or refused.
///
/// The compile's own failures used to be unhappy Outputs and are thrown now, so
/// they arrive by a different route. To a caller they mean the same thing — a
/// code and something to read — which is what this collapses back together.
Future<({int exitCode, String text})> runOf(
  GraphqlCompileCommand command,
) async {
  try {
    final output = await applyCommand(command);
    return (exitCode: output.exitCode, text: output.toText() ?? '');
  } on CommandException catch (error) {
    return (exitCode: error.exitCode, text: error.message);
  }
}
