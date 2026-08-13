import 'dart:io';

import 'package:macss_cli/src/scaffold_document.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/commands/new.dart';
import 'package:macss_cli/modules/specification/commands/new.dart';
import 'package:macss_cli/src/project_config.dart';
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

  Future<void> openRequisition({String lang = 'es'}) {
    writeProjectConfig(tempDir.path, language: lang);
    return applyCommand(
      RequisitionNewCommand(
        RequisitionNewInput(slug: 'demo'),
        resolver: resolver,
        workingDirectory: tempDir.path,
        now: clock,
      ),
    );
  }

  ScaffoldDocumentCommand contractCommand() => specificationNewCommand(
    SpecificationNewInput(),
    resolver: resolver,
    workingDirectory: tempDir.path,
    now: clock,
  );

  Future<SpecificationNewOutput> addContract() async =>
      await applyCommand(contractCommand());

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

    test('is written in the language the project declared', () async {
      // A Spanish project should not yield an English contract.
      await openRequisition(lang: 'es');

      await addContract();

      expect(file('$folder/specification.md').readAsStringSync(),
          contains('Historias de Usuario'));
    });

    // There is no `--lang` to override it with. A contract written in a
    // language the project does not speak is not a contract anyone will read,
    // and the per-invocation flag was the only way to produce one.
    test('takes no --lang to write against the project with', () {
      expect(
        specificationNewParams.map((p) => p.name),
        isNot(contains('lang')),
      );
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

      expect(out.kept, isTrue);
      expect(
          file('$folder/specification.md').readAsStringSync(), 'WRITTEN BY QA');
    });

    // It used to short-circuit before the plan was built, so `--plan` on a
    // requisition that already had a contract said nothing at all. The step
    // answers now, and says `keep`.
    test('says it would keep an existing contract, rather than staying silent',
        () async {
      await openRequisition();
      await addContract();

      final previews = await previewCommand(contractCommand());

      expect(previews.single.verb, 'keep');
      expect(previews.single.target, endsWith('specification.md'));
    });

    test('output names the file and the next step', () async {
      await openRequisition();

      final out = await addContract();

      expect(out.toText(), contains('specification.md'));
      expect(out.toText(), contains('specification check'));
    });

    test('refuses to write a contract with nothing to contract about', () {
      // No requisition open: there is no request to turn into an agreement.
      expect(contractCommand().validate(), contains('requisition new'));
    });

    // The project must have said which language it speaks. There is nothing
    // to fall back on, and English is not a safe assumption — it is a guess.
    test('refuses to write a contract where no language is declared', () async {
      await openRequisition();
      File(p.join(tempDir.path, '.macss', 'config.yaml')).deleteSync();

      expect(
        contractCommand().validate(),
        contains('macss project adopt --lang <en|es>'),
      );
    });
  });
}
