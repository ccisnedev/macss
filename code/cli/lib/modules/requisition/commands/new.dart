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
import '../../../templates/template_resolver.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../issue_metadata.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionNewInput extends Input {
  final String slug;
  final String lang;

  RequisitionNewInput({required this.slug, required this.lang});

  factory RequisitionNewInput.fromCliRequest(CliRequest req) =>
      RequisitionNewInput(
        slug: normalizeSlug(req.param('slug') ?? ''),
        lang: req.flagString('lang') ?? 'en',
      );

  static final List<CliParam> params = [
    CliParam.positional('slug', description: 'Short name for the requisition'),
    CliParam.string(
      'lang',
      allowed: ['en', 'es'],
      defaultValue: 'en',
      description: 'Language of the form handed to the Product Owner',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug, 'lang': lang};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionNewOutput extends Output {
  final String message;
  final String relDir;

  RequisitionNewOutput({required this.message, required this.relDir});

  @override
  Map<String, dynamic> toJson() => {'message': message, 'dir': relDir};

  @override
  int get exitCode => ExitCode.ok;

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

  RequisitionNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  String? validate() {
    if (input.slug.isEmpty) {
      return 'A <slug> is required: macss requisition new <slug>';
    }
    return null;
  }

  @override
  Future<RequisitionNewOutput> execute() async {
    final steps = <String>[];

    // The workspace is local and reproducible; keep it out of version control
    // before anything is written into it.
    final gitignore = ensureGitignoreEntries(workingDirectory);
    if (gitignore != null) steps.add('  $gitignore');

    final stamp = now();
    final folder = datedFolder(input.slug, stamp);
    final dir = requisitionDir(workingDirectory, folder);
    final relDir = requisitionRelDir(folder);
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
