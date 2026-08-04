import 'dart:convert';
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

/// The command names the banner advertises, read out of its `Commands:` block.
///
/// The banner is a formatted string with colour codes, so strip those first and
/// take the leading word of each indented entry — which is what a user's eye
/// does too.
Set<String> _bannerCommands(String banner) {
  final plain = banner.replaceAll(RegExp(r'\[[0-9;]*m'), '');
  final commands = <String>{};

  var inBlock = false;
  for (final line in const LineSplitter().convert(plain)) {
    if (line.trimLeft().startsWith('Commands:')) {
      inBlock = true;
      continue;
    }
    if (!inBlock) continue;
    // The block ends at the first line that is not an indented entry.
    if (line.trim().isEmpty) break;

    final entry = RegExp(r'^\s{2,}([a-z][a-z-]*)\s{2,}\S').firstMatch(line);
    if (entry == null) break;
    commands.add(entry.group(1)!);
  }

  return commands;
}

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

    // The banner is hand-maintained, and it advertised `issue` for as long as
    // that module existed plus however long it would have taken someone to
    // notice. `contains('create')` passed the whole time — and still passes
    // today, on a command that no longer exists, because the word also appears
    // in the Quickstart line. Read a substring, learn nothing.
    //
    // This asks the question that matters: is every command the banner names
    // one the CLI actually answers?
    test(
      'every command the banner advertises is a route the CLI has',
      () async {
        final output = await _makeTui().execute();

        final stdout = MemorySink();
        await runMacss(
          const ['help', '--json'],
          stdout: stdout.sink,
          stderr: MemorySink().sink,
        );
        final catalog = jsonDecode(await stdout.text()) as Map<String, dynamic>;
        final routes = (catalog['commands'] as List)
            .cast<Map<String, dynamic>>()
            .map((c) => c['route'] as String)
            .toSet();

        // A banner entry names either a root command (`doctor`) or a module
        // (`project`), which stands for the routes underneath it.
        bool served(String name) =>
            routes.contains(name) || routes.any((r) => r.startsWith('$name '));

        final advertised = _bannerCommands(output.banner);
        expect(
          advertised,
          isNotEmpty,
          reason: 'the banner parser found nothing',
        );

        for (final name in advertised) {
          expect(
            served(name),
            isTrue,
            reason:
                'the banner advertises `macss $name`, '
                'which the CLI does not accept',
          );
        }
      },
    );

    test('the banner names every lifecycle stage', () async {
      // A new user reads this list before anything else. A stage missing from
      // it is a stage they will not know exists.
      final output = await _makeTui().execute();

      expect(
        _bannerCommands(output.banner),
        containsAll(<String>['project', 'requisition', 'specification', 'dor']),
      );
    });

    test('the parser reads the banner the way it is actually written', () {
      // Trusting an unverified parser is how a guard silently passes on
      // nothing: an empty result set satisfies every `for` loop.
      expect(
        _bannerCommands(
          '  Commands:\n'
          '    [36mproject[0m     scaffold the canon\n'
          '    [36mdoctor[0m      verify the install\n'
          '\n'
          '  Quickstart:  macss project create --path=my-project',
        ),
        <String>{'project', 'doctor'},
      );
    });

    test('TuiOutput.banner contains quickstart hint', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains(quickstartCommand));
    });

    // Asserting the banner merely *contains* a string is what let it advertise
    // `macss create my-project` — a positional argument the CLI rejects, on a
    // deprecated alias. It exited 7: the first command a new user was told to
    // run did not work. This guard runs it instead of reading it.
    test('the quickstart command the banner advertises actually works', () async {
      final tempRoot = Directory.systemTemp.createTempSync(
        'macss_quickstart_test_',
      );
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

      // The advertised command asks before it writes, and there is no terminal
      // here to answer. Standing in for the human is what lets this assert the
      // quickstart actually scaffolds, rather than only that it parses.
      var asked = false;
      final code =
          await (ModularCli()..module(
                'project',
                (m) => buildProjectModule(
                  m,
                  assets: assets,
                  approver: (_) async {
                    asked = true;
                    return true;
                  },
                ),
              ))
              .run(args, stdout: MemorySink().sink, stderr: MemorySink().sink);

      expect(code, ExitCode.ok, reason: 'quickstart was: $quickstartCommand');
      expect(asked, isTrue,
          reason: 'the quickstart must show what it will do before doing it');
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
