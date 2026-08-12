/// `macss delivery publish` — the delivery becomes a pull request.
///
/// It is the first command in this CLI that writes outside the machine by a
/// route that is not `gh`: it pushes. So `--plan` has to say so and do nothing,
/// and every process it would run is stubbed here.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/delivery/commands/publish.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/workspace.dart';

void main() {
  late Directory root;
  late List<List<String>> calls;
  // Captured while the call is in flight: the body file is a temp file the
  // publisher deletes on the way out, and reading it afterwards is racing a
  // cleanup that is doing the right thing.
  String? sentBody;
  const folder = 'docs/requisitions/20260812-demo';

  File file(String rel) => File(p.join(root.path, p.joinAll(rel.split('/'))));
  String dir() => p.join(root.path, p.joinAll(folder.split('/')));

  setUp(() {
    root = Directory.systemTemp.createTempSync('macss_delpub_');
    calls = [];
    sentBody = null;
    Directory(dir()).createSync(recursive: true);
    file('$folder/specification.md').writeAsStringSync(_contract);
    file('$folder/delivery.md').writeAsStringSync(_claimed);
    const RequisitionRecord(
      title: 'demo',
      prTitle: 'feat(cli): the delivery side',
      labels: ['enhancement'],
      state: RequisitionState.ready,
      issue: 56,
    ).write(dir());
    writeActiveRequisition(root.path,
        slug: 'demo', relDir: folder, isoDate: '2026-08-12');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<DeliveryPublishOutput> publish({
    bool apply = true,
    String stdout = 'https://github.com/o/r/pull/57',
    String head = 'feat/x',
  }) =>
      DeliveryPublishCommand(
        DeliveryPublishInput(
          flags: apply
              ? const ChangeFlags(apply: true, autoapprove: true)
              : const ChangeFlags(plan: true),
        ),
        workingDirectory: root.path,
        assets: Assets(root: Directory.current.path),
        runProcess: (exe, args) async {
          calls.add([exe, ...args]);
          final at = args.indexOf('--body-file');
          if (at >= 0) sentBody = File(args[at + 1]).readAsStringSync();
          return ProcessResult(0, 0, stdout, '');
        },
        runGit: (args) {
          calls.add(['git', ...args]);
          if (args.last == 'HEAD') return ProcessResult(0, 0, '$head\n', '');
          if (args.last == 'origin/HEAD') {
            return ProcessResult(0, 0, 'origin/main\n', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      ).execute();

  List<String> gh() => calls.firstWhere((c) => c.first == 'gh');
  bool pushed() => calls.any((c) => c.first == 'git' && c.contains('push'));

  group('--plan', () {
    test('names the push and the pull request, and does neither', () async {
      final out = await publish(apply: false);

      expect(out.planPath, isNotNull);
      final plan = File(out.planPath!).readAsStringSync();
      expect(plan, contains('push'));
      expect(plan, contains('feat/x'));
      expect(plan, contains('main'));

      expect(pushed(), isFalse, reason: 'a plan pushes nothing');
      expect(calls.any((c) => c.first == 'gh'), isFalse);
      expect(RequisitionRecord.read(dir())!.state, RequisitionState.ready);
    });
  });

  group('--apply', () {
    test('pushes the branch before it opens the pull request', () async {
      await publish();

      final pushAt = calls.indexWhere((c) => c.contains('push'));
      final ghAt = calls.indexWhere((c) => c.first == 'gh');
      expect(pushAt, isNonNegative, reason: 'the branch was never pushed');
      expect(pushAt, lessThan(ghAt),
          reason: 'gh pr create needs a head that exists on the remote');
    });

    test('opens it between the branch it is on and the default branch',
        () async {
      await publish();

      expect(gh(), containsAllInOrder(['pr', 'create']));
      expect(gh(), containsAllInOrder(['--base', 'main']));
      expect(gh(), containsAllInOrder(['--head', 'feat/x']));
      expect(gh(), containsAllInOrder(['--title', 'feat(cli): the delivery side']),
          reason: 'the PR carries pr_title, never the issue title');
    });

    test('records the pull request, its branches and the state', () async {
      await publish();

      final record = RequisitionRecord.read(dir())!;
      expect(record.pr, 57);
      expect(record.base, 'main');
      expect(record.head, 'feat/x');
      expect(record.state, RequisitionState.delivered);
      expect(record.issue, 56, reason: 'the issue survives the transition');
    });

    /// #44 is open on purpose with its work merged. Auto-closing would fight a
    /// method that lets an issue outlive the pull request that answered it.
    test('the body points at the issue without closing it', () async {
      await publish();

      expect(sentBody, contains('#56'));
      expect(sentBody!.toLowerCase(), isNot(contains('closes #56')));
      expect(sentBody, contains('Every criterion'),
          reason: 'the body is the delivery');
    });

    test('a delivery that does not pass its gate is not published', () async {
      file('$folder/delivery.md').writeAsStringSync('# Delivery\n\nnothing.\n');

      final out = await publish();

      expect(out.ok, isFalse);
      expect(pushed(), isFalse, reason: 'nothing leaves the machine on a red gate');
    });
  });

  group('publishing twice', () {
    /// `gh issue edit` rejects `--label` and takes `--add-label`; `gh pr edit`
    /// has the same asymmetry. Sending `--label` to both is what shipped on the
    /// issue side and made every update fail once a requisition declared a
    /// label.
    test('edits the pull request it already opened, and adds labels', () async {
      await publish();
      calls.clear();

      final out = await publish();

      expect(out.ok, isTrue, reason: out.toText());
      expect(gh(), containsAllInOrder(['pr', 'edit', '57']));
      expect(gh(), containsAllInOrder(['--add-label', 'enhancement']));
      expect(gh(), isNot(contains('--label')));
    });
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

const _claimed = '''
# Delivery

## 1. Every criterion, and where its evidence is

| Criterion | Where the evidence is |
| --------- | --------------------- |
| US1-AC1   | order_test.dart: the state is shown |

## 2. What was not done, and why

- Nothing.
''';
