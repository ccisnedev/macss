/// `macss api graphql compile` — stage-0 placeholder for GraphQL artifact compilation.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../../src/api/graphql/compile_config.dart';
import '../../../../src/api/graphql/compile_config_resolver.dart';
import '../../../../src/api/graphql/compile_runner.dart';
import '../../../../src/api/graphql/compile_validation.dart';

class GraphqlCompileInput extends Input {
  final String? sourceRoot;
  final String? metadataFile;
  final String? outputDirectory;
  final String? engine;
  final String workingDirectory;
  GraphqlCompileInput({
    required this.sourceRoot,
    required this.metadataFile,
    required this.outputDirectory,
    required this.engine,
    required this.workingDirectory,
  });

  factory GraphqlCompileInput.fromCliRequest(
    CliRequest req, {
    String? workingDirectory,
  }) {
    return GraphqlCompileInput(
      sourceRoot: req.flagString('source-root'),
      metadataFile: req.flagString('metadata'),
      outputDirectory: req.flagString('output'),
      engine: req.flagString('engine'),
      workingDirectory: workingDirectory ?? Directory.current.path,
    );
  }

  /// Declared contract: the four compile options. Declaring them rejects any
  /// other flag at parse time and publishes them in help.
  static final List<CliParam> params = [
    CliParam.string(
      'source-root',
      description: 'GraphQL source root. Default: code/db',
    ),
    CliParam.string(
      'metadata',
      description: 'Metadata file. Default: <source-root>/graphql.metadata.jsonc',
    ),
    CliParam.string(
      'output',
      description: 'Artifact directory. Default: .modular_api/graphql',
    ),
    CliParam.string(
      'engine',
      description: 'GraphQL engine. Supported: sqlserver',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
    'sourceRoot': sourceRoot,
    'metadataFile': metadataFile,
    'outputDirectory': outputDirectory,
    'engine': engine,
    'workingDirectory': workingDirectory,
  };
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Runs the compiler over the resolved configuration.
///
/// The configuration is resolved and validated when the step is built, so the
/// plan describes the compile that actually runs — and a configuration that
/// cannot compile never reaches a plan at all.
class CompileGraphqlArtifacts implements Step {
  CompileGraphqlArtifacts({required this.runner, required this.config});

  final GraphqlCompileRunner runner;
  final GraphqlCompileResolvedConfig config;

  @override
  Preview preview() => Preview(
    verb: 'compile',
    target: config.outputDirectory,
    detail: [
      'source ${config.sourceRoot}',
      'metadata ${config.metadataFile}',
      'engine ${config.engine}',
      'the output directory is written by the compiler, so anything already '
          'there is replaced by what this run produces',
    ].join('; '),
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final result = await runner.run(config);
    return Outcome(
      verb: 'compile',
      target: config.outputDirectory,
      detail: result.message,
      values: {'message': result.message},
    );
  }
}

class GraphqlCompileOutput extends Output {
  GraphqlCompileOutput({required this.message, this.resolvedConfig});

  final String message;
  final GraphqlCompileResolvedConfig? resolvedConfig;

  @override
  Map<String, dynamic> toJson() => {
    'message': message,
    if (resolvedConfig != null) 'config': resolvedConfig!.toJson(),
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => message;
}

class GraphqlCompileCommand
    implements Command<GraphqlCompileInput, GraphqlCompileOutput> {
  @override
  final GraphqlCompileInput input;

  final GraphqlCompileConfigResolver configResolver;
  final GraphqlCompileRunner runner;

  GraphqlCompileCommand(
    this.input, {
    GraphqlCompileConfigResolver? configResolver,
    GraphqlCompileRunner? runner,
  }) : configResolver = configResolver ??
            GraphqlCompileConfigResolver(environment: Platform.environment),
       runner = runner ??
            ModularApiGraphqlCompileRunner(environment: Platform.environment);

  @override
  String? validate() => null;

  GraphqlCompileResolvedConfig? _resolved;

  /// One step, over a configuration resolved and validated first.
  ///
  /// A plan built from a configuration that cannot compile would describe work
  /// that will never happen, so the validation throws before any step exists —
  /// and it keeps the exit codes it always had: 2 for a usage error, 3 for a
  /// configuration error.
  @override
  Future<List<Step>> steps() async {
    final resolved = configResolver.resolve(input);
    _resolved = resolved;

    try {
      validateGraphqlCompileConfig(resolved);
    } on GraphqlCompileUsageError catch (error) {
      throw CommandException(
        code: 'GRAPHQL_COMPILE_USAGE',
        message: error.message,
        exitCode: 2,
      );
    } on GraphqlCompileConfigError catch (error) {
      throw CommandException(
        code: 'GRAPHQL_COMPILE_CONFIG',
        message: error.message,
        exitCode: 3,
      );
    }

    return [CompileGraphqlArtifacts(runner: runner, config: resolved)];
  }

  @override
  GraphqlCompileOutput describe(Execution execution) {
    final failure = execution.failure?.error;
    if (failure is GraphqlCompileExecutionError) {
      throw CommandException(
        code: 'GRAPHQL_COMPILE_FAILED',
        message: failure.message,
        exitCode: failure.hasBlockingDiagnostics ? 4 : 5,
      );
    }
    if (failure != null) {
      throw CommandException(
        code: 'GRAPHQL_COMPILE_FAILED',
        message: 'Unexpected GraphQL compile failure: $failure',
        exitCode: 5,
      );
    }

    return GraphqlCompileOutput(
      message: execution.outcomes.single.values['message'] as String,
      resolvedConfig: _resolved,
    );
  }
}
