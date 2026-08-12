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

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/project_config.dart';
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
  final ChangeFlags flags;

  VerificationNewInput({this.slug, required this.flags});

  factory VerificationNewInput.fromCliRequest(CliRequest req) =>
      VerificationNewInput(
        slug: optionalSlug(req.flagString('slug')),
        flags: ChangeFlags.fromCliRequest(req),
      );

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to open the record for; defaults to the '
            'active one'),
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

class VerificationNewOutput extends Output {
  final String message;
  final bool ok;
  final String? planPath;
  final List<String> criteria;

  VerificationNewOutput({
    required this.message,
    this.ok = true,
    this.planPath,
    this.criteria = const [],
  });

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'ok': ok, 'planPath': planPath, 'criteria': criteria};

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
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
  final Approver? approver;

  VerificationNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    required this.runProcess,
    SpecificationGate? gate,
    DateTime Function()? now,
    this.approver,
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

    return input.flags.validate();
  }

  @override
  Future<VerificationNewOutput> execute() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;
    final relDir =
        p.posix.joinAll(p.split(p.relative(dir, from: workingDirectory)));
    final relPath = p.posix.join(relDir, 'verification.md');
    final file = File(p.join(dir, 'verification.md'));

    // Idempotence answers before the convention does. A record already open is
    // a walk already begun, and re-opening it would throw away exactly what it
    // exists to preserve: how far it got.
    if (file.existsSync()) {
      return VerificationNewOutput(
        message: '  kept     $relPath (a walk already begun)',
      );
    }

    final contract = await criteriaFromPlatform(
      record,
      runProcess: runProcess,
      gate: gate,
    );
    if (!contract.ok) {
      return VerificationNewOutput(ok: false, message: contract.failure!);
    }
    final criteria = contract.ids;

    final lang = projectLanguage(workingDirectory)!;
    final resolution = resolver.resolve('verification', lang: lang);

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: _now,
    ).decide(
      command: 'verification new',
      workingDirectory: workingDirectory,
      body: [
        'would open the record for "${p.basename(dir)}":',
        '',
        '  create   $relPath ($lang)',
        '  from     issue #${record.issue}, the frozen contract',
        '  listing  ${criteria.length} criteria, none judged: '
            '${criteria.join(', ')}',
        if (resolution.notice != null) '  note     ${resolution.notice}',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return VerificationNewOutput(
        message: decision.message!,
        ok: !decision.blocked,
        planPath: decision.planPath,
      );
    }

    file.writeAsStringSync(
      resolution.content
          .replaceAll('{{DATE}}', _now().toIso8601String().substring(0, 10))
          .replaceAll('{{CRITERIA}}', _entries(criteria)),
    );

    return VerificationNewOutput(
      criteria: criteria,
      message: [
        'Record opened ($lang):',
        '  created  $relPath',
        '  listing  ${criteria.length} criteria from issue #${record.issue}, '
            'none judged',
        '',
        'One criterion at a time, and the human judges before the next.',
      ].join('\n'),
    );
  }

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
