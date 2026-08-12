/// Where the contract comes from on this side of the cycle: the platform.
///
/// `delivery check` reads `specification.md` from disk, because it runs on the
/// machine that specified and implemented, where the file is there by
/// construction. Verification cannot assume that. `docs/requisitions/` is not
/// versioned, so the verifier may hold no copy, a stale one, or one edited
/// since the body froze — and what is authoritative is the frozen issue body.
///
/// So the three verification commands ask the same question of the same place,
/// through here, rather than each deciding for itself.
library;

import '../requisition/publisher.dart';
import '../requisition/requisition_record.dart';
import '../specification/specification_gate.dart';

/// The criteria a contract declares, or why they could not be read.
class ContractCriteria {
  final List<String> ids;
  final String? failure;

  const ContractCriteria(this.ids) : failure = null;
  const ContractCriteria.unavailable(this.failure) : ids = const [];

  bool get ok => failure == null;
}

/// Reads the frozen contract off the issue and returns its criterion ids.
Future<ContractCriteria> criteriaFromPlatform(
  RequisitionRecord record, {
  required ProcessRunner runProcess,
  required SpecificationGate gate,
}) async {
  final fetched = await runProcess(
    'gh',
    ['issue', 'view', '${record.issue}', '--json', 'body', '--jq', '.body'],
  );
  if (fetched.exitCode != 0) {
    return ContractCriteria.unavailable(
      'Could not read issue #${record.issue}:\n${fetched.stderr}'.trimRight(),
    );
  }

  final contract = contractIn(fetched.stdout.toString());
  if (contract == null) {
    return ContractCriteria.unavailable(
      'Issue #${record.issue} carries no `$specificationMarker` marker, so the '
      'contract cannot be told apart from the request it follows. The body '
      'predates the marker and cannot acquire one — it froze at its Definition '
      'of Ready. Walk it from the issue by hand.',
    );
  }

  final ids = gate.acIds(contract);
  if (ids.isEmpty) {
    return ContractCriteria.unavailable(
      'The contract on issue #${record.issue} declares no acceptance criterion. '
      'There is nothing to verify against, and that is a defect of the contract '
      'rather than of this walk.',
    );
  }

  return ContractCriteria(ids);
}
