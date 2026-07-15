import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';
import 'package:macss_cli/src/api/graphql/compile_config.dart';
import 'package:macss_cli/src/api/graphql/compile_config_resolver.dart';
import 'package:macss_cli/src/api/graphql/compile_runner.dart';

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
      final output = await GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'postgres',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
      ).execute();

      expect(output.exitCode, equals(2));
      expect(output.toText(), contains('sqlserver'));
    });

    test('missing source root returns config failure exit code 3', () async {
      final output = await GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: p.join(tempDir.path, 'missing', 'db'),
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
      ).execute();

      expect(output.exitCode, equals(3));
      expect(output.toText(), contains('sourceRoot'));
    });

    test('missing metadata returns config failure exit code 3', () async {
      final output = await GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: p.join(sourceRoot.path, 'missing.metadata.jsonc'),
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
      ).execute();

      expect(output.exitCode, equals(3));
      expect(output.toText(), contains('metadata'));
    });

    test('valid configuration returns success', () async {
      final output = await GraphqlCompileCommand(
        GraphqlCompileInput(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: p.join(tempDir.path, 'artifacts', 'graphql'),
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
        configResolver: GraphqlCompileConfigResolver(environment: const {}),
        runner: _SuccessRunner(),
      ).execute();

      expect(output.exitCode, equals(0));
      expect(output.toText(), contains('compiled successfully'));
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