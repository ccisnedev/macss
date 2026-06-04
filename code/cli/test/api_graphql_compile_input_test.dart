import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:test/test.dart';

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';

void main() {
  group('GraphqlCompileInput', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_compile_input_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('parses supported flags and captures current working directory', () {
      final req = CliRequest(
        originalArgs: const [
          'api',
          'graphql',
          'compile',
          '--source-root=services/orders/db',
          '--metadata=services/orders/db/graphql.metadata.jsonc',
          '--output=artifacts/graphql',
          '--engine=sqlserver',
        ],
        matchedCommand: const ['api', 'graphql', 'compile'],
        params: const {},
        flags: const {
          'source-root': 'services/orders/db',
          'metadata': 'services/orders/db/graphql.metadata.jsonc',
          'output': 'artifacts/graphql',
          'engine': 'sqlserver',
        },
        positionals: const [],
      );

      final input = GraphqlCompileInput.fromCliRequest(
        req,
        workingDirectory: tempDir.path,
      );

      expect(input.sourceRoot, equals('services/orders/db'));
      expect(
        input.metadataFile,
        equals('services/orders/db/graphql.metadata.jsonc'),
      );
      expect(input.outputDirectory, equals('artifacts/graphql'));
      expect(input.engine, equals('sqlserver'));
      expect(input.workingDirectory, equals(tempDir.path));
    });

    test('captures contextual help requests from flags', () {
      final req = CliRequest(
        originalArgs: const ['api', 'graphql', 'compile', '--help'],
        matchedCommand: const ['api', 'graphql', 'compile'],
        params: const {},
        flags: const {'help': ''},
        positionals: const [],
      );

      final input = GraphqlCompileInput.fromCliRequest(
        req,
        workingDirectory: tempDir.path,
      );

      expect(input.helpRequested, isTrue);
    });
  });
}