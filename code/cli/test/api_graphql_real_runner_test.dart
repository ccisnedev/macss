import 'dart:io';

import 'package:modular_api/modular_api.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/src/api/graphql/compile_config.dart';
import 'package:macss_cli/src/api/graphql/compile_runner.dart';

void main() {
  group('ModularApiGraphqlCompileRunner', () {
    late Directory tempDir;
    late Directory sourceRoot;
    late File metadataFile;
    late String outputDirectory;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_real_runner_');
      sourceRoot = Directory(p.join(tempDir.path, 'code', 'db'))
        ..createSync(recursive: true);
      metadataFile = File(p.join(sourceRoot.path, 'graphql.metadata.jsonc'))
        ..writeAsStringSync('''
{
  version: 1,
  objects: {
    "sales.Customer": {
      publish: true,
    },
  },
}
''');
      outputDirectory = p.join(tempDir.path, '.modular_api', 'graphql');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('builds artifacts from metadata and physical catalog without src imports', () async {
      final runner = ModularApiGraphqlCompileRunner(
        providerVersion: '0.4.7-test',
        physicalCatalogLoader: (config) async => const PhysicalCatalog(
          objects: <PhysicalObject>[
            PhysicalObject(
              id: 'sales.Customer',
              kind: PhysicalObjectKind.table,
              schemaName: 'sales',
              objectName: 'Customer',
              identityFields: <String>['CustomerId'],
              fields: <PhysicalField>[
                PhysicalField(
                  column: 'CustomerId',
                  nativeType: 'int',
                  nullable: false,
                ),
              ],
              relations: <PhysicalRelationSeed>[],
            ),
          ],
        ),
      );

      final result = await runner.run(
        GraphqlCompileResolvedConfig(
          sourceRoot: sourceRoot.path,
          metadataFile: metadataFile.path,
          outputDirectory: outputDirectory,
          engine: 'sqlserver',
          workingDirectory: tempDir.path,
        ),
      );

      expect(result.message, contains(outputDirectory));
      expect(File(p.join(outputDirectory, 'catalog.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'catalog.lock')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'diagnostics.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'schema.graphql')).existsSync(), isTrue);
    });
  });
}