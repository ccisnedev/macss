/// `macss specification publish [--apply]` — adds the contract to the issue.
///
/// The issue already exists: `requisition publish` created it carrying the
/// request. This updates it so the body reads request first, contract second —
/// how a need became agreed work, top to bottom.
///
/// It requires both: an issue to update, and a contract worth publishing.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/vocabulary.dart';
import '../../requisition/issue_metadata.dart';
import '../../requisition/publisher.dart';
import '../slug.dart';
import '../specification_gate.dart';
import '../workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SpecificationPublishInput extends Input {
  final String? slug;
  final bool apply;
  final String? repo;

  SpecificationPublishInput({this.slug, this.apply = false, this.repo});

  factory SpecificationPublishInput.fromCliRequest(CliRequest req) =>
      SpecificationPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        apply: req.flagBool('apply'),
        repo: req.flagString('repo'),
      );

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to publish; defaults to the active one'),
    CliParam.boolean('apply',
        description: 'Update the issue; without it, only previews'),
    CliParam.string('repo',
        description:
            'Target repository; by default gh infers it from this directory'),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug, 'apply': apply, 'repo': repo};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SpecificationPublishOutput extends Output {
  final String message;
  final bool ok;

  SpecificationPublishOutput({required this.message, this.ok = true});

  @override
  Map<String, dynamic> toJson() => {'ok': ok, 'message': message};

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class SpecificationPublishCommand
    implements
        Command<SpecificationPublishInput, SpecificationPublishOutput> {
  @override
  final SpecificationPublishInput input;

  final String workingDirectory;
  final IssuePublisher publisher;
  final SpecificationGate gate;

  SpecificationPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    required Assets assets,
    SpecificationGate? gate,
  })  : publisher = IssuePublisher(runProcess: runProcess),
        gate = gate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets));

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run `macss requisition new <slug>` first.';
    }
    if (!File(p.join(dir, 'specification.md')).existsSync()) {
      return 'No specification.md — run `macss specification new` first.';
    }
    final meta = IssueMetadata.read(dir);
    if (meta == null || !meta.isPublished) {
      return 'The requisition has not been published yet — run '
          '`macss requisition publish --apply` first, so there is an issue to '
          'add the contract to.';
    }
    return null;
  }

  @override
  Future<SpecificationPublishOutput> execute() async {
    final dir = _dir!;
    final meta = IssueMetadata.read(dir)!;

    final result = gate.evaluate(
      File(p.join(dir, 'specification.md')).readAsStringSync(),
    );
    if (!result.passed) {
      return SpecificationPublishOutput(
        ok: false,
        message: [
          'The contract is not ready, so there is nothing worth publishing yet:',
          ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
        ].join('\n'),
      );
    }

    final body = assembleBody(dir);
    if (body.exceedsLimit) {
      return SpecificationPublishOutput(
        ok: false,
        message: 'The assembled body is ${body.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}, or '
            'split the requisition into smaller ones.',
      );
    }

    if (!input.apply) {
      return SpecificationPublishOutput(
        message: [
          'Plan — would update issue ${meta.issue}',
          '  body:   ${body.lines} lines from ${body.parts.join(' + ')}',
          '',
          'Would run:',
          '  gh ${publisher.plannedArgs(meta, repo: input.repo).join(' ')} '
              '--body-file <body>',
          '',
          'Re-run with --apply to update it.',
        ].join('\n'),
      );
    }

    final published = await publisher.publish(meta, body, repo: input.repo);
    return published.ok
        ? SpecificationPublishOutput(
            message: 'Issue ${meta.issue} updated: ${published.url}')
        : SpecificationPublishOutput(ok: false, message: published.error!);
  }
}
