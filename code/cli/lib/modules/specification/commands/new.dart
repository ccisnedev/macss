/// `macss specification new [--slug <slug>]` — adds the contract template to an
/// open requisition.
///
/// It creates **only** `specification.md`. The requisition is a separate
/// document with a separate author — the Product Owner's request, whoever
/// transcribed it — and creating both at once, as this command used to,
/// collapsed that distinction.
///
/// It therefore requires a requisition to exist: a contract with nothing to
/// contract about is not a document anyone can write.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/project_config.dart';
import '../../../src/steps.dart';
import '../../../templates/template_resolver.dart';
import '../slug.dart';
import '../workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SpecificationNewInput extends Input {
  final String? slug;

  SpecificationNewInput({this.slug});

  factory SpecificationNewInput.fromCliRequest(CliRequest req) =>
      SpecificationNewInput(slug: optionalSlug(req.flagString('slug')));

  /// No `--lang`. It used to inherit the requisition's, which was the right
  /// instinct applied one hop at a time; the project now declares it once and
  /// every document derives from that.
  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to add the contract to; defaults to the active one',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SpecificationNewOutput extends Output {
  SpecificationNewOutput({
    required this.path,
    required this.kept,
    required this.lang,
    this.notice,
  });

  /// Where the contract is, relative to the project.
  final String path;

  /// Whether one was already there. `new` is idempotent, so this is the
  /// ordinary second-run answer rather than a failure.
  final bool kept;

  final String lang;
  final String? notice;

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
          'Contract scaffolded ($lang):',
          '  created  $path',
          if (notice != null) '  note     $notice',
          '',
          'Next: fill the committed date, the user stories with their '
              'acceptance criteria, and the explicit scope. Then '
              '`macss specification check`.',
        ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class SpecificationNewCommand
    implements Command<SpecificationNewInput, SpecificationNewOutput> {
  @override
  final SpecificationNewInput input;

  final TemplateResolver resolver;
  final String workingDirectory;
  final DateTime Function() _now;

  SpecificationNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    if (_dir == null) {
      return 'No requisition found — run `macss requisition new <slug> --apply` '
          'first, '
          'or point at one with --slug <slug>.';
    }
    final undeclared = undeclaredLanguageFailure(workingDirectory);
    if (undeclared != null) return undeclared;

    return null;
  }

  String get _lang => projectLanguage(workingDirectory)!;

  String get _relPath => p.posix.join(
    p.posix.joinAll(p.split(p.relative(_dir!, from: workingDirectory))),
    'specification.md',
  );

  TemplateResolution? _resolution;

  /// One step: the contract.
  ///
  /// Idempotence used to be answered here, ahead of the convention — an
  /// existing contract was reported kept before any plan was built. It is
  /// answered by the step now, which is better: `--plan` on a requisition that
  /// already has one says `keep` instead of the command quietly deciding there
  /// was nothing to show.
  @override
  Future<List<Step>> steps() async {
    _resolution = resolver.resolve('specification', lang: _lang);
    return [
      WriteFile(
        path: p.join(_dir!, 'specification.md'),
        contents: _resolution!.content.replaceAll(
          '{{DATE}}',
          _now().toIso8601String().substring(0, 10),
        ),
        shownAs: _relPath,
      ),
    ];
  }

  @override
  SpecificationNewOutput describe(Execution execution) =>
      SpecificationNewOutput(
        path: _relPath,
        kept: execution.outcomes.single.verb == 'keep',
        lang: _lang,
        notice: _resolution?.notice,
      );
}
