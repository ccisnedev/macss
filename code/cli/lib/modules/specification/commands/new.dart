/// `macss specification new [--slug <slug>]` — adds the contract template to an
/// open requisition.
///
/// It creates **only** `specification.md`. The requisition is a separate
/// document with a separate author — the Product Owner's request, whoever
/// transcribed it — and creating both at once, as this command used to,
/// collapsed that distinction.
///
/// It therefore requires a requisition to exist: a contract with nothing to
/// contract about is not a document anyone can write.
///
/// The command itself is [ScaffoldDocumentCommand], shared with
/// `delivery new`: the two were the same code twice, differing only in which
/// artifact they wrote and what they told the author to do next.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../src/scaffold_document.dart';
import '../../../templates/template_resolver.dart';

typedef SpecificationNewInput = ScaffoldDocumentInput;
typedef SpecificationNewOutput = ScaffoldDocumentOutput;

/// The contract's parameters, named where a reader of this module looks.
final List<CliParam> specificationNewParams =
    ScaffoldDocumentInput.paramsFor('contract');

/// `macss specification new`.
ScaffoldDocumentCommand specificationNewCommand(
  ScaffoldDocumentInput input, {
  required TemplateResolver resolver,
  required String workingDirectory,
  DateTime Function()? now,
}) => ScaffoldDocumentCommand(
  input,
  artifact: 'specification',
  heading: 'Contract',
  next:
      'Next: fill the committed date, the user stories with their acceptance '
      'criteria, and the explicit scope. Then `macss specification check`.',
  resolver: resolver,
  workingDirectory: workingDirectory,
  now: now,
);
