/// Registers the `delivery` module — the stage where the work becomes a
/// document, and the document becomes a pull request.
///
/// It mirrors `specification`, on the other side of the cycle: `new` opens the
/// artifact, `check` runs the stage gate, and `publish` materializes it on the
/// platform (ADR 0008 §5). There is no `macss pr` module for the same reason
/// there is no `macss issue` one — the pull request is a consequence of
/// publishing the delivery, not an artifact somebody composes.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../templates/template_resolver.dart';
import 'commands/check.dart';
import 'commands/new.dart';

void buildDeliveryModule(ModuleBuilder m, {required Assets assets}) {
  final resolver = TemplateResolver(assets);

  m.command<DeliveryNewInput, DeliveryNewOutput>(
    'new',
    (req) => DeliveryNewCommand(
      DeliveryNewInput.fromCliRequest(req),
      resolver: resolver,
      workingDirectory: Directory.current.path,
    ),
    description: 'Open the delivery: what was built, against which contract — '
        '--plan or --apply',
    params: DeliveryNewInput.params,
  );

  m.command<DeliveryCheckInput, DeliveryCheckOutput>(
    'check',
    (req) => DeliveryCheckCommand(
      DeliveryCheckInput.fromCliRequest(req),
      workingDirectory: Directory.current.path,
      assets: assets,
    ),
    description: 'Verify every acceptance criterion is claimed with its '
        'evidence, and the branch can carry a pull request',
    params: DeliveryCheckInput.params,
  );
}
