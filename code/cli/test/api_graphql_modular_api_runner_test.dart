import 'dart:io';

import 'package:modular_api/modular_api.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/src/api/graphql/compile_config.dart';
import 'package:macss_cli/src/api/graphql/compile_runner.dart';

void main() {
  group('ModularApiGraphqlCompileRunner', () {
    late Directory tempDir;
    late String metadataPath;
    late String outputDirectory;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_modular_api_runner_');
      metadataPath = p.join(tempDir.path, 'code', 'db', 'graphql.metadata.jsonc');
      outputDirectory = p.join(tempDir.path, '.modular_api', 'graphql');
      Directory(p.dirname(metadataPath)).createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('writes canonical artifacts for a valid metadata file', () async {
      File(metadataPath).writeAsStringSync('''
{
  version: 1,
  objects: {
    "sales.Customer": {
      publish: true,
    },
  },
}
''');

      final runner = ModularApiGraphqlCompileRunner(
        providerVersion: '0.4.7-test',
        physicalCatalogLoader: (_) async => _physicalCatalog(),
      );

      final result = await runner.run(
        GraphqlCompileResolvedConfig(
          sourceRoot: p.join(tempDir.path, 'code', 'db'),
          metadataFile: metadataPath,
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

    test('blocking diagnostics still write artifacts before failing', () async {
      File(metadataPath).writeAsStringSync('{ version: "bad" }');

      final runner = ModularApiGraphqlCompileRunner(
        providerVersion: '0.4.7-test',
        physicalCatalogLoader: (_) async => _physicalCatalog(),
      );

      await expectLater(
        () => runner.run(
          GraphqlCompileResolvedConfig(
            sourceRoot: p.join(tempDir.path, 'code', 'db'),
            metadataFile: metadataPath,
            outputDirectory: outputDirectory,
            engine: 'sqlserver',
            workingDirectory: tempDir.path,
          ),
        ),
        throwsA(
          isA<GraphqlCompileExecutionError>().having(
            (error) => error.hasBlockingDiagnostics,
            'hasBlockingDiagnostics',
            isTrue,
          ),
        ),
      );

      expect(File(p.join(outputDirectory, 'catalog.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'catalog.lock')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'diagnostics.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'schema.graphql')).existsSync(), isTrue);
    });
  });
}

PhysicalCatalog _physicalCatalog() {
  return const PhysicalCatalog(
    objects: <PhysicalObject>[
      PhysicalObject(
        id: 'sales.Customer',
        kind: PhysicalObjectKind.table,
        schemaName: 'sales',
        objectName: 'Customer',
        identityFields: <String>['CustomerId'],
        fields: <PhysicalField>[
          PhysicalField(column: 'CustomerId', nativeType: 'int', nullable: false),
          PhysicalField(column: 'Name', nativeType: 'nvarchar', nullable: false),
        ],
        relations: <PhysicalRelationSeed>[],
      ),
    ],
  );
}