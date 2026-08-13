import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/skill/commands/clean.dart';
import 'package:macss_cli/modules/skill/commands/deploy.dart';
import 'package:macss_cli/modules/skill/commands/list.dart';
import 'package:macss_cli/modules/skill/host.dart';
import 'package:macss_cli/modules/skill/skill_builder.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';

import 'support/memory_sink.dart';

void main() {
  late Directory tempRoot;
  late Directory assetsRoot;
  late Assets assets;
  late String home;
  late Map<String, String> env;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('macss_skill_test_');
    assetsRoot = Directory(p.join(tempRoot.path, '_assets'));
    home = p.join(tempRoot.path, 'home');
    env = {'HOME': home};

    for (final entry in {
      'macss-specification': '# Specification skill',
      'macss-analyze': '# Analyze skill',
    }.entries) {
      final f = File(
        p.join(assetsRoot.path, 'assets', 'skills', entry.key, 'SKILL.md'),
      );
      f.createSync(recursive: true);
      f.writeAsStringSync(entry.value);
    }

    assets = Assets(root: assetsRoot.path);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  /// Marks [host] as installed by creating its config root, which is what
  /// detection looks for.
  void installHost(String host) {
    Directory(hostPaths(host, environment: env)!.markerDirectory)
        .createSync(recursive: true);
  }

  File skillIn(String host, String name) => File(
        p.join(hostPaths(host, environment: env)!.skillsDirectory, name,
            'SKILL.md'),
      );

  SkillDeployCommand deployCmd({String? host}) => SkillDeployCommand(
    SkillDeployInput(host: host),
    assets: assets,
    environment: env,
  );

  SkillCleanCommand cleanCmd({String? host}) => SkillCleanCommand(
    SkillCleanInput(host: host),
    assets: assets,
    environment: env,
  );

  Future<SkillDeployOutput> deploy({String? host}) async =>
      await applyCommand(deployCmd(host: host));

  Future<SkillCleanOutput> clean({String? host}) async =>
      await applyCommand(cleanCmd(host: host));

  /// Every verb the run reported, against the skill it acted on.
  Map<String, String> verbsOf(SkillDeployOutput out) => {
    for (final entry in out.byHost.values)
      for (final s in entry) s.skill: s.verb,
  };

  group('macss skill deploy', () {
    test('deploys to every installed assistant when no --host is given',
        () async {
      installHost('claude');
      installHost('opencode');

      final out = await deploy();

      expect(out.exitCode, ExitCode.ok);
      expect(out.hosts, ['claude', 'opencode']);
      expect(skillIn('claude', 'macss-analyze').existsSync(), isTrue);
      expect(skillIn('opencode', 'macss-analyze').existsSync(), isTrue);
      expect(
        skillIn('claude', 'macss-specification').readAsStringSync(),
        '# Specification skill',
      );
    });

    test('skips an assistant that is not installed', () async {
      installHost('claude');

      final out = await deploy();

      expect(out.hosts, ['claude']);
      expect(skillIn('opencode', 'macss-analyze').existsSync(), isFalse);
    });

    test('--host deploys even when the assistant looks uninstalled', () async {
      // Priming a fresh setup before the assistant has ever run.
      final out = await deploy(host: 'claude');

      expect(out.exitCode, ExitCode.ok);
      expect(out.hosts, ['claude']);
      expect(skillIn('claude', 'macss-analyze').existsSync(), isTrue);
    });

    // Not a validation failure — the invocation was well formed and there is
    // nothing here to deploy to. Thrown, so it keeps the exit code it always
    // had rather than becoming a 7.
    test('reports clearly when no assistant is found', () async {
      await expectLater(
        deploy(),
        throwsA(
          isA<CommandException>()
              .having((e) => e.exitCode, 'exitCode', ExitCode.notFound)
              .having((e) => e.message, 'message', contains('--host')),
        ),
      );
    });

    test('is idempotent — an unchanged skill reports exists', () async {
      installHost('claude');
      await deploy();

      final out = await deploy();

      expect(verbsOf(out)['macss-analyze'], 'exists');
      expect(verbsOf(out).values, isNot(contains('create')));
    });

    test('refreshes a stale skill rather than leaving it behind', () async {
      installHost('claude');
      await deploy();
      skillIn('claude', 'macss-analyze').writeAsStringSync('# Old version');

      final out = await deploy();

      expect(verbsOf(out)['macss-analyze'], 'update');
      expect(
        skillIn('claude', 'macss-analyze').readAsStringSync(),
        '# Analyze skill',
      );
    });

    // The step says it would refresh before it does, so a stale skill is named
    // in the plan rather than discovered afterwards. This is what the dryRun
    // boolean could never be held to.
    test('says which skills it would refresh, and refreshes none', () async {
      installHost('claude');
      await deploy();
      skillIn('claude', 'macss-analyze').writeAsStringSync('# Old version');

      final previews = await previewCommand(deployCmd());

      expect(
        previews.firstWhere((p) => p.target.contains('macss-analyze')).verb,
        'update',
      );
      expect(
        skillIn('claude', 'macss-analyze').readAsStringSync(),
        '# Old version',
        reason: 'asking changes nothing',
      );
    });

    test('fails cleanly when no home directory resolves', () async {
      await expectLater(
        applyCommand(
          SkillDeployCommand(
            SkillDeployInput(host: 'claude'),
            assets: assets,
            environment: const {},
          ),
        ),
        throwsA(
          isA<CommandException>()
              .having((e) => e.exitCode, 'exitCode', ExitCode.genericError)
              .having((e) => e.message, 'message', contains('home directory')),
        ),
      );
    });

    test('retires a namespaced skill that is no longer shipped', () async {
      // Deployment that can only add leaves frozen copies nothing will update
      // again — exactly what stranded the iq-* skills when the lifecycle moved.
      installHost('claude');
      await deploy();
      final dropped = File(
        p.join(hostPaths('claude', environment: env)!.skillsDirectory,
            'macss-retired', 'SKILL.md'),
      );
      dropped.createSync(recursive: true);
      dropped.writeAsStringSync('# from an older release');

      final out = await deploy();

      expect(dropped.parent.existsSync(), isFalse);
      expect(verbsOf(out)['macss-retired'], 'remove');
    });

    test('never retires a skill outside the MACSS namespace', () async {
      installHost('claude');
      final foreign = File(
        p.join(hostPaths('claude', environment: env)!.skillsDirectory,
            'iq-analyze', 'SKILL.md'),
      );
      foreign.createSync(recursive: true);
      foreign.writeAsStringSync("# another tool's");

      await deploy();

      expect(foreign.existsSync(), isTrue);
    });

    test('validate rejects assets with no skills directory', () {
      final empty = Assets(root: p.join(tempRoot.path, 'nowhere'));
      final cmd = SkillDeployCommand(SkillDeployInput(), assets: empty);
      expect(cmd.validate(), contains('macss upgrade'));
    });
  });

  group('macss skill list', () {
    test('lists the shipped skills, sorted', () async {
      final out =
          await SkillListCommand(SkillListInput(), assets: assets).execute();
      expect(out.skills, ['macss-analyze', 'macss-specification']);
    });
  });

  group('macss skill clean', () {
    test('removes what was deployed and reports what was absent', () async {
      installHost('claude');
      await deploy();
      skillIn('claude', 'macss-analyze').parent.deleteSync(recursive: true);

      final out = await clean();

      expect(out.removed, ['macss-specification']);
      expect(out.absent, ['macss-analyze']);
      expect(skillIn('claude', 'macss-specification').existsSync(), isFalse);
    });

    test('leaves foreign skills in the directory alone', () async {
      installHost('claude');
      await deploy();
      final foreign = File(
        p.join(hostPaths('claude', environment: env)!.skillsDirectory,
            'someone-else', 'SKILL.md'),
      );
      foreign.createSync(recursive: true);
      foreign.writeAsStringSync('# Not ours');

      await clean();

      expect(foreign.existsSync(), isTrue);
    });
  });

  group('host resolution', () {
    test('resolves the known hosts from HOME', () {
      expect(
        hostPaths('claude', environment: {'HOME': '/h'})!.skillsDirectory,
        p.join('/h', '.claude', 'skills'),
      );
      expect(
        hostPaths('opencode', environment: {'HOME': '/h'})!.skillsDirectory,
        p.join('/h', '.config', 'opencode', 'skill'),
      );
    });

    test('falls back to USERPROFILE on Windows', () {
      expect(
        hostPaths('claude', environment: {'USERPROFILE': r'C:\u'})!
            .skillsDirectory,
        p.join(r'C:\u', '.claude', 'skills'),
      );
    });

    test('returns null for an unknown host', () {
      expect(hostPaths('bogus', environment: {'HOME': '/h'}), isNull);
    });

    test('detection reports only assistants whose config root exists', () {
      expect(detectHosts(environment: env), isEmpty);
      installHost('opencode');
      expect(detectHosts(environment: env), ['opencode']);
    });
  });

  // Contract style: wire the command through a real ModularCli so the declared
  // parameter contract is enforced end to end, without the compiled binary.
  group('macss skill contract', () {
    ModularCli makeCli() => ModularCli()
      ..module('skill', (m) => buildSkillModule(m, assets: assets));

    test('rejects an undeclared option', () async {
      final stderr = MemorySink();
      final code = await makeCli().run(
        ['skill', 'deploy', '--bogus'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('rejects a --host outside the allowed set', () async {
      final code = await makeCli().run(
        ['skill', 'deploy', '--host=notepad'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.validationFailed);
    });

    test('list rejects any option (empty contract)', () async {
      final code = await makeCli().run(
        ['skill', 'list', '--host=claude'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.validationFailed);
    });
  });
}
