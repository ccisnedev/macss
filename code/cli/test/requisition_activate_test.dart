import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/requisition/commands/activate.dart';
import 'package:macss_cli/modules/specification/workspace.dart';
import 'package:macss_cli/src/plan_apply.dart';

/// Selecting a requisition is the operation that used to be a hand edit.
///
/// Two properties are being bought. It must never pick for you when what you
/// gave is ambiguous — the requisition says *"refuses and shows the candidates
/// rather than guessing"*. And it must obey the same convention as everything
/// else that writes: a command exempt from it is the first crack in it.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_activate_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void makeRequisition(String folder) =>
      Directory(p.join(root.path, 'docs', 'requisitions', folder))
          .createSync(recursive: true);

  RequisitionActivateCommand command(
    String? slug, {
    bool plan = false,
    bool apply = false,
    bool autoapprove = true,
  }) =>
      RequisitionActivateCommand(
        RequisitionActivateInput(
          slug: slug,
          flags: ChangeFlags(plan: plan, apply: apply, autoapprove: autoapprove),
        ),
        workingDirectory: root.path,
        now: () => DateTime(2026, 8, 6),
      );

  String? pointerSlug() {
    final f = File(p.join(root.path, '.macss', 'active_requisition.yaml'));
    if (!f.existsSync()) return null;
    return RegExp(r'^slug:\s*(.+)$', multiLine: true)
        .firstMatch(f.readAsStringSync())
        ?.group(1)
        ?.trim();
  }

  group('selecting', () {
    test('makes the requisition the one later commands act on', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');

      final out = await command('beta', apply: true).execute();

      expect(out.exitCode, ExitCode.ok);
      expect(resolveRequisitionDir(root.path), endsWith('20260805-beta'));
      expect(pointerSlug(), 'beta');
    });

    test('announces which requisition is now active', () async {
      makeRequisition('20260805-beta');

      final out = await command('beta', apply: true).execute();

      expect(out.toText(), contains('beta'));
    });

    test('a name matching nothing refuses, and shows what does exist', () {
      makeRequisition('20260804-alpha');

      final error = command('nothing-like-it', apply: true).validate();

      expect(error, isNotNull);
      expect(error, contains('alpha'));
      expect(pointerSlug(), isNull);
    });

    // The defect this requirement corrects, at the command level.
    test('an ambiguous name refuses and shows the candidates', () {
      makeRequisition('20260804-demo');
      makeRequisition('20260806-demo');

      final error = command('demo', apply: true).validate();

      expect(error, contains('20260804-demo'));
      expect(error, contains('20260806-demo'));
      expect(pointerSlug(), isNull, reason: 'nothing is selected on a refusal');
    });
  });

  group('it writes, so it says which of plan or apply it is doing', () {
    test('neither flag is a usage error, and the pointer is untouched', () {
      makeRequisition('20260805-beta');

      final error = command('beta').validate();

      expect(error, contains('--plan'));
      expect(error, contains('--apply'));
      expect(pointerSlug(), isNull);
    });

    test('--plan names what would become active and changes nothing', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');
      await command('alpha', apply: true).execute();

      final out = await command('beta', plan: true).execute();

      expect(out.toText(), contains('beta'));
      expect(pointerSlug(), 'alpha', reason: 'a plan changes nothing');
    });

    test('a slug is required: there is nothing to derive it from', () {
      makeRequisition('20260805-beta');

      expect(command(null, apply: true).validate(), isNotNull);
    });
  });
}
