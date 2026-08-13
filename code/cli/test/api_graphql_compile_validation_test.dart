import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:test/test.dart';

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';
import 'package:macss_cli/src/api/graphql/compile_config.dart';
import 'package:macss_cli/src/api/graphql/compile_config_resolver.dart';
import 'package:macss_cli/src/api/graphql/compile_runner.dart';

/// The refusal a command makes before it builds a single step.
///
/// The configuration is validated in `steps()`, so a broken one throws rather
/// than returning an unhappy Output — which is what keeps its exit code.
Future<CommandException> refusal(GraphqlCompileCommand command) async {
  try {
    await applyCommand(command);
  } on CommandException catch (error) {
    return error;
  }
  fail('expected the command to refuse');
}

void main() {
  group('GraphqlCompileCommand validation', () {
    late Directory tempDir;
    late Directory sourceRoot;
    late File metadataFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_compile_validate_');
      sourceRoot = Directory(p.join(tempDir.path, 'code', 'db'))
        ..createSync(recursive: true);
      metadataFile = File(p.join(sourceRoot.path, 'graphql.metadata.jsonc'))
        ..writeAsStringSync('{}');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('unsupported engine returns invalid usage exit code 2', () async {
      final error = await refusal(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'postgres',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
      ));

      expect(error.exitCode, 2);
      expect(error.message, contains('sqlserver'));
    });

    test('missing source root returns config failure exit code 3', () async {
      final error = await refusal(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: p.join(tempDir.path, 'missing', 'db'),
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
      ));

      expect(error.exitCode, 3);
      expect(error.message, contains('sourceRoot'));
    });

    test('missing metadata returns config failure exit code 3', () async {
      final error = await refusal(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: p.join(sourceRoot.path, 'missing.metadata.jsonc'),
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
      ));

      expect(error.exitCode, 3);
      expect(error.message, contains('metadata'));
    });

    test('valid configuration returns success', () async {
      final output = await applyCommand(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: _SuccessRunner(),
      ));

      expect(output.exitCode, 0);
      expect(output.toText(), contains('compiled successfully'));
    });

    // A configuration that cannot compile never reaches a plan: the validation
    // throws before any step exists, so `--plan` on a broken config refuses
    // rather than describing work that will never happen.
    test('an invalid configuration builds no steps', () async {
      await expectLater(
        previewCommand(GraphqlCompileCommand(
          GraphqlCompileInput(
            sourceRoot: sourceRoot.path,
            metadataFile: metadataFile.path,
            outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
            engine: 'postgres',
            workingDirectory: tempDir.path,
          ),
          configResolver: GraphqlCompileConfigResolver(environment: const {}),
        )),
        throwsA(isA<CommandException>()
            .having((e) => e.exitCode, 'exitCode', 2)),
      );
    });
  });
}

class _SuccessRunner implements GraphqlCompileRunner {
  @override
  Future<GraphqlCompileRunResult> run(GraphqlCompileResolvedConfig config) async {
    return GraphqlCompileRunResult(
      message: 'compiled successfully for ${config.sourceRoot}',
      resolvedConfig: config,
    );
  }
}