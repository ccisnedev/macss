import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';

import 'support/graphql_run.dart';
import 'package:macss_cli/src/api/graphql/compile_config.dart';
import 'package:macss_cli/src/api/graphql/compile_config_resolver.dart';
import 'package:macss_cli/src/api/graphql/compile_runner.dart';

void main() {
  group('GraphqlCompileCommand runner contract', () {
    late Directory tempDir;
    late Directory sourceRoot;
    late File metadataFile;
    late _FakeRunner fakeRunner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_compile_runner_');
      sourceRoot = Directory(p.join(tempDir.path, 'code', 'db'))
        ..createSync(recursive: true);
      metadataFile = File(p.join(sourceRoot.path, 'graphql.metadata.jsonc'))
        ..writeAsStringSync('{}');
      fakeRunner = _FakeRunner();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('valid config invokes the runner with resolved config', () async {
      fakeRunner.result = GraphqlCompileRunResult(
        message: 'runner ok',
        resolvedConfig: GraphqlCompileResolvedConfig(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
      );

      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: fakeRunner,
      ));

      expect(output.exitCode, 0);
      expect(output.text, contains('runner ok'));
      expect(fakeRunner.calls, 1);
      expect(fakeRunner.lastConfig?.sourceRoot, sourceRoot.path);
    });

    test('validation errors do not invoke the runner', () async {
      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'postgres',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: fakeRunner,
      ));

      expect(output.exitCode, 2);
      expect(fakeRunner.calls, 0);
    });

    test('blocking diagnostics from runner map to exit code 4', () async {
      fakeRunner.error = GraphqlCompileExecutionError.blockingDiagnostics(
        'compile emitted blocking diagnostics',
      );

      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: fakeRunner,
      ));

      expect(output.exitCode, 4);
      expect(output.text, contains('blocking diagnostics'));
    });

    test('unexpected runner failures map to exit code 5', () async {
      fakeRunner.error = StateError('boom');

      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: fakeRunner,
      ));

      expect(output.exitCode, 5);
      expect(output.text, contains('Unexpected GraphQL compile failure'));
    });
  });
}

class _FakeRunner implements GraphqlCompileRunner {
  int calls = 0;
  GraphqlCompileResolvedConfig? lastConfig;
  GraphqlCompileRunResult? result;
  Object? error;

  @override
  Future<GraphqlCompileRunResult> run(GraphqlCompileResolvedConfig config) async {
    calls += 1;
    lastConfig = config;
    if (error != null) {
      throw error!;
    }
    return result ?? GraphqlCompileRunResult(message: 'ok', resolvedConfig: config);
  }
}