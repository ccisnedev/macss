/// `macss delivery new [--slug <slug>]` — opens the delivery beside the work.
///
/// `delivery.md` is the mirror of `requisition.md`: the first document of each
/// pair **reports**, the second **commits** (ADR 0008 §1). The request states
/// what was asked and nobody signs it; the delivery states what was built and
/// nobody signs that either. The signature goes on the verification.
///
/// It carries only what a verifier cannot derive from the frozen contract and
/// the diff: which criterion is claimed where, what was deliberately not done,
/// and how to reproduce it. What was built is in the code, and why it was built
/// that way is in `adr/` or nowhere.
///
/// The pull request's title is **not** here — it is `pr_title` in `state.yaml`,
/// the way `requisition.md` has never carried its own.
library;


import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/project_config.dart';
import '../../../src/steps.dart';
import '../../../templates/template_resolver.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class DeliveryNewInput extends Input {
  final String? slug;

  DeliveryNewInput({this.slug});

  factory DeliveryNewInput.fromCliRequest(CliRequest req) =>
      DeliveryNewInput(slug: optionalSlug(req.flagString('slug')));

  /// No `--lang`: the project declared its language once, and every document
  /// derives from it — including this one, which follows the project and not
  /// the stage.
  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to open the delivery for; defaults to the active one',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class DeliveryNewOutput extends Output {
  DeliveryNewOutput({
    required this.path,
    required this.kept,
    required this.lang,
    this.notice,
  });

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
          'Delivery scaffolded ($lang):',
          '  created  $path',
          if (notice != null) '  note     $notice',
          '',
          'Next: claim every acceptance criterion with somewhere to look, say '
              'what was not done, and record `pr_title` in state.yaml. Then '
              '`macss delivery check`.',
        ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class DeliveryNewCommand
    implements Command<DeliveryNewInput, DeliveryNewOutput> {
  @override
  final DeliveryNewInput input;

  final TemplateResolver resolver;
  final String workingDirectory;
  final DateTime Function() _now;

  DeliveryNewCommand(
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
    'delivery.md',
  );

  TemplateResolution? _resolution;

  /// One step: the delivery.
  ///
  /// Idempotence used to be answered ahead of the convention, so `--plan` on a
  /// requisition that already had a delivery said nothing at all. The step
  /// answers now, and says `keep`.
  @override
  Future<List<Step>> steps() async {
    _resolution = resolver.resolve('delivery', lang: _lang);
    return [
      WriteFile(
        path: p.join(_dir!, 'delivery.md'),
        contents: _resolution!.content.replaceAll(
          '{{DATE}}',
          _now().toIso8601String().substring(0, 10),
        ),
        shownAs: _relPath,
      ),
    ];
  }

  @override
  DeliveryNewOutput describe(Execution execution) => DeliveryNewOutput(
    path: _relPath,
    kept: execution.outcomes.single.verb == 'keep',
    lang: _lang,
    notice: _resolution?.notice,
  );
}
