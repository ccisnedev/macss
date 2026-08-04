import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

void main() {
  group('api graphql cli streams', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_cli_streams_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compile rejects an undeclared option', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--bogus'],
        workingDirectory: tempDir.path,
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(exitCode, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('compile help text is routed to stderr in text mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--help'],
        workingDirectory: tempDir.path,
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(exitCode, 0);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains('Usage:'));
    });

    test('compile help stays on stdout in json mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--help', '--json'],
        workingDirectory: tempDir.path,
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      // Since modular_cli_sdk 0.3.3, JSON help emits the command's declared
      // contract (route/description/params), not a prose `message` payload.
      expect(exitCode, 0);
      final out = await stdout.text();
      expect(out, contains('"route"'));
      expect(out, contains('api graphql compile'));
      expect(await stderr.text(), isEmpty);
    });

    test('compile validation failures are routed to stderr in text mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--apply', '--autoapprove'],
        workingDirectory: tempDir.path,
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(exitCode, 3);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains('sourceRoot'));
    });
  });
}