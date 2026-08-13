/// `macss delivery new [--slug <slug>]` — opens the delivery beside the work.
///
/// `delivery.md` is the mirror of `requisition.md`: the first document of each
/// pair **reports**, the second **commits** (ADR 0008 §1). The request states
/// what was asked and nobody signs it; the delivery states what was built and
/// nobody signs that either. The signature goes on the verification.
///
/// It carries only what a verifier cannot derive from the frozen contract and
/// the diff: which criterion is claimed where, what was deliberately not done,
/// and how to reproduce it. What was built is in the code, and why it was built
/// that way is in `adr/` or nowhere.
///
/// The pull request's title is **not** here — it is `pr_title` in `state.yaml`,
/// the way `requisition.md` has never carried its own.
///
/// The command itself is [ScaffoldDocumentCommand], shared with
/// `specification new`.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../src/scaffold_document.dart';
import '../../../templates/template_resolver.dart';

typedef DeliveryNewInput = ScaffoldDocumentInput;
typedef DeliveryNewOutput = ScaffoldDocumentOutput;

/// The contract's parameters, named where a reader of this module looks.
final List<CliParam> deliveryNewParams =
    ScaffoldDocumentInput.paramsFor('delivery');

/// `macss delivery new`.
ScaffoldDocumentCommand deliveryNewCommand(
  ScaffoldDocumentInput input, {
  required TemplateResolver resolver,
  required String workingDirectory,
  DateTime Function()? now,
}) => ScaffoldDocumentCommand(
  input,
  artifact: 'delivery',
  heading: 'Delivery',
  next:
      'Next: claim every acceptance criterion with somewhere to look, say what '
      'was not done, and record `pr_title` in state.yaml. Then '
      '`macss delivery check`.',
  resolver: resolver,
  workingDirectory: workingDirectory,
  now: now,
);
