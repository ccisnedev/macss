/// `macss requisition publish [--apply] [--repo <owner/repo>]` — materializes
/// the requisition as an issue.
///
/// Creates the issue the first time and updates it afterwards, so the same
/// command serves both moments: the request is published as soon as the Product
/// Owner delivers it, and the body grows when the specification is written.
///
/// Previews by default. `--apply` is the deliberate act.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../issue_metadata.dart';
import '../publisher.dart';
import '../requisition_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionPublishInput extends Input {
  final String? slug;
  final bool apply;
  final String? repo;

  RequisitionPublishInput({this.slug, this.apply = false, this.repo});

  factory RequisitionPublishInput.fromCliRequest(CliRequest req) =>
      RequisitionPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        apply: req.flagBool('apply'),
        repo: req.flagString('repo'),
      );

  /// `--plan` is the default and so is not declared: passing `--apply` is what
  /// takes the action.
  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to publish; defaults to the active one',
    ),
    CliParam.boolean(
      'apply',
      description: 'Create or update the issue; without it, only previews',
    ),
    CliParam.string(
      'repo',
      description:
          'Target repository; by default gh infers it from this directory',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() =>
      {'slug': slug, 'apply': apply, 'repo': repo};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionPublishOutput extends Output {
  final String message;
  final bool ok;
  final int? issue;

  RequisitionPublishOutput({required this.message, this.ok = true, this.issue});

  @override
  Map<String, dynamic> toJson() =>
      {'ok': ok, 'message': message, if (issue != null) 'issue': issue};

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionPublishCommand
    implements Command<RequisitionPublishInput, RequisitionPublishOutput> {
  @override
  final RequisitionPublishInput input;

  final String workingDirectory;
  final IssuePublisher publisher;
  final RequisitionGate gate;

  RequisitionPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    this.gate = const RequisitionGate(),
  }) : publisher = IssuePublisher(runProcess: runProcess);

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run `macss requisition new <slug>` first, '
          'or point at one with --slug <slug>.';
    }
    if (IssueMetadata.read(dir) == null) {
      return 'No ${IssueMetadata.fileName} in ${p.basename(dir)}.';
    }
    return null;
  }

  @override
  Future<RequisitionPublishOutput> execute() async {
    final dir = _dir!;
    final meta = IssueMetadata.read(dir)!;

    // Publishing an unanswered form has no purpose. The methodology check comes
    // first; the platform limit is a separate concern, checked below.
    final form = File(p.join(dir, 'requisition.md'));
    if (form.existsSync()) {
      final result = gate.evaluate(form.readAsStringSync());
      if (!result.passed) {
        return RequisitionPublishOutput(
          ok: false,
          message: [
            'The requisition is not complete, so there is nothing worth '
                'publishing yet:',
            ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
          ].join('\n'),
        );
      }
    }

    final body = assembleBody(dir);
    if (body.exceedsLimit) {
      return RequisitionPublishOutput(
        ok: false,
        message: 'The assembled body is ${body.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}, or '
            'split the requisition into smaller ones.',
      );
    }

    final verb = meta.isPublished ? 'update' : 'create';
    if (!input.apply) {
      return RequisitionPublishOutput(
        message: [
          'Plan — would $verb the issue for "${p.basename(dir)}"',
          '  title:  ${meta.title}',
          '  labels: ${meta.labels.isEmpty ? '(none)' : meta.labels.join(', ')}',
          '  body:   ${body.lines} lines from ${body.parts.join(' + ')}',
          if (input.repo == null)
            '  repo:   inferred by gh from this directory',
          '',
          'Would run:',
          '  gh ${publisher.plannedArgs(meta, repo: input.repo).join(' ')} '
              '--body-file <body>',
          '',
          'Re-run with --apply to $verb it.',
        ].join('\n'),
      );
    }

    final result =
        await publisher.publish(meta, body, repo: input.repo);
    if (!result.ok) {
      return RequisitionPublishOutput(ok: false, message: result.error!);
    }

    if (result.number != null && !meta.isPublished) {
      meta.withIssue(result.number!).write(dir);
    }

    return RequisitionPublishOutput(
      issue: result.number,
      message: [
        'Issue ${meta.isPublished ? 'updated' : 'created'}: ${result.url}',
        if (!meta.isPublished && result.number != null)
          '  recorded issue: ${result.number} in ${IssueMetadata.fileName}',
      ].join('\n'),
    );
  }
}
