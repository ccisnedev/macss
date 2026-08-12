import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../templates/template_resolver.dart';
import 'commands/check.dart';
import 'commands/new.dart';
import 'commands/publish.dart';

/// Registers the `specification` module — the contract written on top of a
/// request that already exists.
///
/// `macss specification new` writes `specification.md` into the active
/// requisition, in the language the project declared once in
/// `.macss/config.yaml`. It takes no `--lang`: a setting passed per invocation
/// is one that can differ per invocation.
void buildSpecificationModule(ModuleBuilder m, {required Assets assets}) {
  final resolver = TemplateResolver(assets);

  m.command<SpecificationNewInput, SpecificationNewOutput>(
    'new',
    (req) => specificationNewCommand(
      SpecificationNewInput.fromCliRequest(req),
      resolver: resolver,
      workingDirectory: Directory.current.path,
    ),
    description:
        'Write the contract template into the active requisition',
    params: specificationNewParams,
  );

  // No specification export-template. Of the four documents, the requisition
  // is the only one handed to somebody outside the team — it is this method's
  // issue template. A blank contract would be a form for work nobody outside is
  // doing.

  m.command<SpecificationPublishInput, SpecificationPublishOutput>(
    'publish',
    (req) => SpecificationPublishCommand(
      SpecificationPublishInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      runProcess: Process.run,
      assets: assets,
    ),
    description: 'Add the contract to the issue — --plan or --apply',
    params: SpecificationPublishInput.params,
  );

  m.query<SpecificationCheckInput, SpecificationCheckOutput>(
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
