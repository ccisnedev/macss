/// `macss verification new` — the record is opened before the walk starts.
///
/// It reads the contract from the **platform**, not from disk. A verifier may
/// hold no copy: `docs/requisitions/` is not versioned, so a local
/// `specification.md` can be absent, stale, or edited since the body froze.
/// What is authoritative is the frozen issue body.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/publisher.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/workspace.dart';
import 'package:macss_cli/modules/verification/commands/new.dart';
import 'package:macss_cli/src/plan_apply.dart';
import 'package:macss_cli/src/project_config.dart';
import 'package:macss_cli/templates/template_resolver.dart';

void main() {
  late Directory root;
  late List<List<String>> calls;
  const folder = 'docs/requisitions/20260812-demo';

  File file(String rel) => File(p.join(root.path, p.joinAll(rel.split('/'))));
  String dir() => p.join(root.path, p.joinAll(folder.split('/')));

  setUp(() {
    root = Directory.systemTemp.createTempSync('macss_vernew_');
    calls = [];
    Directory(dir()).createSync(recursive: true);
    writeProjectConfig(root.path, language: 'en');
    const RequisitionRecord(
      title: 'demo',
      state: RequisitionState.delivered,
      issue: 56,
      pr: 57,
    ).write(dir());
    writeActiveRequisition(root.path,
        slug: 'demo', relDir: folder, isoDate: '2026-08-12');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<VerificationNewOutput> open({String? body}) => VerificationNewCommand(
        VerificationNewInput(
          flags: const ChangeFlags(apply: true, autoapprove: true),
        ),
        resolver: TemplateResolver(Assets(root: Directory.current.path)),
        workingDirectory: root.path,
        now: () => DateTime(2026, 8, 12),
        runProcess: (exe, args) async {
          calls.add([exe, ...args]);
          return ProcessResult(0, 0, body ?? _publishedBody, '');
        },
      ).execute();

  String record() => file('$folder/verification.md').readAsStringSync();

  group('the record it opens', () {
    test('lists every criterion of the contract, in its order', () async {
      await open();

      expect(record(), contains('US1-AC1'));
      expect(record(), contains('US1-AC2'));
      expect(record(), contains('US2-AC1'));
      expect(record().indexOf('US1-AC2'), lessThan(record().indexOf('US2-AC1')));
    });

    test('none of them is judged', () async {
      await open();

      // Every criterion carries the same empty verdict, and there are exactly
      // as many of them as the contract declares. A record that arrived with
      // any of them filled would be a reconstruction, which is the one thing
      // opening it early exists to prevent.
      expect('not yet judged'.allMatches(record()).length, 3);
      expect(record(), isNot(contains('**Judged:** the')));
    });

    /// The request and the contract number their sections identically. Reading
    /// the whole body would list the requisition's headings as if they were
    /// criteria, and never fail while doing it.
    test('nothing from the request travels into it', () async {
      await open();

      expect(record(), isNot(contains('Need and value')));
    });

    test('it asks the platform for the issue the record names', () async {
      await open();

      expect(calls.single, containsAllInOrder(['gh', 'issue', 'view', '56']));
    });
  });

  group('what it refuses', () {
    /// Bodies published before the marker existed cannot acquire one: the issue
    /// froze at its Definition of Ready, and re-publishing to add a marker is
    /// the edit the freeze forbids.
    test('a contract published before the marker', () async {
      final out = await open(body: '# Requisition\n\n## 1. Need and value\n\nx');

      expect(out.ok, isFalse);
      expect(out.message, contains('marker'));
      expect(file('$folder/verification.md').existsSync(), isFalse);
    });

    test('a requisition with no published issue', () async {
      const RequisitionRecord(title: 'demo', state: RequisitionState.opened)
          .write(dir());

      final cmd = VerificationNewCommand(
        VerificationNewInput(
          flags: const ChangeFlags(apply: true, autoapprove: true),
        ),
        resolver: TemplateResolver(Assets(root: Directory.current.path)),
        workingDirectory: root.path,
        runProcess: (_, _) async => ProcessResult(0, 0, '', ''),
      );

      expect(cmd.validate(), contains('not been published'));
    });

    test('a contract that declares no criterion', () async {
      final out = await open(
          body: '$specificationMarker\n\n# Specification\n\n## 2. User Stories');

      expect(out.ok, isFalse);
      expect(out.message, contains('no acceptance criterion'));
    });
  });

  test('it keeps a record that is already open', () async {
    await open();
    file('$folder/verification.md').writeAsStringSync('HALF WALKED');

    final out = await open();

    expect(out.message, contains('kept'));
    expect(record(), 'HALF WALKED');
  });
}

final _publishedBody = '''
# Requisition

## 1. Need and value

Something is missing.

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

| AC  | Given (context)  | When (action) | Then (expected result) |
| --- | ---------------- | ------------- | ---------------------- |
| 1   | an order exists  | I open it     | I see its state        |
| 2   | it was cancelled | I open it     | I see it was cancelled |

### US-2: Something else

- **As a** seller
- **I want** to see the order too
- **So that** I can prepare it

| AC  | Given (context) | When (action) | Then (expected result) |
| --- | --------------- | ------------- | ---------------------- |
| 1   | an order exists | I open it     | I see the buyer        |

## 3. Explicit Scope

### Includes

- Reading the order.

### Does NOT include

- Cancelling it.
''';
