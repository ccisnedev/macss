/// Publishing the contract advances the requisition's state.
///
/// The stage was untested: `specification publish` appends the contract to the
/// issue, and nothing recorded that it had happened. The listing could only
/// infer it from a file being on disk, which says the document was written —
/// not that anybody else can read it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/commands/publish.dart';
import 'package:macss_cli/modules/specification/workspace.dart';
import 'package:macss_cli/src/plan_apply.dart';

void main() {
  late Directory root;
  const folder = 'docs/requisitions/20260812-x';

  File file(String rel) =>
      File(p.join(root.path, p.joinAll(rel.split('/'))));
  String dir() => p.join(root.path, p.joinAll(folder.split('/')));

  setUp(() {
    root = Directory.systemTemp.createTempSync('macss_specpub_');
    Directory(dir()).createSync(recursive: true);
    file('$folder/specification.md').writeAsStringSync(_contract);
    const RequisitionRecord(
      title: 'x',
      state: RequisitionState.published,
      issue: 42,
    ).write(dir());
    writeActiveRequisition(root.path,
        slug: 'x', relDir: folder, isoDate: '2026-08-12');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SpecificationPublishOutput> publish() =>
      SpecificationPublishCommand(
        SpecificationPublishInput(flags: const ChangeFlags(
          apply: true,
          autoapprove: true,
        )),
        workingDirectory: root.path,
        runProcess: (_, __) async =>
            ProcessResult(0, 0, 'https://github.com/o/r/issues/42', ''),
        assets: Assets(root: Directory.current.path),
      ).execute();

  test('publishing the contract records that the requisition is specified',
      () async {
    final out = await publish();

    expect(out.exitCode, 0, reason: out.toText());
    expect(RequisitionRecord.read(dir())!.state, RequisitionState.specified);
  });

  test('the issue number it was published to survives the transition',
      () async {
    await publish();
    expect(RequisitionRecord.read(dir())!.issue, 42);
  });
}

const _contract = '''
# Specification

## 1. Commitment date

2026-09-01

## 2. User Stories

### US-1: Something worth building

- **As a** buyer
- **I want** to see my order
- **So that** I know it is coming

| AC  | Given (context) | When (action) | Then (expected result) |
| --- | --------------- | ------------- | ---------------------- |
| 1   | an order exists | I open it     | I see its state        |

## 3. Explicit Scope

### Includes

- Reading the order.

### Does NOT include

- Cancelling it.
''';
