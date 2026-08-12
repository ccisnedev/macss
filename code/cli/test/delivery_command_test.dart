/// `macss delivery new` / `check` — the pull-request side's first stage.
library;

import 'dart:io';

import 'package:modular_cli_sdk/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/delivery/commands/check.dart';
import 'package:macss_cli/modules/delivery/commands/new.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/workspace.dart';
import 'package:macss_cli/src/checks.dart';
import 'package:macss_cli/src/project_config.dart';
import 'package:macss_cli/templates/template_resolver.dart';

void main() {
  late Directory root;
  late Assets assets;
  const folder = 'docs/requisitions/20260812-demo';

  File file(String rel) => File(p.join(root.path, p.joinAll(rel.split('/'))));
  String dir() => p.join(root.path, p.joinAll(folder.split('/')));

  setUp(() {
    root = Directory.systemTemp.createTempSync('macss_delivery_');
    assets = Assets(root: Directory.current.path);
    Directory(dir()).createSync(recursive: true);
    writeProjectConfig(root.path, language: 'en');
    file('$folder/specification.md').writeAsStringSync(_contract);
    const RequisitionRecord(
      title: 'demo',
      prTitle: 'feat(cli): the delivery side',
      state: RequisitionState.ready,
      issue: 56,
    ).write(dir());
    writeActiveRequisition(root.path,
        slug: 'demo', relDir: folder, isoDate: '2026-08-12');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  DeliveryNewCommand opener() => DeliveryNewCommand(
        DeliveryNewInput(),
        resolver: TemplateResolver(assets),
        workingDirectory: root.path,
        now: () => DateTime(2026, 8, 12),
      );

  Future<DeliveryNewOutput> open() async => await applyCommand(opener());

  /// A repository whose HEAD is a branch of its own, unless told otherwise.
  DeliveryCheckCommand check({String head = 'feat/x', String? base = 'origin/main'}) =>
      DeliveryCheckCommand(
        DeliveryCheckInput(),
        workingDirectory: root.path,
        assets: assets,
        runGit: (args) {
          if (args.last == 'HEAD') return ProcessResult(0, 0, '$head\n', '');
          if (args.last == 'origin/HEAD') {
            return base == null
                ? ProcessResult(0, 128, '', 'fatal: ambiguous argument')
                : ProcessResult(0, 0, '$base\n', '');
          }
          return ProcessResult(0, 1, '', '');
        },
      );

  DoctorCheck named(DeliveryCheckOutput out, String name) =>
      out.checks.firstWhere((c) => c.name == name);

  group('macss delivery new', () {
    test('scaffolds the delivery in the project language', () async {
      await open();

      expect(file('$folder/delivery.md').existsSync(), isTrue);
      expect(file('$folder/delivery.md').readAsStringSync(),
          contains('# Delivery'));
    });

    test('is idempotent — a second run keeps what is there', () async {
      await open();
      file('$folder/delivery.md').writeAsStringSync('WRITTEN BY THE AGENT');

      final out = await open();

      expect(out.kept, isTrue);
      expect(file('$folder/delivery.md').readAsStringSync(),
          'WRITTEN BY THE AGENT');
    });

    // That exactly one of --plan and --apply is required is the SDK's rule,
    // applied to every command and tested there.
    test('says what it would write, and writes nothing', () async {
      final previews = await previewCommand(opener());

      expect(previews.single.verb, 'create');
      expect(previews.single.target, endsWith('delivery.md'));
      expect(file('$folder/delivery.md').existsSync(), isFalse);
    });
  });

  group('macss delivery check', () {
    test('a scaffolded but unfilled delivery does not pass', () async {
      await open();

      final out = await check().execute();

      expect(out.ready, isFalse);
      expect(named(out, 'delivery').detail, contains('DELIVERY_AC'));
    });

    test('every criterion claimed with somewhere to look passes', () async {
      await open();
      file('$folder/delivery.md').writeAsStringSync(_claimed);

      final out = await check().execute();

      expect(out.ready, isTrue, reason: out.toText());
      expect(named(out, 'delivery').status, CheckStatus.ok);
    });

    test('no delivery at all says so, and how to open one', () async {
      final out = await check().execute();

      expect(named(out, 'delivery').detail, contains('never opened'));
      expect(named(out, 'delivery').remediation, contains('delivery new'));
    });

    /// `gh pr create` cannot accept a head that is also the base. This is the
    /// last gate before that failure would land with all the work done.
    test('the default branch cannot carry a pull request', () async {
      await open();
      file('$folder/delivery.md').writeAsStringSync(_claimed);

      final out = await check(head: 'main').execute();

      expect(out.ready, isFalse);
      expect(named(out, 'branch').status, CheckStatus.error);
      expect(named(out, 'branch').detail, contains('default branch'));
    });

    /// A gate that blocked on an unconfigured ref would stop the work for a
    /// reason that has nothing to do with the delivery.
    test('an unset origin/HEAD warns and does not block', () async {
      await open();
      file('$folder/delivery.md').writeAsStringSync(_claimed);

      final out = await check(base: null).execute();

      expect(named(out, 'branch').status, CheckStatus.warning);
      expect(out.ready, isTrue, reason: out.toText());
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
