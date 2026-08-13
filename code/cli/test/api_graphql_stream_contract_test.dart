import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

void main() {
  group('api graphql stream contract', () {
    test('text mode writes command text to stdout', () async {
      final cli = ModularCli()
        ..query<_StreamInput, _StreamOutput>(
          'probe',
          (req) => _StreamProbeQuery(_StreamInput.fromCliRequest(req)),
        );

      final stdout = MemorySink();
      final stderr = MemorySink();
      final code = await cli.run(
        ['probe'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.ok);
      expect(await stdout.text(), equals('human text\n'));
      expect(await stderr.text(), isEmpty);
    });

    test('command exceptions are written to stderr', () async {
      final cli = ModularCli()
        ..query<_StreamInput, _StreamOutput>(
          'probe',
          (req) => _ExceptionProbeQuery(_StreamInput.fromCliRequest(req)),
        );

      final stdout = MemorySink();
      final stderr = MemorySink();
      final code = await cli.run(
        ['probe'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 5);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains('probe failed'));
    });

    test('json mode ignores toText and writes structured output to stdout',
        () async {
      final cli = ModularCli()
        ..query<_StreamInput, _StreamOutput>(
          'probe',
          (req) => _StreamProbeQuery(_StreamInput.fromCliRequest(req)),
        );

      final stdout = MemorySink();
      final stderr = MemorySink();
      final code = await cli.run(
        ['probe', '--json'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.ok);
      expect(await stdout.text(), contains('"message": "human text"'));
      expect(await stdout.text(), isNot(contains('human text\n')));
      expect(await stderr.text(), isEmpty);
    });
  });
}

class _StreamInput extends Input {
  _StreamInput();

  factory _StreamInput.fromCliRequest(CliRequest req) => _StreamInput();

  @override
  Map<String, dynamic> toJson() => {};
}

class _StreamOutput extends Output {
  final String message;

  _StreamOutput({required this.message});

  @override
  Map<String, dynamic> toJson() => {'message': message};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => message;
}

class _StreamProbeQuery implements Query<_StreamInput, _StreamOutput> {
  @override
  final _StreamInput input;

  _StreamProbeQuery(this.input);

  @override
  String? validate() => null;

  @override
  Future<_StreamOutput> execute() async =>
      _StreamOutput(message: 'human text');
}

class _ExceptionProbeQuery implements Query<_StreamInput, _StreamOutput> {
  @override
  final _StreamInput input;

  _ExceptionProbeQuery(this.input);

  @override
  String? validate() => null;

  @override
  Future<_StreamOutput> execute() async {
    throw CommandException(
      code: 'PROBE_FAILED',
      message: 'probe failed',
      exitCode: 5,
    );
  }
}