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

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_compile_runner_');
      sourceRoot = Directory(p.join(tempDir.path, 'code', 'db'))
        ..createSync(recursive: true);
      metadataFile = File(p.join(sourceRoot.path, 'graphql.metadata.jsonc'))
        ..writeAsStringSync('{ version: 1, objects: {} }');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('valid configuration is passed to runner after resolution', () async {
      final runner = _RecordingRunner(
        result: const GraphqlCompileRunResult(
          message: 'compiled successfully',
        ),
      );

      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'out'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: runner,
      ));

      expect(output.exitCode, 0);
      expect(output.text, contains('compiled successfully'));
      expect(runner.seenConfig, isNotNull);
      expect(runner.seenConfig!.sourceRoot, sourceRoot.path);
      expect(runner.seenConfig!.metadataFile, metadataFile.path);
    });

    test('blocking diagnostics map to exit code 4', () async {
      final runner = _RecordingRunner(
        error: GraphqlCompileExecutionError.blockingDiagnostics(
          'blocking diagnostics were emitted',
        ),
      );

      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'out'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: runner,
      ));

      expect(output.exitCode, 4);
      expect(output.text, contains('blocking diagnostics'));
    });

    test('unexpected runtime failures map to exit code 5', () async {
      final runner = _RecordingRunner(error: StateError('boom'));

      final output = await runOf(GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'out'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: runner,
      ));

      expect(output.exitCode, 5);
      expect(output.text, contains('boom'));
    });

  });
}

class _RecordingRunner implements GraphqlCompileRunner {
  final GraphqlCompileRunResult? result;
  final Object? error;
  GraphqlCompileResolvedConfig? seenConfig;

  _RecordingRunner({this.result, this.error});

  @override
  Future<GraphqlCompileRunResult> run(GraphqlCompileResolvedConfig config) async {
    seenConfig = config;
    if (error != null) {
      throw error!;
    }
    return result!;
  }
}