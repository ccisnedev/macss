import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/specification/specification_gate.dart';
import 'package:macss_cli/src/vocabulary.dart';

/// A fully-filled specification that satisfies every rule.
const _filledSpec = '''
# Requirement Specification

## Metadata

| Field | Value |
| ----- | ----- |
| ID    | REQ-2026-06-30-001 |
| Date  | 2026-06-30 |

## 1. Commitment date

| Milestone          | Date       |
| ------------------ | ---------- |
| Committed delivery | 2026-08-15 |

## 2. User Stories

### US-1: Register an invoice

**As a** billing analyst,
**I want** to register an invoice through a form,
**So that** records are never lost.

#### Acceptance Criteria

| #    | Given (context)        | When (action)     | Then (expected result) |
| ---- | ---------------------- | ----------------- | ---------------------- |
| AC-1 | the form is open       | I submit valid data | the invoice is stored |
| AC-2 | a duplicate number     | I submit it       | it is rejected         |

## 3. Explicit Scope

### Includes

- Invoice registration form with no-duplicate validation.

### Does NOT include

- Invoice approval workflow.

## 4. Domain and business rules

- **Glossary:** an *invoice* is a billing document identified by a unique number.
''';

/// A fully-filled Spanish (`--lang es`) specification — the gate must accept it
/// (section headers, scope subheadings and Decision/Evidence markers are all in
/// Spanish). Regression for the dogfood finding that the gate was English-only.
const _filledSpecEs = '''
# Especificación de Requerimiento

## Metadatos

| Campo | Valor |
| ----- | ----- |
| ID    | REQ-2026-06-30-001 |

## 1. Fecha de compromiso

| Hito                 | Fecha      |
| -------------------- | ---------- |
| Entrega comprometida | 2026-08-15 |

## 2. Historias de Usuario

### HU-1: Registrar una factura

**Como** analista de facturación,
**Quiero** registrar una factura desde un formulario,
**Para** no se pierdan registros.

#### Acceptance Criteria

| #    | Given (Dado que)   | When (Cuando)        | Then (Entonces)        |
| ---- | ------------------ | -------------------- | ---------------------- |
| AC-1 | el formulario abre | envío datos válidos  | la factura se almacena |

## 3. Alcance Explícito

### Incluye

- Formulario de registro de facturas.

### NO incluye

- El flujo de aprobación de facturas.

## 4. Dominio y reglas de negocio

- **Glosario:** una *factura* es un documento de facturación con número único.
''';

void main() {
  final gate = SpecificationGate(
    vocabulary: Vocabularies.fromAssets(Assets(root: Directory.current.path)),
  );

  group('SpecificationGate', () {

    test('the unfilled scaffold (template) is rejected with violations', () {
      final template =
          Assets(root: Directory.current.path)
              .loadString('artifacts/specification.template.en.md')
              .replaceAll('{{DATE}}', '2026-06-30');

      final r = gate.evaluate(template);
      expect(r.passed, isFalse);
      // Many things are unfilled — at minimum the AC, scope, decision, issue.
      expect(r.violations, isNotEmpty);
    });

    test('a fully-filled spec with one tracing issue passes', () {
      final r = gate.evaluate(_filledSpec);
      expect(r.passed, isTrue, reason: r.violations.join('\n'));
      expect(r.violations, isEmpty);
    });

    test('a fully-filled Spanish (--lang es) spec passes (bilingual gate)', () {
      final r = gate.evaluate(_filledSpecEs);
      expect(r.passed, isTrue, reason: r.violations.join('\n'));
      expect(r.violations, isEmpty);
    });

    test('a numeric AC column (header "AC", cell "1") still counts as an AC', () {
      // The templates say the id cell holds only the number; the story must
      // still be seen as having an acceptance criterion.
      final numericAc = _filledSpec
          .replaceAll('| AC-1 ', '| 1    ')
          .replaceAll('| AC-2 ', '| 2    ')
          .replaceAll('| # ', '| AC ');

      expect(gate.evaluate(numericAc).violations.map((v) => v.code),
          isNot(contains('SPEC_STORY_MISSING_AC')));
    });







    test('a user story with no acceptance criterion → SPEC_STORY_MISSING_AC', () {
      final noAc = _filledSpec.replaceAll(
        RegExp(r'\| AC-\d+ .*\n'),
        '',
      );
      final r = gate.evaluate(noAc);
      expect(r.violations.map((v) => v.code), contains('SPEC_STORY_MISSING_AC'));
    });

    test('an empty scope half → SPEC_SCOPE_INCOMPLETE', () {
      final noExcludes = _filledSpec.replaceAll(
        '- Invoice approval workflow.',
        '<!-- what is explicitly out of scope -->',
      );
      final r = gate.evaluate(noExcludes);
      expect(r.violations.map((v) => v.code), contains('SPEC_SCOPE_INCOMPLETE'));
    });

    test('a lean charter without Testing or Decisions sections is still ready',
        () {
      // The spec is a business charter: testing moves to development (each AC is
      // already a Given-When-Then test), and technical decisions move to the
      // issues. Neither is gated any more.
      final r = gate.evaluate(_filledSpec);
      expect(r.passed, isTrue, reason: r.violations.join('\n'));
      expect(r.violations.map((v) => v.code),
          isNot(contains('SPEC_NO_TESTING_STRATEGY')));
      expect(r.violations.map((v) => v.code),
          isNot(contains('SPEC_DECISION_EVIDENCE_MISSING')));
    });

    test('no user story at all → SPEC_NO_USER_STORY', () {
      const empty = '# Specification\n\n## 2. User Stories\n';
      final r = gate.evaluate(empty);
      expect(r.violations.map((v) => v.code), contains('SPEC_NO_USER_STORY'));
    });

    test('no committed delivery date → SPEC_NO_COMMITMENT_DATE', () {
      // Strip the ISO date from §1 (leave the section, remove the real date).
      final noDate = _filledSpec.replaceAll('2026-08-15', '<!-- YYYY-MM-DD -->');
      final r = gate.evaluate(noDate);
      expect(r.passed, isFalse);
      expect(r.violations.map((v) => v.code),
          contains('SPEC_NO_COMMITMENT_DATE'));
    });

    test('a committed delivery date in §1 → no SPEC_NO_COMMITMENT_DATE', () {
      final r = gate.evaluate(_filledSpec);
      expect(r.violations.map((v) => v.code),
          isNot(contains('SPEC_NO_COMMITMENT_DATE')));
    });

  });

  group('the criterion ids the contract declares', () {
    /// The id is the join between the contract and the two documents that
    /// answer it — the delivery claims evidence per id, the verification is
    /// opened listing them unjudged. Generated in one place so the three cannot
    /// disagree about what a criterion is called.
    test('qualified by their story, in reading order', () {
      expect(gate.acIds(_filledSpec), isNotEmpty);
      expect(gate.acIds(_filledSpec).first, matches(RegExp(r'^US\d+-AC\d+$')));
    });

    test('a contract with no stories declares none', () {
      expect(gate.acIds('# Specification\n\n## 2. User Stories\n'), isEmpty);
    });

    /// Blank template rows are not criteria anybody agreed to, and the gate
    /// already ignores them when it decides whether a story is filled.
    test('unfilled rows are not criteria', () {
      final ids = gate.acIds(_filledSpec);
      expect(ids, everyElement(isNot(contains('AC0'))));
    });
  });
}
