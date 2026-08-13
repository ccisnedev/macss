import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

void main() {
  group('api graphql command contract', () {
    test('validate() maps to validationFailed and writes to stderr', () async {
      final cli = ModularCli()
        ..query<_ProbeInput, _ProbeOutput>(
          'probe',
          (req) => _InvalidProbeQuery(_ProbeInput.fromCliRequest(req)),
        );

      final stdout = MemorySink();
      final stderr = MemorySink();
      final code = await cli.run(
        ['probe'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains('VALIDATION_FAILED'));
    });

    test('custom output exit code is preserved and toText goes to stdout',
        () async {
      final cli = ModularCli()
        ..query<_ProbeInput, _ProbeOutput>(
          'probe',
          (req) => _CustomExitProbeQuery(_ProbeInput.fromCliRequest(req)),
        );

      final stdout = MemorySink();
      final stderr = MemorySink();
      final code = await cli.run(
        ['probe'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 5);
      expect(await stdout.text(), equals('probe ok\n'));
      expect(await stderr.text(), isEmpty);
    });

    test('matched commands get contextual help from the contract', () async {
      // Since modular_cli_sdk 0.3.3 the framework answers `--help` itself,
      // rendering the command's declared contract before the command body runs.
      final cli = ModularCli()
        ..query<_ProbeInput, _ProbeOutput>(
          'probe',
          (req) => _HelpFlagProbeQuery(
            _ProbeInput.fromCliRequest(req),
            helpRequested: req.flagBool('help'),
          ),
        );

      final stdout = MemorySink();
      final stderr = MemorySink();
      final code = await cli.run(
        ['probe', '--help'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.ok);
      final out = await stdout.text();
      expect(out, contains('Usage: probe'));
      expect(out, isNot(contains('helpRequested')));
      expect(await stderr.text(), isEmpty);
    });
  });
}

class _ProbeInput extends Input {
  _ProbeInput();

  factory _ProbeInput.fromCliRequest(CliRequest req) => _ProbeInput();

  @override
  Map<String, dynamic> toJson() => {};
}

class _ProbeOutput extends Output {
  final String message;
  final int code;

  _ProbeOutput({required this.message, this.code = ExitCode.ok});

  @override
  Map<String, dynamic> toJson() => {'message': message};

  @override
  int get exitCode => code;

  @override
  String? toText() => message;
}

class _InvalidProbeQuery implements Query<_ProbeInput, _ProbeOutput> {
  @override
  final _ProbeInput input;

  _InvalidProbeQuery(this.input);

  @override
  String? validate() => 'probe input is invalid';

  @override
  Future<_ProbeOutput> execute() async =>
      _ProbeOutput(message: 'should not execute');
}

class _CustomExitProbeQuery implements Query<_ProbeInput, _ProbeOutput> {
  @override
  final _ProbeInput input;

  _CustomExitProbeQuery(this.input);

  @override
  String? validate() => null;

  @override
  Future<_ProbeOutput> execute() async =>
      _ProbeOutput(message: 'probe ok', code: 5);
}

class _HelpFlagProbeQuery implements Query<_ProbeInput, _ProbeOutput> {
  @override
  final _ProbeInput input;
  final bool helpRequested;

  _HelpFlagProbeQuery(this.input, {required this.helpRequested});

  @override
  String? validate() => null;

  @override
  Future<_ProbeOutput> execute() async =>
      _ProbeOutput(message: 'helpRequested=$helpRequested');
}