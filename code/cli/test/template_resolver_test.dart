import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/templates/template_resolver.dart';

void main() {
  final resolver = TemplateResolver(Assets(root: Directory.current.path));

  group('TemplateResolver', () {
    test('localized artifact: es returns the Spanish template, no notice', () {
      final r = resolver.resolve('specification', lang: 'es');
      expect(r.content, contains('# Especificación'));
      // Declares its language for derived artifacts (issues, etc.).
      expect(r.content, contains('macss:lang=es'));
      expect(r.notice, isNull);
    });

    test('localized artifact: en (default) returns English, no notice', () {
      final r = resolver.resolve('specification');
      expect(r.content, contains('# Specification'));
      expect(r.content, contains('macss:lang=en'));
      expect(r.notice, isNull);
    });

    test('localized artifact: an unsupported lang falls back to English + notice',
        () {
      final r = resolver.resolve('specification', lang: 'pt');
      expect(r.content, contains('# Specification'));
      expect(r.notice, contains('pt'));
      expect(r.notice, contains('English'));
    });

    test('unknown artifact throws', () {
      expect(() => resolver.resolve('bogus'), throwsArgumentError);
    });
  });

  // The third lookup tier — `<artifact>.template.md`, with no language segment.
  // No shipped MACSS artifact uses it today (all are bilingual), so it is
  // exercised against a synthetic assets tree rather than a real template.
  group('TemplateResolver language-neutral tier', () {
    late Directory tempDir;
    late TemplateResolver neutralResolver;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_resolver_test_');
      final artifacts = Directory(p.join(tempDir.path, 'assets', 'artifacts'));
      artifacts.createSync(recursive: true);
      File(p.join(artifacts.path, 'neutral.template.md'))
          .writeAsStringSync('# Neutral');
      neutralResolver = TemplateResolver(Assets(root: tempDir.path));
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('en returns the no-lang template, no notice', () {
      final r = neutralResolver.resolve('neutral', lang: 'en');
      expect(r.content, contains('# Neutral'));
      expect(r.notice, isNull);
    });

    test('a requested lang falls back to it, with a notice', () {
      final r = neutralResolver.resolve('neutral', lang: 'es');
      expect(r.content, contains('# Neutral'));
      expect(r.notice, contains('es'));
    });
  });
}
