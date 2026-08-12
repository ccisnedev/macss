/// The `delivery` gate — whether the claim is well formed.
///
/// It judges shape and coverage, never truth. It cannot tell whether the
/// evidence a row names is honest; what catches that is the person who writes
/// the verification, and that is where the signature was put on purpose.
library;

import 'package:test/test.dart';

import 'package:macss_cli/modules/delivery/delivery_gate.dart';

void main() {
  const gate = DeliveryGate();

  List<String> codesFor(
    String delivery, {
    List<String> criteria = const ['US1-AC1'],
    String? prTitle = 'feat(cli): something',
  }) =>
      gate
          .evaluate(delivery, criteria: criteria, prTitle: prTitle)
          .violations
          .map((v) => v.code)
          .toList();

  group('the pull request title', () {
    test('Conventional Commits shape passes', () {
      for (final title in const [
        'feat: a thing',
        'fix(cli): a thing',
        'feat(cli)!: a breaking thing',
        'refactor(workspace)!: the pointer is named for what it points at',
      ]) {
        expect(codesFor(_delivery, prTitle: title),
            isNot(contains('DELIVERY_PR_TITLE_MALFORMED')),
            reason: '"$title" should parse');
      }
    });

    test('anything else does not', () {
      for (final title in const [
        'a thing',
        'feat a thing',
        'feat():  ',
        ': nothing before the colon',
      ]) {
        expect(codesFor(_delivery, prTitle: title),
            contains('DELIVERY_PR_TITLE_MALFORMED'),
            reason: '"$title" should not parse');
      }
    });

    /// Shape, not vocabulary. A closed list of types would be this gate
    /// deciding what kinds of change a project may make.
    test('an unfamiliar type is still a type', () {
      expect(codesFor(_delivery, prTitle: 'perf(api): fewer round trips'),
          isNot(contains('DELIVERY_PR_TITLE_MALFORMED')));
    });

    test('no title at all is reported as missing, not as malformed', () {
      final codes = codesFor(_delivery, prTitle: null);
      expect(codes, contains('DELIVERY_PR_TITLE_MISSING'));
      expect(codes, isNot(contains('DELIVERY_PR_TITLE_MALFORMED')));
    });
  });

  group('every criterion is claimed, with somewhere to look', () {
    test('a criterion the contract declares and the delivery omits', () {
      final codes = codesFor(_delivery, criteria: ['US1-AC1', 'US2-AC7']);
      expect(codes, contains('DELIVERY_AC_UNCLAIMED'));
    });

    test('all of them present passes', () {
      expect(codesFor(_twoCriteria, criteria: ['US1-AC1', 'US1-AC2']),
          isEmpty);
    });

    /// The id alone is not a claim. "US1-AC1 | done" says nothing a reader can
    /// open, and the whole point of the row is to save them the search.
    test('a criterion named with no evidence beside it', () {
      expect(codesFor(_noEvidence), contains('DELIVERY_AC_NO_EVIDENCE'));
    });

    test('a contract that declares nothing is not a delivery to judge', () {
      expect(codesFor(_delivery, criteria: const []),
          contains('DELIVERY_NO_CRITERIA'));
    });
  });
}

const _delivery = '''
# Delivery

## 1. Every criterion, and where its evidence is

| Criterion | Where the evidence is |
| --------- | --------------------- |
| US1-AC1   | delivery_gate_test.dart: the shape passes |

## 2. What was not done, and why

- Nothing.
''';

const _twoCriteria = '''
# Delivery

## 1. Every criterion, and where its evidence is

| Criterion | Where the evidence is |
| --------- | --------------------- |
| US1-AC1   | a_test.dart: one |
| US1-AC2   | a_test.dart: two |
''';

const _noEvidence = '''
# Delivery

## 1. Every criterion, and where its evidence is

| Criterion | Where the evidence is |
| --------- | --------------------- |
| US1-AC1   | <!-- test name · file:line · command to run --> |
''';
