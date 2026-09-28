import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'package:macss_cli/modules/api/graphql/commands/compile.dart';

import 'support/memory_sink.dart';

// `GraphqlCompileInput.fromCliRequest` reads flags off a real `CliRequest`,
// and that class is built by the router from a declared contract, not a
// literal a test can assemble by hand. So this drives the actual request
// through a `ModularCli` the same way the framework does, using a probe query
// only to capture the `Input` the factory produced, mirroring the SDK's own
// test suite (see `error_path_test.dart`) rather than reimplementing the
// router's internals here.
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

    test(
      'parses supported flags and captures current working directory',
      () async {
        GraphqlCompileInput? captured;

        final cli = ModularCli(suggestionDistance: 2)
          ..query<GraphqlCompileInput, _ProbeOutput>(
            'compile',
            (req) {
              final input = GraphqlCompileInput.fromCliRequest(
                req,
                workingDirectory: tempDir.path,
              );
              captured = input;
              return _ProbeQuery(input);
            },
            globals: true,
            contract: GraphqlCompileInput.contract,
          );

        final code = await cli.run(
          [
            'compile',
            '--source-root=services/orders/db',
            '--metadata=services/orders/db/graphql.metadata.jsonc',
            '--output=artifacts/graphql',
            '--engine=sqlserver',
          ],
          stdout: MemorySink().sink,
          stderr: MemorySink().sink,
        );

        expect(code, ExitCode.ok);
        final input = captured;
        expect(input, isNotNull);
        expect(input!.sourceRoot, equals('services/orders/db'));
        expect(
          input.metadataFile,
          equals('services/orders/db/graphql.metadata.jsonc'),
        );
        expect(input.outputDirectory, equals('artifacts/graphql'));
        expect(input.engine, equals('sqlserver'));
        expect(input.workingDirectory, equals(tempDir.path));
      },
    );
  });
}

class _ProbeOutput extends Output {
  @override
  Map<String, dynamic> toJson() => {};

  @override
  int get exitCode => ExitCode.ok;
}

class _ProbeQuery implements Query<GraphqlCompileInput, _ProbeOutput> {
  @override
  final GraphqlCompileInput input;

  _ProbeQuery(this.input);

  @override
  String? validate() => null;

  @override
  Future<_ProbeOutput> execute() async => _ProbeOutput();
}
