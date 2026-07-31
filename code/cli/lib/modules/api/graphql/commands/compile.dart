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

class GraphqlCompileOutput extends Output {
  final String message;
  final int _exitCode;
  final GraphqlCompileResolvedConfig? resolvedConfig;

  GraphqlCompileOutput({
    required this.message,
    int exitCode = ExitCode.ok,
    this.resolvedConfig,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() => {
    'message': message,
    if (resolvedConfig != null) 'config': resolvedConfig!.toJson(),
  };

  @override
  int get exitCode => _exitCode;

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

  @override
  Future<GraphqlCompileOutput> execute() async {
    final resolved = configResolver.resolve(input);

    try {
      validateGraphqlCompileConfig(resolved);
    } on GraphqlCompileUsageError catch (error) {
      return GraphqlCompileOutput(
        message: error.message,
        exitCode: 2,
        resolvedConfig: resolved,
      );
    } on GraphqlCompileConfigError catch (error) {
      return GraphqlCompileOutput(
        message: error.message,
        exitCode: 3,
        resolvedConfig: resolved,
      );
    }

    try {
      final result = await runner.run(resolved);
      return GraphqlCompileOutput(
        message: result.message,
        resolvedConfig: result.resolvedConfig ?? resolved,
      );
    } on GraphqlCompileExecutionError catch (error) {
      return GraphqlCompileOutput(
        message: error.message,
        exitCode: error.hasBlockingDiagnostics ? 4 : 5,
        resolvedConfig: resolved,
      );
    } catch (error) {
      return GraphqlCompileOutput(
        message: 'Unexpected GraphQL compile failure: $error',
        exitCode: 5,
        resolvedConfig: resolved,
      );
    }
  }
}