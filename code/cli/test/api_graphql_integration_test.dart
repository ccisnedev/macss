import 'dart:io';

import 'package:modular_api/modular_api.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/src/api/graphql/compile_runner.dart';

import 'support/memory_sink.dart';

void main() {
  group('api graphql integration', () {
    late Directory tempDir;
    late String originalWorkingDirectory;
    late Directory sourceRoot;
    late File metadataFile;
    late String outputDirectory;

    setUp(() {
      originalWorkingDirectory = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync('macss_api_graphql_it_');
      Directory.current = tempDir.path;
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
      Directory.current = originalWorkingDirectory;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compile writes artifacts end to end in text mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--apply', '--autoapprove'],
        stdout: stdout.sink,
        stderr: stderr.sink,
        graphqlCompileRunner: _runner(),
      );

      expect(exitCode, 0);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains(outputDirectory));
      expect(File(p.join(outputDirectory, 'catalog.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'catalog.lock')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'diagnostics.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'schema.graphql')).existsSync(), isTrue);
    });

    test('compile writes json to stdout in json mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--json', '--apply', '--autoapprove'],
        stdout: stdout.sink,
        stderr: stderr.sink,
        graphqlCompileRunner: _runner(),
      );

      expect(exitCode, 0);
      expect(await stdout.text(), contains('"message"'));
      expect(await stderr.text(), isEmpty);
      expect(File(p.join(outputDirectory, 'catalog.json')).existsSync(), isTrue);
    });

    test('blocking diagnostics return exit code 4 and still write artifacts', () async {
      metadataFile.writeAsStringSync('{ version: "bad" }');
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--apply', '--autoapprove'],
        stdout: stdout.sink,
        stderr: stderr.sink,
        graphqlCompileRunner: _runner(),
      );

      expect(exitCode, 4);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains('blocking diagnostics'));
      expect(File(p.join(outputDirectory, 'catalog.json')).existsSync(), isTrue);
      expect(File(p.join(outputDirectory, 'diagnostics.json')).existsSync(), isTrue);
    });
  });
}

GraphqlCompileRunner _runner() {
  return ModularApiGraphqlCompileRunner(
    providerVersion: '0.4.7-test',
    physicalCatalogLoader: (_) async => const PhysicalCatalog(
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
}