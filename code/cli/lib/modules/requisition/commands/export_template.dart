/// `macss requisition export-template [--path <dir>] [--lang <lang>]` — writes
/// the blank form.
///
/// A blank form, for the case where the Product Owner would rather fill one
/// directly than be transcribed — usually rendered to PDF or DOCX first.
/// Producing it by scaffolding a throwaway requisition would litter
/// `docs/requisitions/` and move the active pointer, so it gets its own command.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../templates/template_resolver.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ExportTemplateInput extends Input {
  final String resolvedPath;
  /// Required, and the only place --lang survives: this writes at a path
  /// that need not be a MACSS project, so there is no config to derive it from.
  final String? lang;

  ExportTemplateInput({required this.resolvedPath, required this.lang});

  factory ExportTemplateInput.fromCliRequest(CliRequest req) {
    final raw = req.flagString('path', aliases: const ['p']);
    final cwd = Directory.current.path;
    return ExportTemplateInput(
      resolvedPath:
          raw == null ? cwd : (p.isAbsolute(raw) ? raw : p.join(cwd, raw)),
      lang: req.flagString('lang'),
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
      required: true,
      allowed: ['en', 'es'],
      description:
          'Language of the template. This runs where no project need exist, '
          'so there is nothing to derive it from',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'resolvedPath': resolvedPath,
        'lang': lang,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

/// The form that was written, and nothing about the gate that let it be.
class ExportTemplateOutput extends Output {
  ExportTemplateOutput({required this.path, required this.lang, this.notice});

  /// Where the form was written.
  final String path;

  final String lang;

  /// What the resolver had to say — a fallback language, usually.
  final String? notice;

  @override
  Map<String, dynamic> toJson() => {
    'path': path,
    'lang': lang,
    if (notice != null) 'notice': notice,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    'exported  ${p.basename(path)} ($lang)',
    if (notice != null) 'note      $notice',
  ].join('\n');
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
    // The one command that keeps `--lang`, and the one that requires it: it
    // writes where no MACSS project need exist, so there is no configuration to
    // derive the language from. Not a weakening of the rule — the reason the
    // rule has an exception here. It is declared required, so absence is
    // refused before this method runs.
    return null;
  }

  /// One step: the form.
  ///
  /// The template is resolved **here**, when the step is built, and travels
  /// inside it. Resolving it again inside `perform` would be a second
  /// derivation free to disagree with the one the plan described.
  @override
  Future<List<Step>> steps() async {
    final target = File(p.join(input.resolvedPath, '$artifact.md'));

    // The refusal to overwrite comes first: there is no change to plan or
    // approve when the answer is that nothing will be written either way.
    // Thrown rather than reported, so it keeps its own exit code instead of
    // becoming a validation failure.
    if (target.existsSync()) {
      throw CommandException(
        code: 'ALREADY_EXISTS',
        message: '${target.path} already exists — not overwritten.',
        exitCode: ExitCode.conflict,
      );
    }

    final resolution = resolver.resolve(artifact, lang: input.lang!);
    return [
      WriteTemplate(
        path: target.path,
        contents: resolution.content,
        lang: input.lang!,
        notice: resolution.notice,
      ),
    ];
  }

  @override
  ExportTemplateOutput describe(Execution execution) {
    final outcome = execution.outcomes.single;
    return ExportTemplateOutput(
      path: outcome.target,
      lang: outcome.values['lang'] as String,
      notice: outcome.values['notice'] as String?,
    );
  }
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Writes one blank form.
class WriteTemplate implements Step {
  WriteTemplate({
    required this.path,
    required this.contents,
    required this.lang,
    this.notice,
  });

  final String path;

  /// Resolved when this step was built, and not again.
  final String contents;

  final String lang;
  final String? notice;

  @override
  Preview preview() => Preview(
    verb: 'create',
    target: path,
    detail: [lang, ?notice].join('; '),
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return Outcome(
      verb: 'create',
      target: path,
      values: {'lang': lang, 'notice': ?notice},
    );
  }
}
