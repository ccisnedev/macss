import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:modular_cli_sdk/testing.dart';
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/dor/commands/check.dart';
import 'package:macss_cli/modules/dor/dor_builder.dart';
import 'package:macss_cli/modules/requisition/commands/new.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/specification/commands/new.dart';
import 'package:macss_cli/src/checks.dart';
import 'package:macss_cli/src/project_config.dart';
import 'package:macss_cli/templates/template_resolver.dart';

import 'support/memory_sink.dart';

/// DoR composes the stage checks and adds what neither owns. These tests walk
/// the requirement forward one step at a time, so each check is seen failing
/// for its own reason and then passing.
void main() {
  late Directory tempDir;
  late Assets assets;
  late TemplateResolver resolver;

  DateTime clock() => DateTime(2026, 8, 2);
  const folder = 'docs/requisitions/20260802-demo';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_dor_test_');
    assets = Assets(root: Directory.current.path);
    resolver = TemplateResolver(assets);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File file(String relative) =>
      File(p.join(tempDir.path, p.joinAll(relative.split('/'))));

  Future<void> openRequisition() {
    // The project declares its language once; every document derives from it.
    writeProjectConfig(tempDir.path, language: 'es');
    return applyCommand(RequisitionNewCommand(
      RequisitionNewInput(slug: 'demo'),
      resolver: resolver,
      workingDirectory: tempDir.path,
      now: clock,
    ));
  }

  Future<void> addContract() => applyCommand(SpecificationNewCommand(
        SpecificationNewInput(),
        resolver: resolver,
        workingDirectory: tempDir.path,
        now: clock,
      ));

  void fillForm() {
    final form = file('$folder/requisition.md');
    form.writeAsStringSync(form
        .readAsStringSync()
        .replaceAll('<!-- Su respuesta aquí -->', 'Una respuesta real.'));
  }

  /// A contract that satisfies every surviving rule.
  void fillContract() {
    file('$folder/specification.md').writeAsStringSync('''
# Especificación

## 1. Fecha de compromiso

| Hito                 | Fecha                |
| -------------------- | -------------------- |
| Entrega comprometida | 2026-09-15           |

## 2. Historias de Usuario

### HU-1: Consulta del estado del pedido

**Como** cliente registrado,
**Quiero** consultar el estado de mi pedido,
**Para** saber cuándo llegará.

| AC  | Dado que                | Cuando               | Entonces               |
| --- | ----------------------- | -------------------- | ---------------------- |
| 1   | Tiene un pedido activo  | Consulta su detalle  | Ve estado y fecha      |

## 3. Alcance Explícito

### Incluye

- Consulta de estado de pedidos activos.

### NO incluye

- Cancelación del pedido.
''');
  }

  void publish() {
    final dir = p.dirname(file('$folder/x').path);
    RequisitionRecord.read(dir)!.published(42).write(dir);
  }

  Future<DorCheckOutput> dor() => DorCheckCommand(
        DorCheckInput(),
        workingDirectory: tempDir.path,
        assets: assets,
      ).execute();

  DoctorCheck named(DorCheckOutput out, String name) =>
      out.checks.firstWhere((c) => c.name == name);

  group('macss dor check', () {
    test('a blank requisition fails on all three', () async {
      await openRequisition();

      final out = await dor();

      expect(out.ready, isFalse);
      expect(out.exitCode, ExitCode.validationFailed);
      expect(named(out, 'requisition').status, CheckStatus.error);
      expect(named(out, 'specification').detail, contains('no contract'));
      expect(named(out, 'issue').detail, 'not published');
    });

    test('a filled form clears its own check but not the others', () async {
      await openRequisition();
      fillForm();

      final out = await dor();

      expect(named(out, 'requisition').status, CheckStatus.ok);
      expect(out.ready, isFalse);
    });

    test('an unfilled contract reports its codes, not its prose', () async {
      // The stage check prints full messages; repeating them here would bury
      // the one thing DoR answers.
      await openRequisition();
      fillForm();
      await addContract();

      final specification = named(await dor(), 'specification');

      expect(specification.detail, contains('SPEC_'));
      expect(specification.remediation, contains('specification check'));
    });

    test('everything written but unpublished still fails on the issue',
        () async {
      await openRequisition();
      fillForm();
      await addContract();
      fillContract();

      final out = await dor();

      expect(named(out, 'requisition').status, CheckStatus.ok);
      expect(named(out, 'specification').status, CheckStatus.ok,
          reason: named(out, 'specification').detail);
      expect(named(out, 'issue').status, CheckStatus.error);
      expect(out.ready, isFalse,
          reason: 'a requirement with no home cannot be picked up');
    });

    test('published as well: the Definition of Ready is met', () async {
      await openRequisition();
      fillForm();
      await addContract();
      fillContract();
      publish();

      final out = await dor();

      expect(out.ready, isTrue, reason: out.toText());
      expect(out.exitCode, ExitCode.ok);
      expect(named(out, 'issue').detail, contains('#42'));
    });

    /// The gate writes the state it establishes, and takes neither `--plan` nor
    /// `--apply` to do it — a deliberate exception to ADR 0007, because a gate
    /// that must be told which of the two it is doing stops being runnable as a
    /// gate. What it writes is a record of an event: `ready` says the gate was
    /// passed, not that it would pass now.
    test('passing the gate records that the requisition is ready', () async {
      await openRequisition();
      fillForm();
      await addContract();
      fillContract();
      publish();

      final out = await dor();

      expect(out.ready, isTrue, reason: out.toText());
      final dir = p.dirname(file('$folder/x').path);
      expect(RequisitionRecord.read(dir)!.state, RequisitionState.ready);
    });

    test('failing it leaves the state where it was', () async {
      await openRequisition();
      fillForm();
      publish(); // no contract, so the gate cannot pass

      final out = await dor();

      expect(out.ready, isFalse);
      final dir = p.dirname(file('$folder/x').path);
      expect(RequisitionRecord.read(dir)!.state, RequisitionState.published,
          reason: 'a gate that did not pass has established nothing');
    });

    test('says the body is frozen once ready', () async {
      await openRequisition();
      fillForm();
      await addContract();
      fillContract();
      publish();

      expect((await dor()).toText(), contains('frozen'));
    });

    test('validate explains when there is no requisition at all', () {
      final cmd = DorCheckCommand(
        DorCheckInput(),
        workingDirectory: tempDir.path,
        assets: assets,
      );

      expect(cmd.validate(), contains('requisition new'));
    });
  });

  group('macss dor contract', () {
    test('rejects an undeclared option', () async {
      final stderr = MemorySink();
      final code = await (ModularCli()
            ..module('dor', (m) => buildDorModule(m, assets: assets)))
          .run(
        ['dor', 'check', '--bogus'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stderr.text(), contains('unknown option --bogus'));
    });
  });
}
