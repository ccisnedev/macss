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

  SpecificationNewInput({this.slug, this.lang});

  factory SpecificationNewInput.fromCliRequest(CliRequest req) =>
      SpecificationNewInput(
        slug: optionalSlug(req.flagString('slug')),
        lang: req.flagString('lang'),
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
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug, 'lang': lang};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SpecificationNewOutput extends Output {
  final String message;

  SpecificationNewOutput({required this.message});

  @override
  Map<String, dynamic> toJson() => {'message': message};

  @override
  int get exitCode => ExitCode.ok;

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

  SpecificationNewCommand(
    this.input, {
    required this.resolver,
    required this.workingDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

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
  Future<SpecificationNewOutput> execute() async {
    final dir = _dir!;
    final relDir = p.posix.joinAll(
      p.split(p.relative(dir, from: workingDirectory)),
    );
    final relPath = p.posix.join(relDir, 'specification.md');
    final file = File(p.join(dir, 'specification.md'));

    if (file.existsSync()) {
      return SpecificationNewOutput(
        message: '  kept     $relPath (already exists)',
      );
    }

    final lang = input.lang ?? IssueMetadata.read(dir)?.lang ?? 'en';
    final resolution = resolver.resolve('specification', lang: lang);
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
