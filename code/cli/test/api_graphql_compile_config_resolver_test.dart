import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';
import 'package:macss_cli/src/api/graphql/compile_config_resolver.dart';

void main() {
  group('GraphqlCompileConfigResolver', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_compile_config_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('applies default source root, metadata, output and engine', () {
      final input = GraphqlCompileInput(
        sourceRoot: null,
        metadataFile: null,
        outputDirectory: null,
        engine: null,
        workingDirectory: tempDir.path,
      );

      final resolved = GraphqlCompileConfigResolver(
        environment: const {},
      ).resolve(input);

      expect(resolved.sourceRoot, equals(p.join(tempDir.path, 'code', 'db')));
      expect(
        resolved.metadataFile,
        equals(p.join(tempDir.path, 'code', 'db', 'graphql.metadata.jsonc')),
      );
      expect(
        resolved.outputDirectory,
        equals(p.join(tempDir.path, '.modular_api', 'graphql')),
      );
      expect(resolved.engine, equals('sqlserver'));
    });

    test('uses environment variables when flags are not present', () {
      final input = GraphqlCompileInput(
        sourceRoot: null,
        metadataFile: null,
        outputDirectory: null,
        engine: null,
        workingDirectory: tempDir.path,
      );

      final resolved = GraphqlCompileConfigResolver(
        environment: const {
          'MACSS_API_GRAPHQL_SOURCE_ROOT': 'services/orders/db',
          'MACSS_API_GRAPHQL_METADATA': 'config/graphql.metadata.jsonc',
          'MACSS_API_GRAPHQL_OUTPUT': 'artifacts/graphql',
          'MACSS_API_GRAPHQL_ENGINE': 'sqlserver',
        },
      ).resolve(input);

      expect(
        resolved.sourceRoot,
        equals(p.join(tempDir.path, 'services', 'orders', 'db')),
      );
      expect(
        resolved.metadataFile,
        equals(p.join(tempDir.path, 'config', 'graphql.metadata.jsonc')),
      );
      expect(
        resolved.outputDirectory,
        equals(p.join(tempDir.path, 'artifacts', 'graphql')),
      );
      expect(resolved.engine, equals('sqlserver'));
    });

    test('explicit flags override environment values', () {
      final input = GraphqlCompileInput(
        sourceRoot: 'code/custom-db',
        metadataFile: 'code/custom-db/custom.metadata.jsonc',
        outputDirectory: 'build/graphql',
        engine: 'sqlserver',
        workingDirectory: tempDir.path,
      );

      final resolved = GraphqlCompileConfigResolver(
        environment: const {
          'MACSS_API_GRAPHQL_SOURCE_ROOT': 'services/orders/db',
          'MACSS_API_GRAPHQL_METADATA': 'config/graphql.metadata.jsonc',
          'MACSS_API_GRAPHQL_OUTPUT': 'artifacts/graphql',
          'MACSS_API_GRAPHQL_ENGINE': 'postgres',
        },
      ).resolve(input);

      expect(
        resolved.sourceRoot,
        equals(p.join(tempDir.path, 'code', 'custom-db')),
      );
      expect(
        resolved.metadataFile,
        equals(
          p.join(tempDir.path, 'code', 'custom-db', 'custom.metadata.jsonc'),
        ),
      );
      expect(
        resolved.outputDirectory,
        equals(p.join(tempDir.path, 'build', 'graphql')),
      );
      expect(resolved.engine, equals('sqlserver'));
    });
  });
}