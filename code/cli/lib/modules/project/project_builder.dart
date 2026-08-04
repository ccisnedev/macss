/// Registers the `project` module — a project's conformance to the MACSS canon.
///
/// The three commands are the same concern at three moments: `create` builds a
/// conforming project from nothing, `check` diagnoses one that exists, `adopt`
/// retrofits one that predates MACSS. They share `canon.dart`, so the canon can
/// only be changed in one place.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import 'commands/adopt.dart';
import 'commands/check.dart';
import 'commands/create.dart';

void buildProjectModule(ModuleBuilder m, {required Assets assets}) {
  m.command<CreateInput, CreateOutput>(
    'create',
    (req) => CreateCommand(CreateInput.fromCliRequest(req), assets: assets),
    description: 'Scaffold a new MACSS project',
    params: CreateInput.params,
  );

  m.command<ProjectCheckInput, ProjectCheckOutput>(
    'check',
    (req) => ProjectCheckCommand(ProjectCheckInput.fromCliRequest(req)),
    description:
        'Diagnose a project against the MACSS canon — what is missing, what deviates',
    params: ProjectCheckInput.params,
  );

  m.command<ProjectAdoptInput, ProjectAdoptOutput>(
    'adopt',
    (req) =>
        ProjectAdoptCommand(ProjectAdoptInput.fromCliRequest(req), assets: assets),
    description:
        'Create what an existing project is missing to follow the canon — --plan or --apply',
    params: ProjectAdoptInput.params,
  );
}
