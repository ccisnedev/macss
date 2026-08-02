import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/specification/specification_gate.dart';
import 'package:macss_cli/src/vocabulary.dart';
import 'package:macss_cli/templates/template_resolver.dart';

/// Templates and vocabulary are two halves of the same contract: the gate looks
/// for the words the vocabulary declares, and the templates are what a person
/// fills in. If they drift, the gate reports "no user stories" on a document
/// that plainly has them.
///
/// This enumerates the shipped languages rather than listing them, so a language
/// added tomorrow must bring both halves or fail here.
void main() {
  final assets = Assets(root: Directory.current.path);
  final resolver = TemplateResolver(assets);
  final vocabularies = Vocabularies.fromAssets(assets);
  final languages = assets.listDirectoryFiles('vocabulary');

  group('every shipped language has both halves', () {
    for (final lang in languages) {
      test('$lang: the specification template speaks its own vocabulary', () {
        final template = resolver.resolve('specification', lang: lang).content;
        final v = vocabularies.forLanguage(lang)!;

        // The bold marker matters: the gate matches `**Como`, not a bare
        // "Como" that could appear in ordinary prose.
        expect(template, contains('**${v.storyRole}'),
            reason: 'story role label missing from the $lang template');
        expect(template, contains('**${v.storyWant}'));
        expect(template, contains('**${v.storyBenefit}'));
        expect(template, contains(v.scopeIncludes));
        expect(template, contains(v.scopeExcludes));
      });

      test('$lang: the requisition template ships', () {
        final template = resolver.resolve('requisition', lang: lang);
        expect(template.content.trim(), isNotEmpty);
        expect(template.notice, isNull,
            reason: '$lang fell back to another language');
      });
    }
  });

  group('the Spanish templates carry no English labels', () {
    // The Spanish specification used to embed `**As a (Como)**` so a single
    // English matcher would find the line in either language. A Product Owner
    // reading that form saw two languages mixed for no reason he could see.
    test('the story labels are Spanish only', () {
      final template = resolver.resolve('specification', lang: 'es').content;

      for (final english in ['**As a', '**I want', '**So that']) {
        expect(template, isNot(contains(english)),
            reason: 'the vocabulary makes embedding English unnecessary');
      }
    });

    test('the requisition speaks of situación, not AS-IS', () {
      final template = resolver.resolve('requisition', lang: 'es').content;

      expect(template, contains('Situación actual'));
      expect(template, contains('Situación deseada'));
      expect(template, isNot(contains('AS-IS')));
      expect(template, isNot(contains('TO-BE')));
    });
  });

  group('the requisition asks for value', () {
    for (final lang in languages) {
      test('$lang: the three questions only the requester can answer', () {
        final template = resolver.resolve('requisition', lang: lang).content;

        // Three short questions -- a longer form is a form that does not get
        // filled. The fourth, the observable signal, is engineering work and
        // lives in the specification.
        final questions = RegExp(r'^\*\*.+\?\*\*$', multiLine: true)
            .allMatches(template)
            .length;
        expect(questions, 3, reason: 'expected exactly three value questions');
      });

      test('$lang: the specification asks how we will know it worked', () {
        final template = resolver.resolve('specification', lang: lang).content;
        expect(RegExp(r'^### .+\?$', multiLine: true).hasMatch(template), isTrue);
      });
    }
  });

  // The gate matched English-only story labels while the Spanish template had
  // stopped embedding them. Every unit test passed, because the fixture still
  // carried `**As a (Como)**` — a fixture that had drifted from what ships.
  //
  // This walks the SHIPPED template through the real gate, per language, so the
  // fixtures cannot mask it again.
  group('the shipped template passes the gate it was written for', () {
    final gate = SpecificationGate(vocabulary: vocabularies);

    for (final lang in languages) {
      test('$lang: a filled shipped template has its stories found', () {
        final filled = resolver
            .resolve('specification', lang: lang)
            .content
            // Fill the story labels and the AC row the way a person would.
            .replaceAll(RegExp(r'<!--[^>]*-->'), 'contenido real')
            .replaceAll('| --- |', '| --- |');

        final codes =
            gate.evaluate(filled).violations.map((v) => v.code).toList();

        expect(codes, isNot(contains('SPEC_NO_USER_STORY')),
            reason: 'the $lang labels must be findable by the $lang vocabulary');
      });
    }
  });
}
