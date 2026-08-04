/// `macss requisition new <slug> [--lang <lang>]` — opens a requisition.
///
/// Writes the form the Product Owner fills, the issue metadata beside it, and
/// records the requisition as the active one so later commands need no slug.
///
/// The specification is **not** created here: it belongs to a later stage, with
/// a different author. `macss specification new` adds it once the request is in.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/gitignore.dart';
import '../../../src/plan_apply.dart';
import '../../../templates/template_resolver.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../issue_metadata.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionNewInput extends Input {
  final String slug;
  final String lang;
  final ChangeFlags flags;

  RequisitionNewInput({
    required this.slug,
    required this.lang,
    required this.flags,
  });

  factory RequisitionNewInput.fromCliRequest(CliRequest req) =>
      RequisitionNewInput(
        slug: normalizeSlug(req.param('slug') ?? ''),
        lang: req.flagString('lang') ?? 'en',
        flags: ChangeFlags.fromCliRequest(req),
      );

  static final List<CliParam> params = [
    CliParam.positional('slug', description: 'Short name for the requisition'),
    CliParam.string(
      'lang',
      allowed: ['en', 'es'],
      defaultValue: 'en',
      description: 'Language of the form handed to the Product Owner',
    ),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'slug': slug,
        'lang': lang,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionNewOutput extends Output {
  final String message;
  final String relDir;
  final String? planPath;
  final bool blocked;

  RequisitionNewOutput({
    required this.message,
    required this.relDir,
    this.planPath,
    this.blocked = false,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'dir': relDir, 'planPath': planPath};

  @override
  int get exitCode => blocked ? ExitCode.genericError : ExitCode.ok;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionNewCommand
    implements Command<RequisitionNewInput, RequisitionNewOutput> {
  @override
  final RequisitionNewInput input;

  final TemplateResolver resolver;
  final String workingDirectory;
  final DateTime Function() now;
  final Approver? approver;

  RequisitionNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
    this.approver,
  }) : now = now ?? DateTime.now;

  @override
  String? validate() {
    if (input.slug.isEmpty) {
      return 'A <slug> is required: macss requisition new <slug>';
    }
    return input.flags.validate();
  }

  @override
  Future<RequisitionNewOutput> execute() async {
    final stamp = now();
    final folder = datedFolder(input.slug, stamp);
    final dir = requisitionDir(workingDirectory, folder);
    final relDir = requisitionRelDir(folder);

    // What opening a requisition would touch, decided before it touches
    // anything. `new` is idempotent, so an existing file is named as kept.
    final formExists = File(p.join(dir, 'requisition.md')).existsSync();
    final metaExists = File(IssueMetadata.pathIn(dir)).existsSync();
    final body = [
      'would open the requisition "${input.slug}" at $relDir:',
      '',
      formExists
          ? '  keep     $relDir/requisition.md (already exists)'
          : '  create   $relDir/requisition.md',
      metaExists
          ? '  keep     $relDir/${IssueMetadata.fileName}'
          : '  create   $relDir/${IssueMetadata.fileName}',
      '  record   $relDir as the active requisition',
      '  ensure   the MACSS workspace is git-ignored',
    ].join('\n');

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'requisition new',
      workingDirectory: workingDirectory,
      body: body,
    );

    if (!decision.proceed) {
      return RequisitionNewOutput(
        message: decision.message!,
        relDir: relDir,
        planPath: decision.planPath,
        blocked: decision.blocked,
      );
    }

    final steps = <String>[];

    // The workspace is local and reproducible; keep it out of version control
    // before anything is written into it.
    final gitignore = ensureGitignoreEntries(workingDirectory);
    if (gitignore != null) steps.add('  $gitignore');

    Directory(dir).createSync(recursive: true);

    final resolution = resolver.resolve('requisition', lang: input.lang);
    final form = File(p.join(dir, 'requisition.md'));
    if (form.existsSync()) {
      steps.add('  kept     $relDir/requisition.md (already exists)');
    } else {
      form.writeAsStringSync(
        resolution.content.replaceAll('{{DATE}}', _iso(stamp)),
      );
      steps.add('  created  $relDir/requisition.md');
    }

    if (File(IssueMetadata.pathIn(dir)).existsSync()) {
      steps.add('  kept     $relDir/${IssueMetadata.fileName}');
    } else {
      IssueMetadata(title: input.slug, lang: input.lang).write(dir);
      steps.add('  created  $relDir/${IssueMetadata.fileName}');
    }

    writeActiveRequisition(
      workingDirectory,
      slug: input.slug,
      relDir: relDir,
      lang: input.lang,
      isoDate: _iso(stamp),
    );

    final lines = [
      'Requisition opened for "${input.slug}":',
      ...steps,
      if (resolution.notice != null) '  note     ${resolution.notice}',
      '',
      'Next: hand $relDir/requisition.md to the Product Owner, then '
          '`macss requisition check`.',
    ];
    return RequisitionNewOutput(message: lines.join('\n'), relDir: relDir);
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
