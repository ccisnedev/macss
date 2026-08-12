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

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/plan_apply.dart';
import '../../../src/project_config.dart';
import '../../../templates/template_resolver.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class DeliveryNewInput extends Input {
  final String? slug;
  final ChangeFlags flags;

  DeliveryNewInput({this.slug, required this.flags});

  factory DeliveryNewInput.fromCliRequest(CliRequest req) =>
      DeliveryNewInput(
        slug: optionalSlug(req.flagString('slug')),
        flags: ChangeFlags.fromCliRequest(req),
      );

  /// No `--lang`: the project declared its language once, and every document
  /// derives from it — including this one, which follows the project and not
  /// the stage.
  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to open the delivery for; defaults to the active one',
    ),
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

class DeliveryNewOutput extends Output {
  final String message;
  final String? planPath;
  final bool blocked;

  DeliveryNewOutput({
    required this.message,
    this.planPath,
    this.blocked = false,
  });

  @override
  Map<String, dynamic> toJson() => {'message': message, 'planPath': planPath};

  @override
  int get exitCode => blocked ? ExitCode.genericError : ExitCode.ok;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class DeliveryNewCommand
    implements Command<DeliveryNewInput, DeliveryNewOutput> {
  @override
  final DeliveryNewInput input;

  final TemplateResolver resolver;
  final String workingDirectory;
  final DateTime Function() _now;
  final Approver? approver;

  DeliveryNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
    this.approver,
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

    return input.flags.validate();
  }

  @override
  Future<DeliveryNewOutput> execute() async {
    final dir = _dir!;
    final relDir = p.posix.joinAll(
      p.split(p.relative(dir, from: workingDirectory)),
    );
    final relPath = p.posix.join(relDir, 'delivery.md');
    final file = File(p.join(dir, 'delivery.md'));

    // Idempotence answers before the convention does: an existing contract is
    // kept either way, so there is nothing to plan or approve.
    if (file.existsSync()) {
      return DeliveryNewOutput(
        message: '  kept     $relPath (already exists)',
      );
    }

    final lang = projectLanguage(workingDirectory)!;
    final resolution = resolver.resolve('delivery', lang: lang);

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: _now,
    ).decide(
      command: 'delivery new',
      workingDirectory: workingDirectory,
      body: [
        'would open the delivery for "${p.basename(dir)}":',
        '',
        '  create   $relPath ($lang)',
        if (resolution.notice != null) '  note     ${resolution.notice}',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return DeliveryNewOutput(
        message: decision.message!,
        planPath: decision.planPath,
        blocked: decision.blocked,
      );
    }

    file.writeAsStringSync(
      resolution.content.replaceAll(
        '{{DATE}}',
        _now().toIso8601String().substring(0, 10),
      ),
    );

    return DeliveryNewOutput(
      message: [
        'Delivery scaffolded ($lang):',
        '  created  $relPath',
        if (resolution.notice != null) '  note     ${resolution.notice}',
        '',
        'Next: claim every acceptance criterion with somewhere to look, say '
            'what was not done, and record `pr_title` in state.yaml. Then '
            '`macss delivery check`.',
      ].join('\n'),
    );
  }
}
