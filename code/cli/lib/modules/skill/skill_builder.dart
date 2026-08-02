/// Registers the `skill` module — deploying the lifecycle skills MACSS ships.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import 'commands/clean.dart';
import 'commands/deploy.dart';
import 'commands/list.dart';

/// `macss skill deploy` materializes the shipped `SKILL.md` files into a
/// project-local, git-ignored `.skills/` directory (optionally also into an
/// assistant's own location via `--host`); `list` shows what ships; `clean`
/// removes what was deployed.
void buildSkillModule(ModuleBuilder m, {required Assets assets}) {
  m.command<SkillDeployInput, SkillDeployOutput>(
    'deploy',
    (req) => SkillDeployCommand(
      SkillDeployInput.fromCliRequest(req),
      assets: assets,
    ),
    description: 'Install the MACSS lifecycle skills for every AI host detected',
    params: SkillDeployInput.params,
  );

  m.command<SkillListInput, SkillListOutput>(
    'list',
    (req) => SkillListCommand(SkillListInput.fromCliRequest(req), assets: assets),
    description: 'List the lifecycle skills this CLI ships',
    params: SkillListInput.params,
  );

  m.command<SkillCleanInput, SkillCleanOutput>(
    'clean',
    (req) => SkillCleanCommand(
      SkillCleanInput.fromCliRequest(req),
      assets: assets,
    ),
    description: 'Remove the MACSS lifecycle skills that were deployed',
    params: SkillCleanInput.params,
  );
}
