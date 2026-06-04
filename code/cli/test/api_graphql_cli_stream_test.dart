import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

void main() {
  group('api graphql cli streams', () {
    late Directory tempDir;
    late String originalWorkingDirectory;

    setUp(() {
      originalWorkingDirectory = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync('macss_cli_streams_');
      Directory.current = tempDir.path;
    });

    tearDown(() {
      Directory.current = originalWorkingDirectory;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compile help text is routed to stderr in text mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile', '--help'],
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
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(exitCode, 0);
      expect(await stdout.text(), contains('"message"'));
      expect(await stderr.text(), isEmpty);
    });

    test('compile validation failures are routed to stderr in text mode', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final exitCode = await runMacss(
        ['api', 'graphql', 'compile'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(exitCode, 3);
      expect(await stdout.text(), isEmpty);
      expect(await stderr.text(), contains('sourceRoot'));
    });
  });
}