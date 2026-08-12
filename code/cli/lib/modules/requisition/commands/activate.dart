/// `macss requisition activate <slug> --plan|--apply` — choose the requisition
/// the following commands act on.
///
/// The pointer lives in `.macss/active_requisition.yaml` and was, until now, changed by
/// opening that file and editing two keys that had to stay consistent with each
/// other and with a folder name. Nothing checked that they agreed, which made it
/// the only unguarded operation in a CLI that will not even choose between
/// `--plan` and `--apply` for you.
///
/// The name comes from the vocabulary already in the code and the docs: the
/// pointer records the **active** requisition. `set` would not say what is being
/// set, and git's `checkout` carries a meaning that does not apply here.
///
/// It writes, so it takes the convention (ADR 0007). A command exempt from it
/// would be the first crack in it.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../specification/slug.dart';
import '../../specification/workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionActivateInput extends Input {
  /// Which requisition to make active. Required: there is nothing in the
  /// context to derive it from, and deriving it would be choosing for the
  /// caller (ADR 0009).
  final String? slug;

  final ChangeFlags flags;

  RequisitionActivateInput({this.slug, this.flags = const ChangeFlags()});

  factory RequisitionActivateInput.fromCliRequest(CliRequest req) =>
      RequisitionActivateInput(
        slug: optionalSlug(req.param('slug')),
        flags: ChangeFlags.fromCliRequest(req),
      );

  static final List<CliParam> params = [
    CliParam.positional('slug',
        description: 'The requisition to make active, as `list` shows it'),
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

class RequisitionActivateOutput extends Output {
  final String message;
  final String? planPath;
  final bool blocked;

  RequisitionActivateOutput({
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

class RequisitionActivateCommand
    implements Command<RequisitionActivateInput, RequisitionActivateOutput> {
  @override
  final RequisitionActivateInput input;

  final String workingDirectory;
  final Approver? approver;
  final DateTime Function() now;

  RequisitionActivateCommand(
    this.input, {
    required this.workingDirectory,
    this.approver,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    if (input.slug == null || input.slug!.isEmpty) {
      return 'Which requisition? '
          'Usage: macss requisition activate <slug> --apply\n'
          'Run `macss requisition list` to see them.';
    }

    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;

    if (_dir == null) {
      final existing = _allSlugs();
      return [
        'No requisition named "${input.slug}".',
        if (existing.isEmpty)
          'This project has none yet — open one with '
              '`macss requisition new <slug> --apply`.'
        else ...[
          'These exist:',
          ...existing.map((s) => '  $s'),
        ],
      ].join('\n');
    }

    return input.flags.validate();
  }

  @override
  Future<RequisitionActivateOutput> execute() async {
    final dir = _dir!;
    final folder = p.basename(dir);
    final relDir = requisitionRelDir(folder);

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'requisition activate',
      workingDirectory: workingDirectory,
      body: [
        'would make "${input.slug}" the active requisition:',
        '',
        '  activate  $relDir',
        '',
        'Commands that take no --slug act on the active requisition.',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return RequisitionActivateOutput(
        message: decision.message!,
        planPath: decision.planPath,
        blocked: decision.blocked,
      );
    }

    // The same writer `requisition new` uses, so the pointer keeps its keys and
    // its format.
    writeActiveRequisition(
      workingDirectory,
      slug: input.slug!,
      relDir: relDir,
      isoDate: _iso(now()),
    );

    return RequisitionActivateOutput(
      message: 'Active requisition: ${input.slug} ($relDir)',
    );
  }

  List<String> _allSlugs() {
    final base = Directory(p.join(workingDirectory, 'docs', 'requisitions'));
    if (!base.existsSync()) return const [];
    return base
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .map((f) => RegExp(r'^\d{8}-(.+)$').firstMatch(f)?.group(1) ?? f)
        .toSet()
        .toList()
      ..sort();
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
