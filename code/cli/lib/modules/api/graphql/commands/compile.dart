/// `macss api graphql compile` — stage-0 placeholder for GraphQL artifact compilation.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../../src/api/graphql/compile_config.dart';
import '../../../../src/api/graphql/compile_config_resolver.dart';
import '../../../../src/api/graphql/compile_runner.dart';
import '../../../../src/api/graphql/compile_validation.dart';
import '../../../../src/plan_apply.dart';

class GraphqlCompileInput extends Input {
  final String? sourceRoot;
  final String? metadataFile;
  final String? outputDirectory;
  final String? engine;
  final String workingDirectory;
  final ChangeFlags flags;

  GraphqlCompileInput({
    required this.sourceRoot,
    required this.metadataFile,
    required this.outputDirectory,
    required this.engine,
    required this.workingDirectory,
    this.flags = const ChangeFlags(),
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
      flags: ChangeFlags.fromCliRequest(req),
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
    ...ChangeFlags.params,
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
    'plan': flags.plan,
    'apply': flags.apply,
    'autoapprove': flags.autoapprove,
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
  final Approver? approver;
  final DateTime Function()? now;

  GraphqlCompileCommand(
    this.input, {
    GraphqlCompileConfigResolver? configResolver,
    GraphqlCompileRunner? runner,
    this.approver,
    this.now,
  }) : configResolver = configResolver ??
            GraphqlCompileConfigResolver(environment: Platform.environment),
       runner = runner ??
            ModularApiGraphqlCompileRunner(environment: Platform.environment);

  @override
  String? validate() => input.flags.validate();

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

    // The config is validated first: a plan built from a configuration that
    // cannot compile would describe work that will never happen.
    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'api graphql compile',
      workingDirectory: input.workingDirectory,
      body: [
        'would compile GraphQL artifacts:',
        '',
        '  source   ${resolved.sourceRoot}',
        '  metadata ${resolved.metadataFile}',
        '  engine   ${resolved.engine}',
        '  output   ${resolved.outputDirectory}',
        '',
        'The output directory is written by the compiler, so anything already '
            'there is replaced by what this run produces.',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return GraphqlCompileOutput(
        message: decision.message!,
        exitCode: decision.blocked ? ExitCode.genericError : ExitCode.ok,
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