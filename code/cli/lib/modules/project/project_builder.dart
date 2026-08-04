/// Registers the `project` module — a project's conformance to the MACSS canon.
///
/// The three commands are the same concern at three moments: `create` builds a
/// conforming project from nothing, `check` diagnoses one that exists, `adopt`
/// retrofits one that predates MACSS. They share `canon.dart`, so the canon can
/// only be changed in one place.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../src/plan_apply.dart';
import 'commands/adopt.dart';
import 'commands/check.dart';
import 'commands/create.dart';

/// [approver] is a seam, not a feature: `--apply` asks a human, and a test that
/// runs the advertised command end to end has no terminal to answer from.
/// Without it the guard could only assert that the command parses, which is
/// weaker than asserting it does what it advertises.
///
/// [workingDirectory] is a seam for the same reason. It defaults to the
/// process's, and a test that needs a different one must be able to say so
/// rather than assign to `Directory.current` — that is process-wide state, and
/// `dart test` loads suites concurrently in one process, so moving it under a
/// sibling suite that resolves a relative path at load time makes that suite
/// fail at random.
void buildProjectModule(
  ModuleBuilder m, {
  required Assets assets,
  Approver? approver,
  String? workingDirectory,
}) {
  m.command<CreateInput, CreateOutput>(
    'create',
    (req) => CreateCommand(
      CreateInput.fromCliRequest(req, workingDirectory: workingDirectory),
      assets: assets,
      approver: approver,
    ),
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
    (req) => ProjectAdoptCommand(
      ProjectAdoptInput.fromCliRequest(req, workingDirectory: workingDirectory),
      assets: assets,
      approver: approver,
    ),
    description:
        'Create what an existing project is missing to follow the canon — --plan or --apply',
    params: ProjectAdoptInput.params,
  );
}
