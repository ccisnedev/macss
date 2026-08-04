/// `macss specification new [--slug <slug>]` — adds the contract template to an
/// open requisition.
///
/// It creates **only** `specification.md`. The requisition is a separate
/// document with a separate author — a form the Product Owner fills — and
/// creating both at once, as this command used to, collapsed that distinction.
///
/// It therefore requires a requisition to exist: a contract with nothing to
/// contract about is not a document anyone can write.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/plan_apply.dart';
import '../../../templates/template_resolver.dart';
import '../../requisition/issue_metadata.dart';
import '../slug.dart';
import '../workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SpecificationNewInput extends Input {
  final String? slug;

  /// Overrides the language; by default the requisition's is inherited, so a
  /// Spanish request yields a Spanish contract.
  final String? lang;

  final ChangeFlags flags;

  SpecificationNewInput({this.slug, this.lang, required this.flags});

  factory SpecificationNewInput.fromCliRequest(CliRequest req) =>
      SpecificationNewInput(
        slug: optionalSlug(req.flagString('slug')),
        lang: req.flagString('lang'),
        flags: ChangeFlags.fromCliRequest(req),
      );

  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to add the contract to; defaults to the active one',
    ),
    CliParam.string(
      'lang',
      allowed: ['en', 'es'],
      description: "Language of the contract; inherits the requisition's when omitted",
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

class SpecificationNewOutput extends Output {
  final String message;
  final String? planPath;
  final bool blocked;

  SpecificationNewOutput({
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

class SpecificationNewCommand
    implements Command<SpecificationNewInput, SpecificationNewOutput> {
  @override
  final SpecificationNewInput input;

  final TemplateResolver resolver;
  final String workingDirectory;
  final DateTime Function() _now;
  final Approver? approver;

  SpecificationNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
    this.approver,
  }) : _now = now ?? DateTime.now;

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    if (_dir == null) {
      return 'No requisition found — run `macss requisition new <slug>` first, '
          'or point at one with --slug <slug>.';
    }
    return input.flags.validate();
  }

  @override
  Future<SpecificationNewOutput> execute() async {
    final dir = _dir!;
    final relDir = p.posix.joinAll(
      p.split(p.relative(dir, from: workingDirectory)),
    );
    final relPath = p.posix.join(relDir, 'specification.md');
    final file = File(p.join(dir, 'specification.md'));

    // Idempotence answers before the convention does: an existing contract is
    // kept either way, so there is nothing to plan or approve.
    if (file.existsSync()) {
      return SpecificationNewOutput(
        message: '  kept     $relPath (already exists)',
      );
    }

    final lang = input.lang ?? IssueMetadata.read(dir)?.lang ?? 'en';
    final resolution = resolver.resolve('specification', lang: lang);

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: _now,
    ).decide(
      command: 'specification new',
      workingDirectory: workingDirectory,
      body: [
        'would add the contract to "${p.basename(dir)}":',
        '',
        '  create   $relPath ($lang)',
        if (resolution.notice != null) '  note     ${resolution.notice}',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return SpecificationNewOutput(
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

    return SpecificationNewOutput(
      message: [
        'Contract scaffolded ($lang):',
        '  created  $relPath',
        if (resolution.notice != null) '  note     ${resolution.notice}',
        '',
        'Next: fill the committed date, the user stories with their acceptance '
            'criteria, and the explicit scope. Then `macss specification check`.',
      ].join('\n'),
    );
  }
}
