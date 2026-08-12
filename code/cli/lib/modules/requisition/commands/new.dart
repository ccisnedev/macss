/// `macss requisition new <slug> --plan|--apply` — opens a requisition.
///
/// It takes no `--lang`: the project declared its language once, and this
/// derives it. A project that has not declared one is stopped rather than
/// assumed to be English.
///
/// Writes the form carrying the Product Owner's request, the issue metadata
/// beside it, and records the requisition as the active one so later commands
/// need no slug.
///
/// The analyst usually holds the pen: the request arrives by email or in a
/// meeting, and is transcribed into the form. The Product Owner remains its
/// author — what the form may contain is what he said, and nothing inferred.
///
/// The specification is **not** created here: it belongs to a later stage, with
/// a different author. `macss specification new` adds it once the request is in.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/gitignore.dart';
import '../../../src/project_config.dart';
import '../../../templates/template_resolver.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../requisition_record.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionNewInput extends Input {
  final String slug;
  final ChangeFlags flags;

  RequisitionNewInput({required this.slug, required this.flags});

  factory RequisitionNewInput.fromCliRequest(CliRequest req) =>
      RequisitionNewInput(
        slug: normalizeSlug(req.param('slug') ?? ''),
        flags: ChangeFlags.fromCliRequest(req),
      );

  /// No `--lang`. The project declared its language once, in
  /// `.macss/config.yaml`, and this derives it from there: a setting passed per
  /// invocation is one that can differ per invocation, and a project that
  /// answers differently on Tuesday does not have an answer.
  static final List<CliParam> params = [
    CliParam.positional('slug', description: 'Short name for the requisition'),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'slug': slug,
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
      return 'A <slug> is required: macss requisition new <slug> --apply';
    }
    // The form is a localized template, so the project must have said which
    // language it speaks. There is no default to fall back on.
    final undeclared = undeclaredLanguageFailure(workingDirectory);
    if (undeclared != null) return undeclared;

    return input.flags.validate();
  }

  /// The project's language, declared once. Safe once validation has passed.
  String get lang => projectLanguage(workingDirectory)!;

  @override
  Future<RequisitionNewOutput> execute() async {
    final stamp = now();
    final folder = datedFolder(input.slug, stamp);
    final dir = requisitionDir(workingDirectory, folder);
    final relDir = requisitionRelDir(folder);

    // What opening a requisition would touch, decided before it touches
    // anything. `new` is idempotent, so an existing file is named as kept.
    final formExists = File(p.join(dir, 'requisition.md')).existsSync();
    final metaExists = File(RequisitionRecord.pathIn(dir)).existsSync();
    final body = [
      'would open the requisition "${input.slug}" at $relDir:',
      '',
      formExists
          ? '  keep     $relDir/requisition.md (already exists)'
          : '  create   $relDir/requisition.md',
      metaExists
          ? '  keep     $relDir/${RequisitionRecord.fileName}'
          : '  create   $relDir/${RequisitionRecord.fileName}',
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

    final resolution = resolver.resolve('requisition', lang: lang);
    final form = File(p.join(dir, 'requisition.md'));
    if (form.existsSync()) {
      steps.add('  kept     $relDir/requisition.md (already exists)');
    } else {
      form.writeAsStringSync(
        resolution.content.replaceAll('{{DATE}}', _iso(stamp)),
      );
      steps.add('  created  $relDir/requisition.md');
    }

    if (File(RequisitionRecord.pathIn(dir)).existsSync()) {
      steps.add('  kept     $relDir/${RequisitionRecord.fileName}');
    } else {
      RequisitionRecord(title: input.slug, state: RequisitionState.opened)
          .write(dir);
      steps.add('  created  $relDir/${RequisitionRecord.fileName}');
    }

    writeActiveRequisition(
      workingDirectory,
      slug: input.slug,
      relDir: relDir,
      isoDate: _iso(stamp),
    );

    final lines = [
      'Requisition opened for "${input.slug}":',
      ...steps,
      if (resolution.notice != null) '  note     ${resolution.notice}',
      '',
      'Next: fill $relDir/requisition.md with what the Product Owner sent, '
          'then `macss requisition check`.',
    ];
    return RequisitionNewOutput(message: lines.join('\n'), relDir: relDir);
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
