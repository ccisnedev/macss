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

import 'support/memory_sink.dart';

void main() {
  late Directory tempRoot;
  late Directory assetsRoot;
  late Assets assets;
  late String dest;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('macss_skill_test_');
    assetsRoot = Directory(p.join(tempRoot.path, '_assets'));
    dest = p.join(tempRoot.path, 'project');

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

  String deployedSkill(String name) =>
      p.join(dest, '.skills', name, 'SKILL.md');

  SkillDeployCommand deployCmd({String? host, Map<String, String>? env}) =>
      SkillDeployCommand(
        SkillDeployInput(resolvedPath: dest, host: host),
        assets: assets,
        environment: env,
      );

  group('macss skill deploy', () {
    test('writes every shipped skill into .skills/', () async {
      final out = await deployCmd().execute();

      expect(out.exitCode, ExitCode.ok);
      expect(out.deployed, ['macss-analyze', 'macss-specification']);
      expect(
        File(deployedSkill('macss-specification')).readAsStringSync(),
        '# Specification skill',
      );
      expect(File(deployedSkill('macss-analyze')).existsSync(), isTrue);
      expect(out.message, contains('created  .skills/macss-analyze/SKILL.md'));
    });

    test('is idempotent — an unchanged skill reports exists', () async {
      await deployCmd().execute();
      final out = await deployCmd().execute();

      expect(out.message, contains('exists   .skills/macss-analyze/SKILL.md'));
      expect(out.message, isNot(contains('created')));
    });

    test('refreshes a stale skill rather than leaving it behind', () async {
      await deployCmd().execute();
      File(deployedSkill('macss-analyze')).writeAsStringSync('# Old version');

      final out = await deployCmd().execute();

      expect(out.message, contains('updated  .skills/macss-analyze/SKILL.md'));
      expect(
        File(deployedSkill('macss-analyze')).readAsStringSync(),
        '# Analyze skill',
      );
    });

    test('--host also deploys to the assistant directory', () async {
      final home = p.join(tempRoot.path, 'home');
      final out = await deployCmd(
        host: 'claude',
        env: {'HOME': home},
      ).execute();

      expect(out.exitCode, ExitCode.ok);
      expect(File(deployedSkill('macss-analyze')).existsSync(), isTrue);
      expect(
        File(p.join(home, '.claude', 'skills', 'macss-analyze', 'SKILL.md'))
            .existsSync(),
        isTrue,
      );
    });

    test('--host fails cleanly when no home directory resolves', () async {
      final out = await deployCmd(host: 'claude', env: const {}).execute();

      expect(out.exitCode, ExitCode.genericError);
      expect(out.message, contains('home directory'));
    });

    test('validate rejects a path that is an existing file', () {
      File(dest).createSync(recursive: true);
      expect(deployCmd().validate(), contains('existing file'));
    });

    test('validate rejects assets with no skills directory', () {
      final empty = Assets(root: p.join(tempRoot.path, 'nowhere'));
      final cmd = SkillDeployCommand(
        SkillDeployInput(resolvedPath: dest),
        assets: empty,
      );
      expect(cmd.validate(), contains('macss upgrade'));
    });
  });

  group('macss skill list', () {
    test('lists the shipped skills, sorted', () async {
      final out = await SkillListCommand(SkillListInput(), assets: assets)
          .execute();
      expect(out.skills, ['macss-analyze', 'macss-specification']);
    });
  });

  group('macss skill clean', () {
    test('removes what was deployed and reports what was absent', () async {
      await deployCmd().execute();
      Directory(p.join(dest, '.skills', 'macss-analyze'))
          .deleteSync(recursive: true);

      final out = await SkillCleanCommand(
        SkillCleanInput(resolvedPath: dest),
        assets: assets,
      ).execute();

      expect(out.removed, ['macss-specification']);
      expect(out.message, contains('absent   .skills/macss-analyze'));
      expect(
        Directory(p.join(dest, '.skills', 'macss-specification')).existsSync(),
        isFalse,
      );
    });

    test('leaves foreign skills in the directory alone', () async {
      await deployCmd().execute();
      final foreign = File(p.join(dest, '.skills', 'someone-else', 'SKILL.md'));
      foreign.createSync(recursive: true);
      foreign.writeAsStringSync('# Not ours');

      await SkillCleanCommand(
        SkillCleanInput(resolvedPath: dest),
        assets: assets,
      ).execute();

      expect(foreign.existsSync(), isTrue);
    });
  });

  group('hostSkillsDirectory', () {
    test('resolves the known hosts from HOME', () {
      expect(
        hostSkillsDirectory('claude', environment: {'HOME': '/h'}),
        p.join('/h', '.claude', 'skills'),
      );
      expect(
        hostSkillsDirectory('opencode', environment: {'HOME': '/h'}),
        p.join('/h', '.config', 'opencode', 'skill'),
      );
    });

    test('falls back to USERPROFILE on Windows', () {
      expect(
        hostSkillsDirectory('claude', environment: {'USERPROFILE': r'C:\u'}),
        p.join(r'C:\u', '.claude', 'skills'),
      );
    });

    test('returns null for an unknown host', () {
      expect(
        hostSkillsDirectory('bogus', environment: {'HOME': '/h'}),
        isNull,
      );
    });
  });

  // Contract style: wire the command through a real ModularCli so the declared
  // parameter contract is enforced end to end, without the compiled binary.
  group('macss skill contract', () {
    ModularCli makeCli() =>
        ModularCli()..module('skill', (m) => buildSkillModule(m, assets: assets));

    test('rejects an undeclared option before deploying anything', () async {
      final stderr = MemorySink();
      final code = await makeCli().run(
        ['skill', 'deploy', '--path=$dest', '--bogus'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stderr.text(), contains('unknown option --bogus'));
      expect(Directory(p.join(dest, '.skills')).existsSync(), isFalse);
    });

    test('rejects a --host outside the allowed set', () async {
      final stderr = MemorySink();
      final code = await makeCli().run(
        ['skill', 'deploy', '--path=$dest', '--host=notepad'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(Directory(p.join(dest, '.skills')).existsSync(), isFalse);
    });

    test('accepts the -p abbreviation', () async {
      final code = await makeCli().run(
        ['skill', 'deploy', '-p', dest],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      expect(File(deployedSkill('macss-analyze')).existsSync(), isTrue);
    });

    test('list rejects any option (empty contract)', () async {
      final code = await makeCli().run(
        ['skill', 'list', '--path=x'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.validationFailed);
    });
  });
}
