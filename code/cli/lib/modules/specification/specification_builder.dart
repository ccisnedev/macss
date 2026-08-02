import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../templates/template_resolver.dart';
import 'commands/check.dart';
import 'commands/new.dart';
import 'commands/publish.dart';
import '../requisition/commands/export_template.dart';

/// Registers the `specification` module — the QA-facing specification phase.
///
/// `macss specification new <slug> [--lang <lang>]` scaffolds the QA workspace
/// `docs/requisitions/<YYYYMMDD>-<slug>/` with `requisition.md` +
/// `specification.md` from the single-source templates (the CLI
/// is the hands), and records it as the active requisition.
void buildSpecificationModule(ModuleBuilder m, {required Assets assets}) {
  final resolver = TemplateResolver(assets);

  m.command<SpecificationNewInput, SpecificationNewOutput>(
    'new <slug>',
    (req) => SpecificationNewCommand(
      SpecificationNewInput.fromCliRequest(req),
      resolver: resolver,
      workingDirectory: Directory.current.path,
    ),
    description:
        'Scaffold a QA specification workspace under docs/requisitions/ '
        '(requisition.md + specification.md) and make it the active requisition',
    params: SpecificationNewInput.params,
  );

  m.command<ExportTemplateInput, ExportTemplateOutput>(
    'export-template',
    (req) => ExportTemplateCommand(
      ExportTemplateInput.fromCliRequest(req),
      resolver: resolver,
      artifact: 'specification',
    ),
    description: 'Write the blank contract template',
    params: ExportTemplateInput.params,
  );

  m.command<SpecificationPublishInput, SpecificationPublishOutput>(
    'publish',
    (req) => SpecificationPublishCommand(
      SpecificationPublishInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      runProcess: Process.run,
      assets: assets,
    ),
    description:
        'Add the contract to the issue — previews by default',
    params: SpecificationPublishInput.params,
  );

  m.command<SpecificationCheckInput, SpecificationCheckOutput>(
    'check',
    (req) => SpecificationCheckCommand(
      SpecificationCheckInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      assets: assets,
    ),
    description:
        'Run the specification_ready gate over the active requisition — '
        'exits 0 only when the spec is healthy',
    params: SpecificationCheckInput.params,
  );
}
