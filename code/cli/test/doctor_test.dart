import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/macss_doctor_checks_plugin.dart';
import 'package:macss_cli/src/tools.dart';
import 'package:macss_cli/src/version.dart';

import 'support/memory_sink.dart';

Assets _makeAssets(Directory root, {List<String> presentTemplates = const []}) {
  final assets = Assets(root: root.path);
  for (final rel in presentTemplates) {
    final file = File(assets.path(rel));
    Directory(p.dirname(file.path)).createSync(recursive: true);
    file.writeAsStringSync('# template');
  }
  return assets;
}

/// Must mirror `_requiredAssets` in macss_doctor_checks_plugin.dart: that map
/// is what `macss doctor` asserts is installed, and this fixture is the
/// "everything present" case.
const _allTemplates = [
  'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
  'templates/project-base/docs/architecture.md',
  'templates/project-base/docs/roadmap.md',
  'templates/project-base/CHANGELOG.md',
  'vocabulary/en.yaml',
  'vocabulary/es.yaml',
  'artifacts/requisition.template.en.md',
  'artifacts/specification.template.en.md',
  'skills/modules/lifecycle/macss-specification/SKILL.md',
  'skills/modules/lifecycle/macss-analyze/SKILL.md',
  'skills/modules/lifecycle/macss-plan/SKILL.md',
  'skills/modules/lifecycle/macss-execute/SKILL.md',
  'skills/modules/lifecycle/macss-verification/SKILL.md',
];

const _allTemplateCheckNames = [
  'template: 0001-record-architecture-decisions.md',
  'template: architecture.md',
  'template: roadmap.md',
  'template: CHANGELOG.md',
  'vocabulary: en',
  'vocabulary: es',
  'artifact: requisition',
  'artifact: specification',
  'skill: macss-specification',
  'skill: macss-analyze',
  'skill: macss-plan',
  'skill: macss-execute',
  'skill: macss-verification',
];

/// An empty PATH, so the external-tool block is deterministic rather than a
/// function of whatever is installed on the machine running the tests.
const _noTools = <String, String>{'PATH': ''};

/// Every [CliDoctorCheck] the plugin contributes, captured without a real
/// [ModularCli], the same approach the SDK's own plugins are tested with, and
/// the only way to test a plugin's `setup` in isolation from the router.
Future<List<CliDoctorCheck>> _contributedChecks(
  MacssDoctorChecksPlugin plugin,
) async {
  final checks = <CliDoctorCheck>[];
  final host = _CapturingHost(checks);
  plugin.setup(host);
  return checks;
}

Future<Map<String, CliCheckResult>> _resultsFor(
  Assets assets, {
  Map<String, String>? environment,
}) async {
  final plugin = MacssDoctorChecksPlugin(
    assets: assets,
    environment: environment ?? _noTools,
  );
  final checks = await _contributedChecks(plugin);
  final results = <String, CliCheckResult>{};
  for (final check in checks) {
    results[check.name] = await check.run();
  }
  return results;
}

/// A minimal [CliPluginHost] that only records [contribute] calls, enough to
/// exercise [MacssDoctorChecksPlugin.setup] without a real [ModularCli].
class _CapturingHost implements CliPluginHost {
  _CapturingHost(this._checks);

  final List<CliDoctorCheck> _checks;

  @override
  void contribute<T>(String extensionPointId, T value) {
    if (value is CliDoctorCheck) {
      _checks.add(value);
    }
  }

  @override
  List<T> contributions<T>(String extensionPointId) => const [];

  @override
  void declareExtensionPoint<T>(String id) {}

  @override
  CliHostMetadata metadata() =>
      const CliHostMetadata(name: 'macss', version: '0.0.0');

  @override
  void registerCommand<I extends Input, O extends Output>(
    String route,
    Command<I, O> Function(CliRequest req) commandFactory, {
    String? description,
    required bool globals,
    CliContract contract = CliContract.none,
  }) {}

  @override
  void registerQuery<I extends Input, O extends Output>(
    String route,
    Query<I, O> Function(CliRequest req) queryFactory, {
    String? description,
    required bool globals,
    CliContract contract = CliContract.none,
  }) {}
}

