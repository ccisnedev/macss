/// Registers the `dod` module — the Definition of Done.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import 'commands/check.dart';

void buildDodModule(ModuleBuilder m, {required Assets assets}) {
  m.command<DodCheckInput, DodCheckOutput>(
    'check',
    (req) => DodCheckCommand(
      DodCheckInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      runProcess: Process.run,
      assets: assets,
    ),
    description: 'Compose the delivery and verification gates, and the pull '
        'request that carries them',
    params: DodCheckInput.params,
  );
}
