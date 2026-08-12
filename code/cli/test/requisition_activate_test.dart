import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/requisition/commands/activate.dart';
import 'package:macss_cli/modules/specification/workspace.dart';

import 'package:modular_cli_sdk/testing.dart';

/// Selecting a requisition is the operation that used to be a hand edit.
///
/// Two properties are being bought. It must never pick for you when what you
/// gave is ambiguous — the requisition says *"refuses and shows the candidates
/// rather than guessing"*. And it must obey the same convention as everything
/// else that writes.
///
/// What is **not** tested here any more: that `--plan` and `--apply` are
/// declared, that exactly one is required, and that neither is a default. The
/// SDK applies those to every command and has its own tests for them; asserting
/// them once per command tested the SDK from thirteen places at once.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_activate_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void makeRequisition(String folder) =>
      Directory(p.join(root.path, 'docs', 'requisitions', folder))
          .createSync(recursive: true);

  RequisitionActivateCommand command(String? slug) =>
      RequisitionActivateCommand(
        RequisitionActivateInput(slug: slug),
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

      final out = await applyCommand(command('beta'));

      expect(out.exitCode, ExitCode.ok);
      expect(resolveRequisitionDir(root.path), endsWith('20260805-beta'));
      expect(pointerSlug(), 'beta');
    });

    test('announces which requisition is now active', () async {
      makeRequisition('20260805-beta');

      final out = await applyCommand(command('beta'));

      expect(out.toText(), contains('beta'));
    });

    test('a name matching nothing refuses, and shows what does exist', () {
      makeRequisition('20260804-alpha');

      final error = command('nothing-like-it').validate();

      expect(error, isNotNull);
      expect(error, contains('alpha'));
      expect(pointerSlug(), isNull);
    });

    // The defect this requirement corrects, at the command level.
    test('an ambiguous name refuses and shows the candidates', () {
      makeRequisition('20260804-demo');
      makeRequisition('20260806-demo');

      final error = command('demo').validate();

      expect(error, contains('20260804-demo'));
      expect(error, contains('20260806-demo'));
      expect(pointerSlug(), isNull, reason: 'nothing is selected on a refusal');
    });

    test('a slug is required: there is nothing to derive it from', () {
      makeRequisition('20260805-beta');

      expect(command(null).validate(), isNotNull);
    });
  });

  group('what it would do', () {
    test('names the requisition that would become active', () async {
      makeRequisition('20260805-beta');

      final previews = await previewCommand(command('beta'));

      expect(previews.single.verb, 'activate');
      expect(previews.single.target, contains('20260805-beta'));
    });

    test('asking changes nothing', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');
      await applyCommand(command('alpha'));

      await previewCommand(command('beta'));

      expect(pointerSlug(), 'alpha', reason: 'a preview changes nothing');
    });

    test('is one step: the pointer, and nothing else', () async {
      makeRequisition('20260805-beta');

      expect(await previewCommand(command('beta')), hasLength(1));
    });
  });

  group('what it did', () {
    test('is reported faithfully — it did what it said it would', () async {
      makeRequisition('20260805-beta');

      final execution = await runCommand(command('beta'));

      expect(execution.isFaithful, isTrue);
      expect(execution.isComplete, isTrue);
    });
  });
}
