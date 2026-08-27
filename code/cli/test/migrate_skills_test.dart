import 'dart:io';

import 'package:macss_cli/modules/global/commands/migrate_skills.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// The one-time migration off the prefix era.
///
/// Before 0.12.0, macss proved ownership with a `macss-` filename prefix and
/// kept no ledger. Those copies cannot be adopted — their frontmatter predates
/// `license` and `metadata`, so their content hash differs from what 0.12.0
/// would deploy, and R10.6 will not adopt a differing hash. They have to go
/// before the new deploy can create them, and only macss can remove them,
/// because only macss can say the prefix was its own.
void main() {
  late Directory tmp;
  late String home;
  late String ledgerPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('macss_migrate_');
    home = p.join(tmp.path, 'home');
    ledgerPath = p.join(tmp.path, 'state', 'ledger.json');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// The two directories the prefix era wrote to, from macss 0.11.0's
  /// `modules/skill/host.dart`: Claude's, and OpenCode's **singular** spelling.
  String claudeSkills() => p.join(home, '.claude', 'skills');
  String opencodeSkill() => p.join(home, '.config', 'opencode', 'skill');

  Directory plant(String directory, String name) {
    final f = File(p.join(directory, name, 'SKILL.md'));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('---\nname: $name\ndescription: prefix era\n---\n');
    return f.parent;
  }

  MigrateSkillsCommand command() => MigrateSkillsCommand(
    MigrateSkillsInput(),
    home: home,
    ledgerFile: LedgerFile(ledgerPath),
  );

  group('what it removes', () {
    test('the prefix-era copies in both directories', () async {
      final claude = plant(claudeSkills(), 'macss-plan');
      final opencode = plant(opencodeSkill(), 'macss-plan');

      await applyCommand(command());

      expect(claude.existsSync(), isFalse);
      expect(opencode.existsSync(), isFalse);
    });

    test('every prefixed name, not a hard-coded list', () async {
      // Scoped by prefix rather than by the five names this release ships, so a
      // skill macss dropped in an earlier version goes too.
      for (final n in ['macss-plan', 'macss-retired-long-ago']) {
        plant(claudeSkills(), n);
      }
      await applyCommand(command());
      expect(Directory(claudeSkills()).listSync(), isEmpty);
    });

    test('and reports what it removed', () async {
      plant(claudeSkills(), 'macss-plan');
      final output = await applyCommand(command());
      expect(output.toText(), contains('macss-plan'));
      expect(output.exitCode, ExitCode.ok);
    });
  });

  group('what it must not remove', () {
    test('a skill without the prefix', () async {
      // The prefix was macss's ownership marker. Without it, macss cannot say
      // the directory was ever its own — which is rule 1, and the same
      // reasoning inquiry's `clean` now follows.
      final other = plant(claudeSkills(), 'legion');
      await applyCommand(command());
      expect(other.existsSync(), isTrue);
    });

    test('a prefixed skill that a consumer has since recorded', () async {
      // Once 0.12.0 has deployed and ledgered these, they are managed and the
      // migration has nothing to do. Removing a ledgered directory would leave
      // the ledger describing a file that is gone.
      final managed = plant(claudeSkills(), 'macss-plan');
      final ledger = LedgerFile(ledgerPath);
      ledger.write(
        Ledger()..put(
          const Unit(
            artifact: 'macss-plan',
            kind: Kind.skill,
            host: 'claude',
            scope: Scope.global,
          ),
          LedgerRow(
            sourceType: SourceType.local,
            sourceReference: 'assets',
            resolvedDestinationPath: managed.path,
            contentHash: 'whatever',
            owningConsumer: 'macss',
            artifactVersion: '1.0.0',
            created: DateTime.utc(2026),
            updated: DateTime.utc(2026),
          ),
        ),
      );

      await applyCommand(command());
      expect(managed.existsSync(), isTrue);
    });

    test('one another consumer recorded, whatever its name', () async {
      final theirs = plant(claudeSkills(), 'macss-plan');
      LedgerFile(ledgerPath).write(
        Ledger()..put(
          const Unit(
            artifact: 'macss-plan',
            kind: Kind.skill,
            host: 'claude',
            scope: Scope.global,
          ),
          LedgerRow(
            sourceType: SourceType.local,
            sourceReference: 'assets',
            resolvedDestinationPath: theirs.path,
            contentHash: 'h',
            owningConsumer: 'inquiry',
            artifactVersion: '1.0.0',
            created: DateTime.utc(2026),
            updated: DateTime.utc(2026),
          ),
        ),
      );

      await applyCommand(command());
      expect(theirs.existsSync(), isTrue);
    });

    test('the directories themselves, even when left empty', () async {
      plant(claudeSkills(), 'macss-plan');
      await applyCommand(command());
      expect(Directory(claudeSkills()).existsSync(), isTrue);
    });

    test('a directory with no SKILL.md, prefixed or not', () async {
      final notASkill = Directory(p.join(claudeSkills(), 'macss-notes'))
        ..createSync(recursive: true);
      await applyCommand(command());
      expect(notASkill.existsSync(), isTrue);
    });
  });

  group('the plan says so first', () {
    test('--plan removes nothing', () async {
      final claude = plant(claudeSkills(), 'macss-plan');
      final previews = await previewCommand(command());
      expect(previews.map((x) => x.verb), everyElement('remove'));
      expect(claude.existsSync(), isTrue);
    });

    test('each step names the directory it would remove', () async {
      final claude = plant(claudeSkills(), 'macss-plan');
      final previews = await previewCommand(command());
      expect(previews.single.target, claude.path);
    });
  });

  group('nothing to do', () {
    test('a machine with no prefix-era copies plans nothing', () async {
      expect(await previewCommand(command()), isEmpty);
    });

    test('and says why, rather than only that', () async {
      final output = await applyCommand(command());
      expect(output.exitCode, ExitCode.ok);
      expect(output.toText(), contains('Nothing left from the prefix era'));
    });

    test('it is idempotent', () async {
      plant(claudeSkills(), 'macss-plan');
      await applyCommand(command());
      expect(await previewCommand(command()), isEmpty);
    });

    test('a machine that never had macss is not an error', () async {
      expect(() async => await applyCommand(command()), returnsNormally);
    });
  });
}
