/// `macss verification new [--slug <slug>]` — opens the record before the walk.
///
/// **It reads the contract from the platform, not from disk.** A verifier may
/// hold no copy at all: `docs/requisitions/` is not versioned, so a local
/// `specification.md` can be absent, stale, or edited since the body froze.
/// What is authoritative is the frozen issue body, and that is what this reads.
///
/// It is the first scaffold in this CLI whose content depends on another
/// document. The skeleton comes from a template, in the project's language; the
/// criteria are generated from the contract, in the contract's order, with none
/// of them judged.
///
/// It takes no issue number: the record in the folder already carries one.
/// Materializing the folder itself on a machine that never had it is a
/// different problem, and it is not this one.
library;


import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/project_config.dart';
import '../../../src/steps.dart';
import '../../../src/vocabulary.dart';
import '../../../templates/template_resolver.dart';
import '../../requisition/publisher.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../contract_source.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class VerificationNewInput extends Input {
  final String? slug;

  VerificationNewInput({this.slug});

  factory VerificationNewInput.fromCliRequest(CliRequest req) =>
      VerificationNewInput(slug: optionalSlug(req.flagString('slug')));

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to open the record for; defaults to the '
            'active one'),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class VerificationNewOutput extends Output {
  VerificationNewOutput({
    required this.path,
    required this.kept,
    required this.lang,
    required this.criteria,
    this.issue,
    this.notice,
  });

  final String path;

  /// Whether a walk had already begun. Re-opening the record would throw away
  /// exactly what it exists to preserve: how far it got.
  final bool kept;

  final String lang;
  final List<String> criteria;
  final int? issue;
  final String? notice;

  @override
  Map<String, dynamic> toJson() => {
    'path': path,
    'kept': kept,
    'lang': lang,
    'criteria': criteria,
    if (issue != null) 'issue': issue,
    if (notice != null) 'notice': notice,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => kept
      ? '  kept     $path (a walk already begun)'
      : [
          'Record opened ($lang):',
          '  created  $path',
          '  listing  ${criteria.length} criteria from issue #$issue, '
              'none judged',
          if (notice != null) '  note     $notice',
          '',
          'One criterion at a time, and the human judges before the next.',
        ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class VerificationNewCommand
    implements Command<VerificationNewInput, VerificationNewOutput> {
  @override
  final VerificationNewInput input;

  final TemplateResolver resolver;
  final String workingDirectory;
  final ProcessRunner runProcess;
  final SpecificationGate gate;
  final DateTime Function() _now;

  VerificationNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    required this.runProcess,
    SpecificationGate? gate,
    DateTime Function()? now,
  })  : gate = gate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(resolver.assets)),
        _now = now ?? DateTime.now;

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run `macss requisition new <slug> --apply` '
          'first, or point at one with --slug <slug>.';
    }
    final record = RequisitionRecord.read(dir);
    if (record == null) {
      return 'No ${RequisitionRecord.fileName} in ${p.basename(dir)}.';
    }
    if (!record.isPublished) {
      return 'The requisition has not been published, so there is no frozen '
          'contract to verify against.';
    }
    final undeclared = undeclaredLanguageFailure(workingDirectory);
    if (undeclared != null) return undeclared;

    return null;
  }

  String get _lang => projectLanguage(workingDirectory)!;

  String get _relPath => p.posix.join(
    p.posix.joinAll(p.split(p.relative(_dir!, from: workingDirectory))),
    'verification.md',
  );

  List<String> _criteria = const [];
  int? _issue;
  String? _notice;

  /// One step: the record.
  ///
  /// The criteria come from the platform — the frozen contract on the issue,
  /// not the working copy on disk — so the read happens here, before the plan
  /// is built, and what it returned travels inside the step. Asking again at
  /// perform time could answer differently, and the record would then not be
  /// the one that was approved.
  ///
  /// The read happens even when a record already exists and the step will only
  /// keep it. That is a wasted call on the idempotent path, and it is the price
  /// of the step carrying real contents: contents that were never fetched would
  /// write an empty record if the file vanished between preview and perform.
  @override
  Future<List<Step>> steps() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;
    _issue = record.issue;

    final contract = await criteriaFromPlatform(
      record,
      runProcess: runProcess,
      gate: gate,
    );
    if (!contract.ok) {
      throw CommandException(
        code: 'NO_FROZEN_CONTRACT',
        message: contract.failure!,
      );
    }
    _criteria = contract.ids;

    final resolution = resolver.resolve('verification', lang: _lang);
    _notice = resolution.notice;

    return [
      WriteFile(
        path: p.join(dir, 'verification.md'),
        contents: resolution.content
            .replaceAll('{{DATE}}', _now().toIso8601String().substring(0, 10))
            .replaceAll('{{CRITERIA}}', _entries(_criteria)),
        shownAs: _relPath,
      ),
    ];
  }

  @override
  VerificationNewOutput describe(Execution execution) => VerificationNewOutput(
    path: _relPath,
    kept: execution.outcomes.single.verb == 'keep',
    lang: _lang,
    criteria: _criteria,
    issue: _issue,
    notice: _notice,
  );

  /// One block per criterion, in the contract's order, none of them judged.
  ///
  /// The shape is the record's own: what is claimed, the evidence, why the
  /// evidence supports the claim, what it does not reach, and what the human
  /// judged. Written empty on purpose — a walk fills them one at a time, and a
  /// record that arrives pre-filled is a reconstruction.
  String _entries(List<String> criteria) => criteria
      .map((id) => [
            '### $id',
            '',
            '- **Claim:** <!-- what this criterion says holds -->',
            '- **Evidence:** <!-- what was run or read, and its result -->',
            '- **Warrant:** <!-- why that evidence supports the claim -->',
            '- **Not covered by this:** <!-- what the evidence does not reach -->',
            '- **Judged:** <!-- not yet judged -->',
          ].join('\n'))
      .join('\n\n');
}
