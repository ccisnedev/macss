/// The words the specification gate looks for, per language.
///
/// The gate used to carry these as Dart constants, in two different shapes: a
/// bilingual union for the scope headings (`['Includes', 'Incluye']`) and
/// English-only for the story labels — which is why the Spanish template had to
/// embed them as `**As a (Como)**`, so one matcher would find both. That mixture
/// is confusing for a Product Owner reading a Spanish form.
///
/// As assets, adding a language is one `<lang>.yaml` plus its templates: no code
/// changes, and the test suite covers it because the tests enumerate the
/// directory rather than listing languages.
///
/// Section numbers (`1.`, `2.`, …) are deliberately not here: they are already
/// language-independent, which is what lets a document be split before knowing
/// what language it is in.
library;

import 'package:yaml/yaml.dart';

import '../assets.dart';

/// One language's labels.
class Vocabulary {
  final String storyRole;
  final String storyWant;
  final String storyBenefit;
  final String scopeIncludes;
  final String scopeExcludes;

  const Vocabulary({
    required this.storyRole,
    required this.storyWant,
    required this.storyBenefit,
    required this.scopeIncludes,
    required this.scopeExcludes,
  });

  /// Parses a vocabulary document.
  ///
  /// Throws [FormatException] when a key is missing. A half-written vocabulary
  /// would make the gate stop finding stories in that language and report "no
  /// user stories" — a wrong answer is worse than an error.
  factory Vocabulary.fromYaml(String source) {
    final doc = loadYaml(source);
    if (doc is! Map) {
      throw const FormatException('Vocabulary must be a YAML mapping');
    }

    String read(String section, String key) {
      final group = doc[section];
      final value = group is Map ? group[key] : null;
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Vocabulary is missing "$section.$key"');
      }
      return value;
    }

    return Vocabulary(
      storyRole: read('story', 'role'),
      storyWant: read('story', 'want'),
      storyBenefit: read('story', 'benefit'),
      scopeIncludes: read('scope', 'includes'),
      scopeExcludes: read('scope', 'excludes'),
    );
  }
}

/// Every shipped vocabulary, and the unions the gate matches against.
///
/// The gate matches the **union** rather than one language: a document declares
/// its language, but a gate that only accepted the declared one would fail
/// confusingly on a document whose directive is missing or stale.
class Vocabularies {
  final Map<String, Vocabulary> byLanguage;

  const Vocabularies(this.byLanguage);

  /// Loads every `assets/vocabulary/<lang>.yaml`.
  factory Vocabularies.fromAssets(Assets assets) {
    final result = <String, Vocabulary>{};
    for (final lang in assets.listDirectoryFiles('vocabulary')) {
      result[lang] = Vocabulary.fromYaml(
        assets.loadString('vocabulary/$lang.yaml'),
      );
    }
    return Vocabularies(result);
  }

  /// The vocabulary for [language], or null when none ships for it.
  Vocabulary? forLanguage(String language) => byLanguage[language.toLowerCase()];

  List<String> _union(String Function(Vocabulary) field) =>
      byLanguage.values.map(field).toSet().toList()..sort();

  List<String> get storyRoles => _union((v) => v.storyRole);
  List<String> get storyWants => _union((v) => v.storyWant);
  List<String> get storyBenefits => _union((v) => v.storyBenefit);
  List<String> get scopeIncludes => _union((v) => v.scopeIncludes);
  List<String> get scopeExcludes => _union((v) => v.scopeExcludes);
}
