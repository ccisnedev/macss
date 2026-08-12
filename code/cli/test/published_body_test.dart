/// The published issue body, and finding the contract inside it again.
///
/// The body is the assembly of two documents, and **both number their sections
/// `## 1.`, `## 2.`, `## 3.`** — the requisition's *Need and value* and the
/// specification's *Commitment date* are both "1.". Anything reading the body
/// back therefore has to be told where the contract starts, or it reads the
/// request as if it were the contract and never fails while doing it.
///
/// Splitting on `---` does not answer it: documents contain horizontal rules,
/// and the requisition template ships with tables and comments that could grow
/// one at any time.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/publisher.dart';
import 'package:macss_cli/modules/specification/specification_gate.dart';
import 'package:macss_cli/src/vocabulary.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('macss_body_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void write(String name, String content) =>
      File(p.join(dir.path, name)).writeAsStringSync(content);

  group('assembling the body', () {
    test('the request comes first, then the contract', () {
      write('requisition.md', _request);
      write('specification.md', _contract);

      final body = assembleBody(dir.path);

      expect(body.parts, ['requisition.md', 'specification.md']);
      expect(body.content.indexOf('Need and value'),
          lessThan(body.content.indexOf('Commitment date')));
    });

    test('a marker says where the contract starts', () {
      write('requisition.md', _request);
      write('specification.md', _contract);

      expect(assembleBody(dir.path).content, contains(specificationMarker));
    });

    test('no contract yet, no marker', () {
      write('requisition.md', _request);

      expect(assembleBody(dir.path).content,
          isNot(contains(specificationMarker)));
    });
  });

  group('reading the contract back out', () {
    test('the half after the marker is the contract, and it passes its gate',
        () {
      write('requisition.md', _request);
      write('specification.md', _contract);

      final contract = contractIn(assembleBody(dir.path).content)!;

      final gate = SpecificationGate(
          vocabulary: Vocabularies.fromAssets(Assets(root: '.')));
      expect(gate.evaluate(contract).passed, isTrue,
          reason: gate.evaluate(contract).violations.join('\n'));
      expect(contract, isNot(contains('Need and value')),
          reason: 'the request must not travel with the contract');
    });

    /// Bodies published before the marker existed cannot acquire one: the issue
    /// froze at its Definition of Ready, and re-publishing to add a marker is
    /// the edit the freeze forbids. So they are refused rather than guessed at
    /// — reading the request as the contract is the failure this exists to
    /// prevent, and it would not announce itself.
    test('a body with no marker is refused, not parsed', () {
      expect(contractIn('$_request\n\n---\n\n$_contract'), isNull);
    });
  });
}

const _request = '''
# Requisition

## 1. Need and value

Something is missing.

## 2. Current state

Nothing.
''';

const _contract = '''
# Specification

## 1. Commitment date

2026-09-01

## 2. User Stories

### US-1: Something worth building

- **As a** buyer
- **I want** to see my order
- **So that** I know it is coming

| AC  | Given (context) | When (action) | Then (expected result) |
| --- | --------------- | ------------- | ---------------------- |
| 1   | an order exists | I open it     | I see its state        |

## 3. Explicit Scope

### Includes

- Reading the order.

### Does NOT include

- Cancelling it.
''';
