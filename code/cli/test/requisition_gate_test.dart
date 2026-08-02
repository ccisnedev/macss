import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/requisition_gate.dart';
import 'package:macss_cli/templates/template_resolver.dart';

/// The requisition is a form filled by the Product Owner. This gate answers one
/// question: did he actually fill it, or is it still the blank we handed over?
///
/// It deliberately judges presence, not quality. No gate can tell a considered
/// answer from a pretty phrase — what catches vapour is that QA has to turn the
/// stated value into an observable signal during analysis.
void main() {
  final assets = Assets(root: Directory.current.path);
  final resolver = TemplateResolver(assets);
  final gate = RequisitionGate();

  /// The shipped template with every answer slot filled.
  String filled(String lang, {String? answer}) {
    final blank = resolver.resolve('requisition', lang: lang).content;
    return blank
        .replaceAll('<!-- Su respuesta aquí -->', answer ?? 'Una respuesta real.')
        .replaceAll('<!-- Your answer here -->', answer ?? 'A real answer.');
  }

  for (final lang in assets.listDirectoryFiles('vocabulary')) {
    group('the shipped $lang template', () {
      test('fails every rule while it is still blank', () {
        final result =
            gate.evaluate(resolver.resolve('requisition', lang: lang).content);

        expect(result.passed, isFalse);
        expect(
          result.violations.map((v) => v.code),
          containsAll(<String>[
            'REQ_NO_VALUE',
            'REQ_NO_CURRENT_STATE',
            'REQ_NO_DESIRED_STATE',
          ]),
        );
      });

      test('passes once it is filled', () {
        final result = gate.evaluate(filled(lang));
        expect(result.passed, isTrue, reason: result.violations.join('\n'));
      });
    });
  }

  group('rules', () {
    test('an example left untouched does not count as an answer', () {
      // The template ships an example blockquote under each question. Copying
      // the form without answering must not pass.
      final blank = resolver.resolve('requisition', lang: 'es').content;
      expect(gate.evaluate(blank).passed, isFalse);
    });

    test('a comment does not count as an answer', () {
      final withComments = filled('es', answer: '<!-- pendiente -->');
      final codes = gate.evaluate(withComments).violations.map((v) => v.code);
      expect(codes, contains('REQ_NO_VALUE'));
    });

    test('answering only some of the questions still fails', () {
      final partial = resolver
          .resolve('requisition', lang: 'es')
          .content
          .replaceFirst('<!-- Su respuesta aquí -->', 'Sólo la primera.');

      expect(gate.evaluate(partial).violations.map((v) => v.code),
          contains('REQ_NO_VALUE'));
    });

    test('sections are found by number, not by title', () {
      // Section titles differ per language; the numbers do not. That is what
      // lets one gate serve every language.
      const renamed = '''
# Solicitud

## 1. Cualquier título
Respuesta.

## 2. Otro título
Hoy funciona así.

## 3. Y otro
Debería funcionar asá.
''';
      expect(gate.evaluate(renamed).passed, isTrue);
    });

    test('a violation names its section so the fix is obvious', () {
      final result =
          gate.evaluate(resolver.resolve('requisition', lang: 'es').content);
      final value =
          result.violations.firstWhere((v) => v.code == 'REQ_NO_VALUE');

      expect(value.message, contains('1.'));
    });
  });
}
