/// `macss specification check [--slug <slug>]` — runs the `specification_ready`
/// gate over the active requisition's `specification.md`
/// (`.macss/active_requisition.yaml`; `--slug` overrides).
///
/// The CLI runs the gate; the model fixes exactly what it reports. Specification
/// precedes implementation, whose gates belong to the inquiry FSM, so this is a
/// standalone check rather than a state transition — but it plays the same role:
/// the artifact does not leave the specification stage until it exits 0.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/vocabulary.dart';
import '../slug.dart';
import '../specification_gate.dart';
import '../workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SpecificationCheckInput extends Input {
  /// The requisition workspace override; `null` → the active requisition
  /// recorded in `.macss/active_requisition.yaml`.
  final String? slug;

  SpecificationCheckInput({this.slug});

  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to check; defaults to the active one',
    ),
  ];

  factory SpecificationCheckInput.fromCliRequest(CliRequest req) =>
      SpecificationCheckInput(slug: optionalSlug(req.flagString('slug')));

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SpecificationCheckOutput extends Output {
  final String message;
  final bool ready;

  SpecificationCheckOutput({required this.message, required this.ready});

  @override
  Map<String, dynamic> toJson() => {'ready': ready, 'message': message};

  @override
  int get exitCode => ready ? ExitCode.ok : ExitCode.validationFailed;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class SpecificationCheckCommand
    implements Query<SpecificationCheckInput, SpecificationCheckOutput> {
  @override
  final SpecificationCheckInput input;

  final String workingDirectory;
  final SpecificationGate gate;

  SpecificationCheckCommand(
    this.input, {
    required this.workingDirectory,
    required Assets assets,
    SpecificationGate? gate,
  }) : gate = gate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets));

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  File? get _specFile {
    final d = _dir;
    return d == null ? null : File(p.join(d, 'specification.md'));
  }

  /// Display name for messages: the explicit slug, else the resolved folder.
  String get _name {
    final d = _dir;
    return input.slug ?? (d != null ? p.basename(d) : 'active requisition');
  }

  @override
  String? validate() {
    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;

    final spec = _specFile;
    if (spec == null || !spec.existsSync()) {
      return 'No specification found — run '
          '`macss specification new --slug <slug> --apply` first, '
          'or point at one with --slug <slug>.';
    }
    return null;
  }

  @override
  Future<SpecificationCheckOutput> execute() async {
    final result = gate.evaluate(_specFile!.readAsStringSync());

    if (result.passed) {
      return SpecificationCheckOutput(
        ready: true,
        message: 'specification "$_name" is ready — '
            'every rule of the specification_ready gate passes.',
      );
    }

    final lines = <String>[
      'specification "$_name" is NOT ready — fix these and re-run:',
      for (final v in result.violations) '  - ${v.code}: ${v.message}',
    ];
    return SpecificationCheckOutput(ready: false, message: lines.join('\n'));
  }

}
