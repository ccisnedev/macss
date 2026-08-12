/// Registers the `verification` module — the stage where the evidence is
/// gathered and a human judges it.
///
/// It is the twin of `specification` on the other side of the cycle: both are
/// the human-with-agent documents, and both are the **second** of their pair,
/// which is where the signature goes (ADR 0008 §1).
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../templates/template_resolver.dart';
import 'commands/new.dart';

void buildVerificationModule(ModuleBuilder m, {required Assets assets}) {
  final resolver = TemplateResolver(assets);

  m.command<VerificationNewInput, VerificationNewOutput>(
    'new',
    (req) => VerificationNewCommand(
      VerificationNewInput.fromCliRequest(req),
      resolver: resolver,
      workingDirectory: Directory.current.path,
      runProcess: Process.run,
    ),
    description: 'Open the record: every criterion of the frozen contract, '
        'unjudged — --plan or --apply',
    params: VerificationNewInput.params,
  );
}
