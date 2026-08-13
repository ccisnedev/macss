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


import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/project_config.dart';
import '../../../src/steps.dart';
import '../../../templates/template_resolver.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../requisition_record.dart';
import '../steps.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionNewInput extends Input {
  final String slug;

  RequisitionNewInput({required this.slug});

  factory RequisitionNewInput.fromCliRequest(CliRequest req) =>
      RequisitionNewInput(slug: normalizeSlug(req.param('slug') ?? ''));

  /// No `--lang`. The project declared its language once, in
  /// `.macss/config.yaml`, and this derives it from there: a setting passed per
  /// invocation is one that can differ per invocation, and a project that
  /// answers differently on Tuesday does not have an answer.
  static final List<CliParam> params = [
    CliParam.positional('slug', description: 'Short name for the requisition'),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionNewOutput extends Output {
  RequisitionNewOutput({
    required this.slug,
    required this.relDir,
    required this.did,
    this.notice,
  });

  final String slug;
  final String relDir;

  /// One `verb  target` line per step that ran, in order.
  final List<({String verb, String target})> did;

  /// What the template resolver had to say — a fallback language, usually.
  final String? notice;

  @override
  Map<String, dynamic> toJson() => {
    'slug': slug,
    'dir': relDir,
    'did': {for (final step in did) step.target: step.verb},
    if (notice != null) 'notice': notice,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    'Requisition opened for "$slug":',
    ...did.map((s) => '  ${s.verb.padRight(8)} ${s.target}'),
    if (notice != null) '  note     $notice',
    '',
    'Next: fill $relDir/requisition.md with what the Product Owner sent, '
        'then `macss requisition check`.',
  ].join('\n');
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
      return 'A <slug> is required: macss requisition new <slug> --apply';
    }
    // The form is a localized template, so the project must have said which
    // language it speaks. There is no default to fall back on.
    final undeclared = undeclaredLanguageFailure(workingDirectory);
    if (undeclared != null) return undeclared;

    return null;
  }

  /// The project's language, declared once. Safe once validation has passed.
  String get lang => projectLanguage(workingDirectory)!;

  /// Four steps, in the order they must happen.
  ///
  /// The workspace is git-ignored **first**: it is local and reproducible, and
  /// a project should never have a committed `.macss/`, not even for the
  /// duration of one command.
  ///
  /// `new` is idempotent, so the two writes keep what is already there rather
  /// than overwriting it — which each step decides for itself, once. The
  /// `existsSync()` that used to be asked in the preview and asked again forty
  /// lines later is now asked inside the step that acts on the answer.
  @override
  Future<List<Step>> steps() async {
    final stamp = now();
    final folder = datedFolder(input.slug, stamp);
    final dir = requisitionDir(workingDirectory, folder);
    final relDir = requisitionRelDir(folder);

    // Resolved here, so the form that is described is the form that is written.
    _resolution = resolver.resolve('requisition', lang: lang);

    return [
      EnsureWorkspaceGitignored(workingDirectory),
      WriteFile(
        path: p.join(dir, 'requisition.md'),
        contents: _resolution!.content.replaceAll('{{DATE}}', _iso(stamp)),
        shownAs: '$relDir/requisition.md',
      ),
      WriteFile(
        path: RequisitionRecord.pathIn(dir),
        contents: RequisitionRecord(
          title: input.slug,
          state: RequisitionState.opened,
        ).toYaml(),
        shownAs: '$relDir/${RequisitionRecord.fileName}',
      ),
      RecordActiveRequisition(
        workingDirectory: workingDirectory,
        slug: input.slug,
        relDir: relDir,
        isoDate: _iso(stamp),
      ),
    ];
  }

  /// Kept from [steps] so [describe] can report the resolver's notice. Not read
  /// by any step: what the steps needed, they were given.
  TemplateResolution? _resolution;

  @override
  RequisitionNewOutput describe(Execution execution) => RequisitionNewOutput(
    slug: input.slug,
    relDir: requisitionRelDir(datedFolder(input.slug, now())),
    did: [
      for (final o in execution.outcomes) (verb: o.verb, target: o.target),
    ],
    notice: _resolution?.notice,
  );

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
