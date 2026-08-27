/// `macss migrate-skills` — the one-time move off the prefix era.
///
/// Before 0.12.0 macss proved ownership with a `macss-` filename prefix and
/// kept no ledger. Those copies cannot simply be adopted into the new one: their
/// frontmatter predates `license` and `metadata`, so their content hash differs
/// from what 0.12.0 deploys, and R10.6 adopts only an identical hash. They have
/// to go before the new deploy can create them.
///
/// Only macss can remove them, and only macss can say why: the prefix was its
/// own ownership marker, and nothing else on the machine is entitled to read it
/// that way. Everything without the prefix is left alone — the same rule
/// `inquiry`'s `clean` now follows, for the same reason.
///
/// **This route is temporary.** It exists for one upgrade and is removed in
/// 0.13.0. It sits outside the `skill` module deliberately: PRD 12.2 fixes that
/// module at five routes and R12.1 requires it to be identical in every
/// consumer, so a migration belonging to one consumer's history belongs
/// somewhere else.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';

/// The prefix the era used as its ownership marker.
const macssSkillNamespace = 'macss-';

class MigrateSkillsInput extends Input {
  MigrateSkillsInput();

  factory MigrateSkillsInput.fromCliRequest(CliRequest req) =>
      MigrateSkillsInput();

  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => const {};
}

class MigrateSkillsOutput extends Output {
  MigrateSkillsOutput({required this.removed});

  final List<String> removed;

  @override
  Map<String, dynamic> toJson() => {'removed': removed};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() {
    if (removed.isEmpty) {
      return 'Nothing left from the prefix era. This machine is already on the '
          'ledger, or never had any skills deployed by macss.';
    }
    return [
      'Removed ${removed.length} prefix-era skill(s):',
      for (final r in removed) '  $r',
      '',
      'Now deploy them again, this time recorded:',
      '  macss skill deploy --host claude --scope global --all --apply',
    ].join('\n');
  }
}

class MigrateSkillsCommand
    implements Command<MigrateSkillsInput, MigrateSkillsOutput> {
  MigrateSkillsCommand(
    this.input, {
    required this.home,
    required this.ledgerFile,
  });

  @override
  final MigrateSkillsInput input;

  final String home;
  final LedgerFile ledgerFile;

  final List<String> _removed = [];

  /// The two directories the prefix era wrote to, from 0.11.0's
  /// `modules/skill/host.dart`.
  ///
  /// OpenCode's is the **singular** spelling. It reads both under a brace glob,
  /// so the copies there were live all along and are the reason `skill doctor`
  /// reports each macss skill as visible to OpenCode from two directories.
  List<String> get _legacyDirectories => [
    p.join(home, '.claude', 'skills'),
    p.join(home, '.config', 'opencode', 'skill'),
  ];

  @override
  String? validate() => home.isEmpty ? 'No home directory resolved.' : null;

  @override
  Future<List<Step>> steps() async {
    // A ledgered destination is managed, whoever manages it. Removing one would
    // leave the ledger describing a directory that is gone, and if the owner is
    // another consumer it would be rule 1 broken outright.
    final managed = {
      for (final row in ledgerFile.read().rows.values)
        p.normalize(row.resolvedDestinationPath),
    };

    return [
      for (final directory in _legacyDirectories)
        if (Directory(directory).existsSync())
          for (final entry in Directory(directory).listSync().whereType<Directory>())
            if (p.basename(entry.path).startsWith(macssSkillNamespace) &&
                File(p.join(entry.path, 'SKILL.md')).existsSync() &&
                !managed.contains(p.normalize(entry.path)))
              _RemovePrefixEraSkill(entry.path, _removed),
    ];
  }

  @override
  MigrateSkillsOutput describe(Execution execution) =>
      MigrateSkillsOutput(removed: _removed);
}

/// Removes one prefix-era directory, and only the directory.
class _RemovePrefixEraSkill implements Step {
  _RemovePrefixEraSkill(this.directory, this._removed);

  final String directory;
  final List<String> _removed;

  @override
  Preview preview() => Preview(
    verb: 'remove',
    target: directory,
    detail: 'deployed before there was a ledger, and its contents predate the '
        'frontmatter this release ships, so it cannot be adopted',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    Directory(directory).deleteSync(recursive: true);
    _removed.add(directory);
    return Outcome(verb: 'remove', target: directory);
  }
}
