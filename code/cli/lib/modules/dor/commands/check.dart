/// `macss dor check [--slug <slug>]` — the Definition of Ready gate.
///
/// DoR produces no software. It verifies that what is written lets development
/// start without guessing, and it is the point where the requirement stops
/// being negotiable: from here the issue body is frozen.
///
/// It **composes** the stage checks rather than replacing them. Each module
/// judges its own document — is the form answered, is the contract well formed
/// — and DoR adds what neither owns: whether the requirement is *ready*, which
/// is a property of the whole rather than of either file.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/checks.dart';
import '../../../src/vocabulary.dart';
import '../../requisition/issue_metadata.dart';
import '../../requisition/requisition_gate.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class DorCheckInput extends Input {
  final String? slug;

  DorCheckInput({this.slug});

  factory DorCheckInput.fromCliRequest(CliRequest req) =>
      DorCheckInput(slug: optionalSlug(req.flagString('slug')));

  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to check; defaults to the active one',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class DorCheckOutput extends Output {
  final List<DoctorCheck> checks;
  final String name;

  DorCheckOutput({required this.checks, required this.name});

  bool get ready => !hasError(checks);

  @override
  Map<String, dynamic> toJson() => {
        'ready': ready,
        'requisition': name,
        'checks': checks.map((c) => c.toJson()).toList(),
      };

  @override
  int get exitCode => ready ? ExitCode.ok : ExitCode.validationFailed;

  @override
  String? toText() {
    final buffer = StringBuffer(renderChecks(checks));
    buffer.writeln();
    buffer.writeln(
      ready
          ? 'Definition of Ready met. From here the issue body is frozen: a '
              'change of scope opens a new requisition.'
          : 'Not ready. Fix what is marked above and re-run.',
    );
    return buffer.toString();
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class DorCheckCommand implements Command<DorCheckInput, DorCheckOutput> {
  @override
  final DorCheckInput input;

  final String workingDirectory;
  final RequisitionGate requisitionGate;
  final SpecificationGate specificationGate;

  DorCheckCommand(
    this.input, {
    required this.workingDirectory,
    required Assets assets,
    this.requisitionGate = const RequisitionGate(),
    SpecificationGate? specificationGate,
  }) : specificationGate = specificationGate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets));

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    if (_dir == null) {
      return 'No requisition found — run `macss requisition new <slug>` first, '
          'or point at one with --slug <slug>.';
    }
    return null;
  }

  @override
  Future<DorCheckOutput> execute() async {
    final dir = _dir!;

    return DorCheckOutput(
      name: p.basename(dir),
      checks: [
        _documentCheck(
          name: 'requisition',
          file: File(p.join(dir, 'requisition.md')),
          whenMissing: 'the form was never opened',
          violationsOf: (content) => requisitionGate
              .evaluate(content)
              .violations
              .map((v) => v.code)
              .toList(),
          remediation: 'macss requisition check',
        ),
        _documentCheck(
          name: 'specification',
          file: File(p.join(dir, 'specification.md')),
          whenMissing: 'no contract yet',
          violationsOf: (content) => specificationGate
              .evaluate(content)
              .violations
              .map((v) => v.code)
              .toList(),
          remediation: 'macss specification check',
        ),
        _issueCheck(dir),
      ],
    );
  }

  /// What neither module owns: the requirement has a home.
  ///
  /// Until the issue exists there is nothing for development to pick up,
  /// nothing to reference from a branch, and nothing to freeze.
  DoctorCheck _issueCheck(String dir) {
    final meta = IssueMetadata.read(dir);
    final published = meta != null && meta.isPublished;

    return DoctorCheck(
      name: 'issue',
      status: published ? CheckStatus.ok : CheckStatus.error,
      detail: published ? 'published as #${meta.issue}' : 'not published',
      remediation:
          published ? null : 'Run: macss requisition publish --apply',
    );
  }

  DoctorCheck _documentCheck({
    required String name,
    required File file,
    required String whenMissing,
    required List<String> Function(String) violationsOf,
    required String remediation,
  }) {
    if (!file.existsSync()) {
      return DoctorCheck(
        name: name,
        status: CheckStatus.error,
        detail: whenMissing,
        remediation: 'Run: $remediation',
      );
    }

    final codes = violationsOf(file.readAsStringSync());
    if (codes.isEmpty) {
      return DoctorCheck(
        name: name,
        status: CheckStatus.ok,
        detail: 'complete',
      );
    }

    // The codes, not the prose: the stage check prints the full message, and
    // repeating it here would bury the one thing DoR is for — whether the
    // requirement as a whole can start.
    return DoctorCheck(
      name: name,
      status: CheckStatus.error,
      detail: 'unmet: ${codes.join(', ')}',
      remediation: 'Run: $remediation',
    );
  }
}
