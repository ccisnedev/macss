import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/commands/new.dart';
import 'package:macss_cli/modules/requisition/issue_metadata.dart';
import 'package:macss_cli/modules/specification/commands/new.dart';
import 'package:macss_cli/src/plan_apply.dart';
import 'package:macss_cli/templates/template_resolver.dart';

/// `specification new` used to create the requisition **and** the specification
/// in one go. That collapsed a real distinction: the requisition is a form the
/// Product Owner fills, the specification is QA's contract — different authors,
/// different moments.
///
/// It now adds only the contract, to a requisition that already exists.
void main() {
  late Directory tempDir;
  late TemplateResolver resolver;

  DateTime clock() => DateTime(2026, 8, 2);
  const folder = 'docs/requisitions/20260802-demo';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_spec_new_');
    resolver = TemplateResolver(Assets(root: Directory.current.path));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File file(String relative) =>
      File(p.join(tempDir.path, p.joinAll(relative.split('/'))));

  Future<void> openRequisition({String lang = 'es'}) => RequisitionNewCommand(
        RequisitionNewInput(
          slug: 'demo',
          lang: lang,
          flags: const ChangeFlags(apply: true, autoapprove: true),
        ),
        resolver: resolver,
        workingDirectory: tempDir.path,
        now: clock,
      ).execute();

  Future<SpecificationNewOutput> addContract({String? lang}) =>
      SpecificationNewCommand(
        SpecificationNewInput(lang: lang),
        resolver: resolver,
        workingDirectory: tempDir.path,
        now: clock,
      ).execute();

  group('SpecificationNewCommand', () {
    test('adds the contract to the active requisition', () async {
      await openRequisition();

      await addContract();

      expect(file('$folder/specification.md').existsSync(), isTrue);
    });

    test('does not touch the requisition form', () async {
      await openRequisition();
      file('$folder/requisition.md').writeAsStringSync('FILLED BY THE PO');

      await addContract();

      expect(
          file('$folder/requisition.md').readAsStringSync(), 'FILLED BY THE PO');
    });

    test('inherits the language the requisition was opened in', () async {
      // A Spanish request should not yield an English contract.
      await openRequisition(lang: 'es');

      await addContract();

      expect(file('$folder/specification.md').readAsStringSync(),
          contains('Historias de Usuario'));
    });

    test('--lang overrides the inherited language', () async {
      await openRequisition(lang: 'es');

      await addContract(lang: 'en');

      expect(file('$folder/specification.md').readAsStringSync(),
          contains('User Stories'));
    });

    test('replaces the {{DATE}} placeholder with today', () async {
      await openRequisition();

      await addContract();

      final content = file('$folder/specification.md').readAsStringSync();
      expect(content, contains('2026-08-02'));
      expect(content, isNot(contains('{{DATE}}')));
    });

    test('is idempotent: an existing contract is never clobbered', () async {
      await openRequisition();
      await addContract();
      file('$folder/specification.md').writeAsStringSync('WRITTEN BY QA');

      final out = await addContract();

      expect(out.message, contains('kept'));
      expect(
          file('$folder/specification.md').readAsStringSync(), 'WRITTEN BY QA');
    });

    test('output names the file and the next step', () async {
      await openRequisition();

      final out = await addContract();

      expect(out.message, contains('specification.md'));
      expect(out.message, contains('specification check'));
    });

    test('refuses to write a contract with nothing to contract about', () {
      // No requisition open: there is no request to turn into an agreement.
      final cmd = SpecificationNewCommand(
        SpecificationNewInput(),
        resolver: resolver,
        workingDirectory: tempDir.path,
      );

      expect(cmd.validate(), contains('requisition new'));
    });

    test('the language comes from issue.yaml, not from a guess', () async {
      await openRequisition(lang: 'es');

      expect(
        IssueMetadata.read(p.dirname(file('$folder/x').path))!.lang,
        'es',
      );
    });
  });
}
