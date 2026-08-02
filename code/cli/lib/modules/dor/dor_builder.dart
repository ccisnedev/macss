/// Registers the `dor` module — the Definition of Ready gate.
///
/// It is a stage in its own right: it produces no software, and it decides
/// whether development can start. Giving it a module of its own keeps that
/// decision visible, rather than hiding it inside the check of a document.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import 'commands/check.dart';

void buildDorModule(ModuleBuilder m, {required Assets assets}) {
  m.command<DorCheckInput, DorCheckOutput>(
    'check',
    (req) => DorCheckCommand(
      DorCheckInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      assets: assets,
    ),
    description:
        'Definition of Ready — the request, the contract and a published issue',
    params: DorCheckInput.params,
  );
}
