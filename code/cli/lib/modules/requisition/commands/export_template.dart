/// `macss requisition export-template [--path <dir>] [--lang <lang>]` — writes
/// the blank form.
///
/// The requisition template is handed to the Product Owner once, usually
/// rendered to PDF or DOCX. Producing it by scaffolding a throwaway requisition
/// would litter `docs/requisitions/` and move the active pointer, so it gets its
/// own command.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/plan_apply.dart';
import '../../../templates/template_resolver.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ExportTemplateInput extends Input {
  final String resolvedPath;
  final String lang;
  final ChangeFlags flags;

  ExportTemplateInput({
    required this.resolvedPath,
    required this.lang,
    required this.flags,
  });

  factory ExportTemplateInput.fromCliRequest(CliRequest req) {
    final raw = req.flagString('path', aliases: const ['p']);
    final cwd = Directory.current.path;
    return ExportTemplateInput(
      resolvedPath:
          raw == null ? cwd : (p.isAbsolute(raw) ? raw : p.join(cwd, raw)),
      lang: req.flagString('lang') ?? 'en',
      flags: ChangeFlags.fromCliRequest(req),
    );
  }

  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Directory to write the template into; defaults to the current one',
    ),
    CliParam.string(
      'lang',
      allowed: ['en', 'es'],
      defaultValue: 'en',
      description: 'Language of the template',
    ),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'resolvedPath': resolvedPath,
        'lang': lang,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ExportTemplateOutput extends Output {
  final String message;
  final String path;
  final String? planPath;
  final int _exitCode;

  ExportTemplateOutput({
    required this.message,
    required this.path,
    this.planPath,
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'path': path, 'planPath': planPath};

  @override
  int get exitCode => _exitCode;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class ExportTemplateCommand
    implements Command<ExportTemplateInput, ExportTemplateOutput> {
  @override
  final ExportTemplateInput input;

  final TemplateResolver resolver;

  /// Which artifact this exports — `requisition` or `specification`.
  final String artifact;

  final Approver? approver;
  final DateTime Function()? now;

  ExportTemplateCommand(
    this.input, {
    required this.resolver,
    required this.artifact,
    this.approver,
    this.now,
  });

  @override
  String? validate() {
    if (File(input.resolvedPath).existsSync()) {
      return '"${input.resolvedPath}" is a file, not a directory.';
    }
    return input.flags.validate();
  }

  @override
  Future<ExportTemplateOutput> execute() async {
    final resolution = resolver.resolve(artifact, lang: input.lang);
    final target = File(p.join(input.resolvedPath, '$artifact.md'));

    // The refusal to overwrite comes first: there is no change to plan or
    // approve when the answer is that nothing will be written either way.
    if (target.existsSync()) {
      return ExportTemplateOutput(
        message: '${target.path} already exists — not overwritten.',
        path: target.path,
        exitCode: ExitCode.conflict,
      );
    }

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: '$artifact export-template',
      workingDirectory: input.resolvedPath,
      body: [
        'would write the blank $artifact form:',
        '',
        '  create   ${target.path} (${input.lang})',
        if (resolution.notice != null) '  note     ${resolution.notice}',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return ExportTemplateOutput(
        message: decision.message!,
        path: target.path,
        planPath: decision.planPath,
        exitCode: decision.blocked ? ExitCode.genericError : ExitCode.ok,
      );
    }

    target.parent.createSync(recursive: true);
    target.writeAsStringSync(resolution.content);

    final lines = [
      'exported  ${p.basename(target.path)} (${input.lang})',
      if (resolution.notice != null) 'note      ${resolution.notice}',
    ];
    return ExportTemplateOutput(message: lines.join('\n'), path: target.path);
  }
}
