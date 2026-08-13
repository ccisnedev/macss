/// Adding one localized document to an open requisition.
///
/// `specification new` and `delivery new` were the same command twice: same
/// input, same validation, same step, same idempotence, same shape of answer.
/// What differed between them was four strings — which artifact, which file,
/// what to call it in the report, and what to do next.
///
/// **`verification new` is deliberately not here.** It shares the shape and
/// then does more: it reads the frozen contract from the platform before the
/// plan is built, refuses a requisition that has no published issue, and its
/// answer carries the criteria it listed. Folding it in would mean hooks for a
/// third case that has no second — the abstraction would be describing the
/// exception rather than the rule.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../modules/specification/slug.dart';
import '../modules/specification/workspace.dart';
import '../templates/template_resolver.dart';
import 'project_config.dart';
import 'steps.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ScaffoldDocumentInput extends Input {
  ScaffoldDocumentInput({this.slug});

  final String? slug;

  factory ScaffoldDocumentInput.fromCliRequest(CliRequest req) =>
      ScaffoldDocumentInput(slug: optionalSlug(req.flagString('slug')));

  /// No `--lang`: the project declared its language once, and every document
  /// derives from it. A setting passed per invocation is one that can differ
  /// per invocation, and a project that answers differently on Tuesday does not
  /// have an answer.
  static List<CliParam> paramsFor(String what) => [
    CliParam.string(
      'slug',
      description: 'Requisition to add the $what to; defaults to the active one',
    ),
  ];

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ScaffoldDocumentOutput extends Output {
  ScaffoldDocumentOutput({
    required this.path,
    required this.kept,
    required this.lang,
    required this.heading,
    required this.next,
    this.notice,
  });

  /// Where the document is, relative to the project.
  final String path;

  /// Whether one was already there. `new` is idempotent, so this is the
  /// ordinary second-run answer rather than a failure.
  final bool kept;

  final String lang;
  final String? notice;

  /// What the report calls this document — `Contract`, `Delivery`.
  final String heading;

  /// What the author does next.
  final String next;

  @override
  Map<String, dynamic> toJson() => {
    'path': path,
    'kept': kept,
    'lang': lang,
    if (notice != null) 'notice': notice,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => kept
      ? '  kept     $path (already exists)'
      : [
          '$heading scaffolded ($lang):',
          '  created  $path',
          if (notice != null) '  note     $notice',
          '',
          next,
        ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class ScaffoldDocumentCommand
    implements Command<ScaffoldDocumentInput, ScaffoldDocumentOutput> {
  ScaffoldDocumentCommand(
    this.input, {
    required this.artifact,
    required this.heading,
    required this.next,
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  final ScaffoldDocumentInput input;

  /// Which template to resolve, and the stem of the file it writes:
  /// `specification` → `specification.md`.
  final String artifact;

  final String heading;
  final String next;
  final TemplateResolver resolver;
  final String workingDirectory;
  final DateTime Function() _now;

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    if (_dir == null) {
      return 'No requisition found — run `macss requisition new <slug> --apply` '
          'first, or point at one with --slug <slug>.';
    }
    final undeclared = undeclaredLanguageFailure(workingDirectory);
    if (undeclared != null) return undeclared;

    return null;
  }

  String get _lang => projectLanguage(workingDirectory)!;

  String get _relPath => p.posix.join(
    p.posix.joinAll(p.split(p.relative(_dir!, from: workingDirectory))),
    '$artifact.md',
  );

  TemplateResolution? _resolution;

  /// One step: the document.
  ///
  /// Idempotence is the step's answer, not the command's. Both of these used to
  /// short-circuit ahead of the convention, so `--plan` on a requisition that
  /// already had the document said nothing at all.
  @override
  Future<List<Step>> steps() async {
    _resolution = resolver.resolve(artifact, lang: _lang);
    return [
      WriteFile(
        path: p.join(_dir!, '$artifact.md'),
        contents: _resolution!.content.replaceAll(
          '{{DATE}}',
          _now().toIso8601String().substring(0, 10),
        ),
        shownAs: _relPath,
      ),
    ];
  }

  @override
  ScaffoldDocumentOutput describe(Execution execution) =>
      ScaffoldDocumentOutput(
        path: _relPath,
        kept: execution.outcomes.single.verb == 'keep',
        lang: _lang,
        heading: heading,
        next: next,
        notice: _resolution?.notice,
      );
}
