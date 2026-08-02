import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/specification/commands/check.dart';
import 'package:macss_cli/modules/specification/workspace.dart';

const _filledSpec = '''
# Specification

## 1. Commitment date

| Milestone          | Date       |
| ------------------ | ---------- |
| Committed delivery | 2026-08-15 |

## 2. User Stories

### US-1: Register an invoice

**As a** billing analyst,
**I want** to register an invoice,
**So that** records are never lost.

#### Acceptance Criteria

| #    | Given            | When           | Then            |
| ---- | ---------------- | -------------- | --------------- |
| AC-1 | the form is open | I submit data  | it is stored    |

## 3. Explicit Scope

### Includes

- The registration form.

### Does NOT include

- The approval workflow.

## 4. Domain and business rules

- **Glossary:** an *invoice* is a billing document with a unique number.
''';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('macss_spec_check_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void writeSpec(String slug, String content) {
    final f = File(p.join(tempDir.path, 'requisitions', slug, 'specification.md'));
    f.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  void writeIssue(String slug, String name, {String covers = 'US1-AC1'}) {
    File(p.join(tempDir.path, 'requisitions', slug, name))
      ..createSync(recursive: true)
      ..writeAsStringSync('# issue\n\nCovers $covers.\n');
  }

  SpecificationCheckCommand cmd(String? slug) => SpecificationCheckCommand(
        SpecificationCheckInput(slug: slug),
        workingDirectory: tempDir.path,
        assets: Assets(root: Directory.current.path),
      );

  group('SpecificationCheckCommand', () {
    test('passes (exit 0) for a filled spec', () async {
      writeSpec('ok', _filledSpec);
      writeIssue('ok', 'issue-ok.md');

      final out = await cmd('ok').execute();
      expect(out.exitCode, 0);
      expect(out.message.toLowerCase(), contains('ready'));
    });

    test('fails (non-zero) and lists violation codes for an incomplete spec',
        () async {
      // A contract with no committed date is not a contract: the date is what
      // the Product Owner accepts alongside the acceptance criteria.
      writeSpec('bad', _filledSpec.replaceAll(RegExp(r'\d{4}-\d{2}-\d{2}'), ''));

      final out = await cmd('bad').execute();
      expect(out.exitCode, isNot(0));
      expect(out.message, contains('SPEC_NO_COMMITMENT_DATE'));
    });

    test('validate fails when the specification.md is missing', () {
      expect(cmd('ghost').validate(), isNotNull);
    });



    test('checks the active requisition from the pointer (no --slug)', () async {
      final folder = '20260709-active';
      File(p.join(tempDir.path, 'docs', 'requisitions', folder,
          'specification.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync(_filledSpec);
      File(p.join(tempDir.path, 'docs', 'requisitions', folder, 'issue-a.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync('# issue\n\nCovers US1-AC1.\n');
      writeActiveRequisition(tempDir.path,
          slug: 'active',
          relDir: 'docs/requisitions/$folder',
          lang: 'en',
          isoDate: '2026-07-09');

      final out = await cmd(null).execute();
      expect(out.exitCode, 0);
      expect(out.message.toLowerCase(), contains('ready'));
    });
  });
}
