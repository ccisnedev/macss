/// `macss dod check` — the Definition of Done.
///
/// It composes what the two stage gates already judge and adds what neither
/// owns: that the work has a pull request. It is the mirror of `dor check`, and
/// like it, it records what it establishes.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/dod/commands/check.dart';
import 'package:macss_cli/modules/requisition/publisher.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/workspace.dart';
import 'package:macss_cli/src/checks.dart';

void main() {
  late Directory root;
  const folder = 'docs/requisitions/20260812-demo';

  File file(String rel) => File(p.join(root.path, p.joinAll(rel.split('/'))));
  String dir() => p.join(root.path, p.joinAll(folder.split('/')));

  void record({
    RequisitionState state = RequisitionState.verified,
    int? pr = 57,
  }) =>
      RequisitionRecord(
        title: 'demo',
        prTitle: 'feat(cli): x',
        state: state,
        issue: 56,
        pr: pr,
        base: pr == null ? null : 'main',
        head: pr == null ? null : 'feat/x',
      ).write(dir());

  setUp(() {
    root = Directory.systemTemp.createTempSync('macss_dod_');
    Directory(dir()).createSync(recursive: true);
    file('$folder/delivery.md').writeAsStringSync(_claimed);
    file('$folder/verification.md').writeAsStringSync(_walked);
    record();
    writeActiveRequisition(root.path,
        slug: 'demo', relDir: folder, isoDate: '2026-08-12');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<DodCheckOutput> dod() => DodCheckCommand(
        DodCheckInput(),
        workingDirectory: root.path,
        assets: Assets(root: Directory.current.path),
        runProcess: (_, _) async => ProcessResult(0, 0, _publishedBody, ''),
      ).execute();

  DoctorCheck named(DodCheckOutput out, String name) =>
      out.checks.firstWhere((c) => c.name == name);

  test('everything in place: the Definition of Done is met', () async {
    final out = await dod();

    expect(out.done, isTrue, reason: out.toText());
    expect(out.exitCode, ExitCode.ok);
    expect(named(out, 'pull request').detail, contains('#57'));
  });

  test('it composes both gates rather than replacing them', () async {
    final out = await dod();

    expect(out.checks.map((c) => c.name),
        containsAll(['delivery', 'verification', 'pull request']));
  });

  test('an unclaimed criterion fails on the delivery, not on the record',
      () async {
    file('$folder/delivery.md')
        .writeAsStringSync(_claimed.replaceAll('US1-AC1', 'US9-AC9'));

    final out = await dod();

    expect(named(out, 'delivery').status, CheckStatus.error);
    expect(named(out, 'verification').status, CheckStatus.ok);
    expect(out.done, isFalse);
  });

  test('an unjudged criterion fails on the record, not on the delivery',
      () async {
    file('$folder/verification.md').writeAsStringSync(
        _walked.replaceAll('accepted', '<!-- not yet judged -->'));

    final out = await dod();

    expect(named(out, 'verification').status, CheckStatus.error);
    expect(named(out, 'delivery').status, CheckStatus.ok);
  });

  /// What neither stage gate owns: until the pull request exists there is
  /// nothing carrying either document, and nothing to merge.
  test('no pull request, no Definition of Done', () async {
    record(state: RequisitionState.ready, pr: null);

    final out = await dod();

    expect(named(out, 'pull request').status, CheckStatus.error);
    expect(named(out, 'pull request').remediation, contains('delivery publish'));
    expect(out.done, isFalse);
  });

  group('what it records', () {
    test('passing marks the requirement done', () async {
      await dod();

      expect(RequisitionRecord.read(dir())!.state, RequisitionState.done);
    });

    test('failing establishes nothing, so it writes nothing', () async {
      file('$folder/verification.md').writeAsStringSync('# Verification\n');

      await dod();

      expect(RequisitionRecord.read(dir())!.state, RequisitionState.verified);
    });

    /// A discarded requisition that still passes every gate must not come back
    /// to life. The ladder answers this: `discarded` is earlier than nothing.
    test('it never moves a state backwards', () async {
      record(state: RequisitionState.discarded);

      await dod();

      expect(RequisitionRecord.read(dir())!.state, RequisitionState.discarded);
    });
  });
}

const _claimed = '''
# Delivery

## 1. Every criterion, and where its evidence is

| Criterion | Where the evidence is |
| --------- | --------------------- |
| US1-AC1   | order_test.dart: the state is shown |

## 2. What was not done, and why

- Nothing.
''';

const _walked = '''
# Verification

## Criteria

### US1-AC1

- **Claim:** the state is shown
- **Evidence:** order_test.dart passes
- **Judged:** accepted

## Conclusion

Accepted. — the human
''';

final _publishedBody = '''
# Requisition

## 1. Need and value

Something.

---

$specificationMarker

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

- Reading it.

### Does NOT include

- Cancelling it.
''';
