/// `macss verification publish` — the evidence joins the pull request the
/// delivery opened.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/publisher.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/workspace.dart';
import 'package:macss_cli/modules/verification/commands/publish.dart';

void main() {
  late Directory root;
  late List<List<String>> calls;
  String? sentBody;
  const folder = 'docs/requisitions/20260812-demo';

  File file(String rel) => File(p.join(root.path, p.joinAll(rel.split('/'))));
  String dir() => p.join(root.path, p.joinAll(folder.split('/')));

  setUp(() {
    root = Directory.systemTemp.createTempSync('macss_verpub_');
    calls = [];
    sentBody = null;
    Directory(dir()).createSync(recursive: true);
    file('$folder/delivery.md').writeAsStringSync('# Delivery\n\nwhat was built\n');
    file('$folder/verification.md').writeAsStringSync(_walked);
    const RequisitionRecord(
      title: 'demo',
      prTitle: 'feat(cli): x',
      state: RequisitionState.delivered,
      issue: 56,
      pr: 57,
      base: 'main',
      head: 'feat/x',
    ).write(dir());
    writeActiveRequisition(root.path,
        slug: 'demo', relDir: folder, isoDate: '2026-08-12');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  VerificationPublishCommand publisher() => VerificationPublishCommand(
    VerificationPublishInput(),
    workingDirectory: root.path,
    assets: Assets(root: Directory.current.path),
    runProcess: (exe, args) async {
      calls.add([exe, ...args]);
      final at = args.indexOf('--body-file');
      if (at >= 0) sentBody = File(args[at + 1]).readAsStringSync();
      if (args.contains('view')) {
        return ProcessResult(0, 0, _publishedBody, '');
      }
      return ProcessResult(0, 0, 'https://github.com/o/r/pull/57', '');
    },
    runGit: (args) {
      calls.add(['git', ...args]);
      // The ordinary answer for a stage that produces no code.
      return ProcessResult(0, 0, 'Everything up-to-date\n', '');
    },
  );

  Future<VerificationPublishOutput> publish() async =>
      await applyCommand(publisher());

  /// What it says it would do. Nothing reaches the pull request.
  Future<List<Preview>> plan() => previewCommand(publisher());

  List<String> ghEdit() =>
      calls.lastWhere((c) => c.first == 'gh' && c.contains('pr'));

  test('the evidence is appended to the pull request, after the delivery',
      () async {
    final out = await publish();

    expect(out.pr, 57, reason: out.toText());
    expect(ghEdit(), containsAllInOrder(['pr', 'edit', '57']));
    expect(sentBody, contains('what was built'));
    expect(sentBody!.indexOf('what was built'),
        lessThan(sentBody!.indexOf('# Verification')),
        reason: 'the delivery is read first, then the evidence for it');
  });

  test('the state records that it was verified', () async {
    await publish();

    expect(RequisitionRecord.read(dir())!.state, RequisitionState.verified);
  });

  /// Verification produces no code, so nothing to push is the ordinary case
  /// and must not read as a failure. What the push covers is the walk that
  /// turned up a fix.
  test('nothing to push is not a failure', () async {
    final out = await publish();

    expect(calls.any((c) => c.first == 'git' && c.contains('push')), isTrue);
    expect(out.recordedState, RequisitionState.verified.name);
  });

  test('an unfinished record is not published', () async {
    file('$folder/verification.md')
        .writeAsStringSync(_walked.replaceAll('accepted, in their words',
            '<!-- not yet judged -->'));

    await expectLater(
      publish(),
      throwsA(isA<CommandException>().having(
          (e) => e.message, 'message', contains('VERIFICATION_AC_UNJUDGED'))),
    );
    expect(calls.any((c) => c.first == 'gh' && c.contains('edit')), isFalse);
  });

  test('names what would change and changes nothing', () async {
    final previews = await plan();

    // Push, publish, record — and the order is what makes the last one honest:
    // a state written before gh returned would claim something the platform
    // never received.
    expect(previews.map((p) => p.verb), ['push', 'update', 'record']);
    expect(previews[1].target, contains('57'));
    expect(previews.last.detail, contains('verified'));

    expect(calls.any((c) => c.contains('edit')), isFalse);
    expect(RequisitionRecord.read(dir())!.state, RequisitionState.delivered);
  });
}

const _walked = '''
# Verification

## Criteria

### US1-AC1

- **Claim:** the state is shown
- **Evidence:** order_test.dart passes
- **Judged:** accepted, in their words

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