/// Runs [args] on [cli] and captures both streams, the same way `runMacss`
/// drives a `ModularCli`.
Future<({int exitCode, String stdout, String stderr})> _run(
  ModularCli cli,
  List<String> args,
) async {
  final stdoutController = StreamController<List<int>>();
  final stderrController = StreamController<List<int>>();
  final stdoutBytes = <int>[];
  final stderrBytes = <int>[];

  stdoutController.stream.listen(stdoutBytes.addAll);
  stderrController.stream.listen(stderrBytes.addAll);

  final stdoutSink = IOSink(stdoutController.sink);
  final stderrSink = IOSink(stderrController.sink);

  try {
    final exitCode = await cli.run(
      args,
      stdout: stdoutSink,
      stderr: stderrSink,
    );

    await stdoutSink.flush();
    await stderrSink.flush();
    await stdoutSink.close();
    await stderrSink.close();

    return (
      exitCode: exitCode,
      stdout: utf8.decode(stdoutBytes).trim(),
      stderr: utf8.decode(stderrBytes).trim(),
    );
  } finally {
    await stdoutController.close();
    await stderrController.close();
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_doctor_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('MacssDoctorChecksPlugin', () {
    test(
      'declares its manifest id and requires the doctor extension point',
      () {
        final plugin = MacssDoctorChecksPlugin(assets: _makeAssets(tempDir));
        expect(plugin.manifest.id, equals('macss.doctor_checks'));
        expect(plugin.manifest.requires, contains('modular_cli.doctor'));
      },
    );

    test('rejects an undeclared option (empty contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['doctor', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains("unknown option '--bogus'"));
    });

    test('version check always passes with current version', () async {
      final assets = _makeAssets(tempDir);
      final results = await _resultsFor(assets);

      expect(results['macss']!.status, CliCheckStatus.ok);
      expect(results['macss']!.message, macssVersion);
    });

    test('assets check fails when templates dir is missing', () async {
      final assets = _makeAssets(tempDir);
      final results = await _resultsFor(assets);

      expect(results['assets']!.status, CliCheckStatus.error);
      expect(results['assets']!.message, contains('Reinstall MACSS CLI'));
    });

    test('assets check passes when the templates dir exists', () async {
      Directory(
        p.join(tempDir.path, 'assets', 'templates'),
      ).createSync(recursive: true);
      final assets = _makeAssets(tempDir);
      final results = await _resultsFor(assets);

      expect(results['assets']!.status, CliCheckStatus.ok);
    });

    test('template checks fail individually when files are missing', () async {
      // Only the templates dir is present, no files under it.
      Directory(
        p.join(tempDir.path, 'assets', 'templates'),
      ).createSync(recursive: true);
      final assets = _makeAssets(tempDir);
      final results = await _resultsFor(assets);

      for (final name in _allTemplateCheckNames) {
        expect(results[name]!.status, CliCheckStatus.error, reason: name);
        expect(
          results[name]!.message,
          contains('Run: macss upgrade --apply'),
          reason: name,
        );
      }
    });

    test('all checks pass when assets and templates are present', () async {
      final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
      final results = await _resultsFor(assets);

      expect(results['macss']!.status, CliCheckStatus.ok);
      expect(results['assets']!.status, CliCheckStatus.ok);
      for (final name in _allTemplateCheckNames) {
        expect(results[name]!.status, CliCheckStatus.ok, reason: name);
      }
    });
  });

  group('macss doctor external toolchain', () {
    test('a missing tool warns, and never fails the command', () async {
      final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
      final results = await _resultsFor(assets);

      final toolResults = [
        for (final tool in externalTools) results[tool.executable]!,
      ];
      // Every tool is absent from an empty PATH...
      expect(
        toolResults.every((r) => r.status == CliCheckStatus.warning),
        isTrue,
      );

      // ...yet every check that matters to whether the CLI itself works is
      // still ok, so doctor as a whole would still succeed (a warning never
      // becomes an error).
      expect(
        toolResults.every((r) => r.status != CliCheckStatus.error),
        isTrue,
      );
    });

    test(
      'each missing tool says what it is for and how to install it',
      () async {
        final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
        final results = await _resultsFor(assets);
        final gh = results['gh']!;

        expect(gh.status, CliCheckStatus.warning);
        // Not `macss issue publish`, which this asserted for as long as it
        // existed: there has never been an `issue` module. The suite was
        // defending a command the CLI does not have.
        expect(gh.message, contains('macss requisition publish --apply'));
        expect(gh.message, contains('Install:'));
      },
    );

    test('a tool on PATH is reported ok', () async {
      final binDir = Directory(p.join(tempDir.path, 'bin'))
        ..createSync(recursive: true);
      final exe = Platform.isWindows ? 'gh.cmd' : 'gh';
      File(p.join(binDir.path, exe)).writeAsStringSync('');

      final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
      final results = await _resultsFor(
        assets,
        environment: {'PATH': binDir.path},
      );

      expect(results['gh']!.status, CliCheckStatus.ok);
      // Everything else is still absent.
      expect(results['docker']!.status, CliCheckStatus.warning);
    });
  });

  group('macss doctor end-to-end', () {
    test(
      'runs a real ModularCli doctor invocation and reports success',
      () async {
        final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
        // Tools are still absent (empty PATH), which only warns, so the
        // command as a whole still succeeds.
        final cli =
            ModularCli(suggestionDistance: 2, name: 'macss', version: '0.0.0')
              ..plugin(const DoctorPlugin())
              ..plugin(
                MacssDoctorChecksPlugin(assets: assets, environment: _noTools),
              );

        cli.buildPlugins();

        final result = await _run(cli, ['doctor', '--json']);

        expect(result.exitCode, equals(0));
        final json = jsonDecode(result.stdout) as Map<String, dynamic>;
        final checks = (json['checks'] as List).cast<Map<String, dynamic>>();
        expect(
          checks,
          containsAll([
            containsPair('name', 'macss'),
            containsPair('name', 'assets'),
          ]),
        );
      },
    );

    test(
      'runs a real ModularCli doctor invocation and reports a failing check',
      () async {
        // No templates present at all: every asset check fails.
        final assets = _makeAssets(tempDir);
        final cli =
            ModularCli(suggestionDistance: 2, name: 'macss', version: '0.0.0')
              ..plugin(const DoctorPlugin())
              ..plugin(
                MacssDoctorChecksPlugin(assets: assets, environment: _noTools),
              );

        cli.buildPlugins();

        final result = await _run(cli, ['doctor', '--json']);

        // ExitCode.configError (78): the SDK's own `DoctorQuery` throws when
        // any contributed check reports `error`, which is what carries the
        // whole `checks` array into the error envelope below.
        expect(result.exitCode, equals(78));
        final json = jsonDecode(result.stderr) as Map<String, dynamic>;
        final error = json['error'] as Map<String, dynamic>;
        expect(error['id'], equals('doctor-check-failed'));
        final checks = (error['checks'] as List).cast<Map<String, dynamic>>();
        final assetsCheck = checks.singleWhere((c) => c['name'] == 'assets');
        expect(assetsCheck['status'], equals('error'));
      },
    );
  });

  // A skill shipped but absent from doctor's list is one doctor will never
  // report missing: the work looks complete and the check is silently exempt.
  // Found by diagnosing #34: `macss-verification` shipped, four suites green,
  // and nothing noticed. Then lost with #34's branch when that contract was
  // superseded, and noticed a second time the same way: the skill shipped
  // again, everything stayed green again. A guard living only in the branch
  // it was written for dies with it. Derived from the shipped assets rather
  // than repeated, so the next skill joins without anybody remembering this
  // rule.
  //
  // Doctor keeps its hand-written list on purpose. Deriving its checks from
  // the same directory it inspects would make them vacuous: a deleted skill
  // would simply stop being listed, and a broken installation is precisely
  // what doctor is for. So the list stays, and this is what keeps it complete.
  group('every shipped skill is a skill doctor check', () {
    test('the real assets', () async {
      final assets = Assets(root: Directory.current.path);
      final shipped = assets.listDirectory('skills/modules/lifecycle');

      final plugin = MacssDoctorChecksPlugin(
        assets: assets,
        environment: _noTools,
      );
      final checks = await _contributedChecks(plugin);
      final checked = checks.map((c) => c.name).toSet();

      expect(shipped, isNotEmpty, reason: 'no skills found to check');
      for (final skill in shipped) {
        expect(
          checked,
          contains('skill: $skill'),
          reason:
              '"$skill" is shipped and installed by `skill deploy`, and '
              '`macss doctor` does not check it. Add it to `_requiredAssets` '
              'in macss_doctor_checks_plugin.dart.',
        );
      }
    });
  });
}
