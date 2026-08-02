import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/tui.dart';
import 'package:macss_cli/modules/global/commands/version.dart';
import 'package:macss_cli/modules/project/canon.dart';
import 'package:macss_cli/modules/project/project_builder.dart';
import 'package:macss_cli/src/version_check.dart';

import 'support/memory_sink.dart';

/// A shipped-asset tree with one file per canon entry, so the advertised
/// command can stamp a whole project.
Assets _quickstartAssets(Directory root) {
  final assetsRoot = Directory(p.join(root.path, '_assets'));
  for (final file in canonFiles) {
    final f = File(
      p.join(assetsRoot.path, 'assets', p.joinAll(file.template.split('/'))),
    );
    f.createSync(recursive: true);
    f.writeAsStringSync('# ${file.path}');
  }
  return Assets(root: assetsRoot.path);
}

TuiCommand _makeTui() => TuiCommand(
  TuiInput(),
  versionChecker: ({required String currentVersion}) async =>
      const VersionCheckResult(updateAvailable: false),
);

void main() {
  group('TUI Command', () {
    test('root command rejects an unknown flag as invalid usage', () async {
      // A lone flag on the bare root never routes to the banner: the router
      // treats it as an unknown command (exit 64), not a contract violation.
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 64); // ExitCode.invalidUsage
      expect(await stderr.text(), contains('unknown command'));
    });

    test('TuiInput.fromCliRequest returns TuiInput', () {
      expect(TuiInput(), isA<TuiInput>());
    });

    test('TuiOutput contains version string', () async {
      final output = await _makeTui().execute();
      expect(output.version, equals(macssVersion));
    });

    test('TuiOutput.banner contains version', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains(macssVersion));
    });

    test('TuiOutput.banner contains command names', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains('create'));
      expect(output.banner, contains('doctor'));
      expect(output.banner, contains('upgrade'));
      expect(output.banner, contains('uninstall'));
      expect(output.banner, contains('version'));
    });

    test('TuiOutput.banner contains quickstart hint', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains(quickstartCommand));
    });

    // Asserting the banner merely *contains* a string is what let it advertise
    // `macss create my-project` — a positional argument the CLI rejects, on a
    // deprecated alias. It exited 7: the first command a new user was told to
    // run did not work. This guard runs it instead of reading it.
    test('the quickstart command the banner advertises actually works',
        () async {
      final tempRoot =
          Directory.systemTemp.createTempSync('macss_quickstart_test_');
      addTearDown(() {
        if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
      });

      final assets = _quickstartAssets(tempRoot);
      final dest = p.join(tempRoot.path, 'my-project');

      // Take the advertised command verbatim, dropping only the executable name
      // and retargeting the example path so the test controls where it writes.
      final args = [
        for (final arg in quickstartCommand.split(' ').skip(1))
          arg.startsWith('--path') ? '--path=$dest' : arg,
      ];

      final code = await (ModularCli()
            ..module('project', (m) => buildProjectModule(m, assets: assets)))
          .run(args, stdout: MemorySink().sink, stderr: MemorySink().sink);

      expect(code, ExitCode.ok, reason: 'quickstart was: $quickstartCommand');
      expect(File(p.join(dest, 'README.md')).existsSync(), isTrue);
    });

    test('TuiOutput.exitCode is 0', () async {
      final output = await _makeTui().execute();
      expect(output.exitCode, 0);
    });

    test('TuiOutput.toText returns banner only', () async {
      final output = await _makeTui().execute();
      expect(output.toText(), equals(output.banner));
      expect(output.toText(), isNot(contains('version:')));
      expect(output.toText(), isNot(contains('banner:')));
    });

    test('TuiCommand.validate returns null', () {
      expect(_makeTui().validate(), isNull);
    });

    test('shows update hint when new version is available', () async {
      final tui = TuiCommand(
        TuiInput(),
        versionChecker: ({required String currentVersion}) async =>
            const VersionCheckResult(
              updateAvailable: true,
              latestVersion: '9.9.9',
            ),
      );
      final output = await tui.execute();
      expect(output.banner, contains('9.9.9'));
      expect(output.banner, contains('upgrade'));
    });
  });
}
