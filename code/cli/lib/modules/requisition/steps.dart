/// Steps shared by more than one command in the `requisition` module.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../specification/workspace.dart';

/// Points `.macss/active_requisition.yaml` at one requisition.
///
/// Used by `activate`, which does only this, and by `new`, which does it last.
/// One step rather than one per command, so the pointer keeps its keys and its
/// format however it came to be written.
class RecordActiveRequisition implements Step {
  RecordActiveRequisition({
    required this.workingDirectory,
    required this.slug,
    required this.relDir,
    required this.isoDate,
  });

  final String workingDirectory;
  final String slug;
  final String relDir;
  final String isoDate;

  @override
  Preview preview() => Preview(
    verb: 'activate',
    target: relDir,
    detail: 'commands that take no --slug act on the active requisition',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    writeActiveRequisition(
      workingDirectory,
      slug: slug,
      relDir: relDir,
      isoDate: isoDate,
    );
    return Outcome(verb: 'activate', target: relDir, values: {'slug': slug});
  }
}
