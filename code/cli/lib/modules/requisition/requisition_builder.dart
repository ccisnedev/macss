/// Registers the `requisition` module — the stage where a business need becomes
/// a formal request, and the request becomes an issue.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../templates/template_resolver.dart';
import 'commands/check.dart';
import 'commands/export_template.dart';
import 'commands/new.dart';
import 'commands/publish.dart';

void buildRequisitionModule(ModuleBuilder m, {required Assets assets}) {
  final resolver = TemplateResolver(assets);

  m.command<ExportTemplateInput, ExportTemplateOutput>(
    'export-template',
    (req) => ExportTemplateCommand(
      ExportTemplateInput.fromCliRequest(req),
      resolver: resolver,
      artifact: 'requisition',
    ),
    description: 'Write the blank requisition form, to hand to the Product Owner',
    params: ExportTemplateInput.params,
  );

  m.command<RequisitionNewInput, RequisitionNewOutput>(
    'new <slug>',
    (req) => RequisitionNewCommand(
      RequisitionNewInput.fromCliRequest(req),
      resolver: resolver,
      workingDirectory: Directory.current.path,
    ),
    description:
        'Open a requisition: the form, its issue metadata, and the active pointer',
    params: RequisitionNewInput.params,
  );

  m.command<RequisitionPublishInput, RequisitionPublishOutput>(
    'publish',
    (req) => RequisitionPublishCommand(
      RequisitionPublishInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      runProcess: Process.run,
    ),
    description:
        'Create or update the issue from the requisition — previews by default',
    params: RequisitionPublishInput.params,
  );

  m.command<RequisitionCheckInput, RequisitionCheckOutput>(
    'check',
    (req) => RequisitionCheckCommand(
      RequisitionCheckInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
    ),
    description: 'Verify the Product Owner filled the form',
    params: RequisitionCheckInput.params,
  );
}
