import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';

void main() {
  group('Assets', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_assets_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('path resolves under assets/', () {
      final assets = Assets(root: tempDir.path);
      final resolved = assets.path('templates/project-base/docs/architecture.md');
      expect(
        resolved,
        p.join(
          tempDir.path,
          'assets',
          'templates',
          'project-base',
          'docs',
          'architecture.md',
        ),
      );
    });

    test('loadString reads file content', () {
      final dir = Directory(p.join(tempDir.path, 'assets', 'templates'));
      dir.createSync(recursive: true);
      File(p.join(dir.path, 'test.md')).writeAsStringSync('# Test');

      final assets = Assets(root: tempDir.path);
      expect(assets.loadString('templates/test.md'), '# Test');
    });

    test('loadString throws FileSystemException for missing file', () {
      final assets = Assets(root: tempDir.path);
      expect(
        () => assets.loadString('nonexistent.md'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('fileExists returns true when file is present', () {
      final dir = Directory(p.join(tempDir.path, 'assets'));
      dir.createSync(recursive: true);
      File(p.join(dir.path, 'test.md')).writeAsStringSync('x');

      final assets = Assets(root: tempDir.path);
      expect(assets.fileExists('test.md'), isTrue);
    });

    test('fileExists returns false when file is missing', () {
      final assets = Assets(root: tempDir.path);
      expect(assets.fileExists('missing.md'), isFalse);
    });

    test('directoryExists returns true when dir is present', () {
      Directory(p.join(tempDir.path, 'assets', 'templates'))
          .createSync(recursive: true);
      final assets = Assets(root: tempDir.path);
      expect(assets.directoryExists('templates'), isTrue);
    });

    test('directoryExists returns false when dir is missing', () {
      final assets = Assets(root: tempDir.path);
      expect(assets.directoryExists('missing'), isFalse);
    });

    test('listDirectory returns immediate child dirs, sorted', () {
      final skills = p.join(tempDir.path, 'assets', 'skills', 'modules', 'lifecycle');
      for (final name in ['macss-plan', 'macss-analyze', 'macss-execute']) {
        Directory(p.join(skills, name)).createSync(recursive: true);
      }

      final assets = Assets(root: tempDir.path);
      expect(
        assets.listDirectory('skills/modules/lifecycle'),
        ['macss-analyze', 'macss-execute', 'macss-plan'],
      );
    });

    test('listDirectory ignores files', () {
      final skills = p.join(tempDir.path, 'assets', 'skills', 'modules', 'lifecycle');
      Directory(p.join(skills, 'macss-plan')).createSync(recursive: true);
      File(p.join(skills, 'README.md')).writeAsStringSync('x');

      final assets = Assets(root: tempDir.path);
      expect(assets.listDirectory('skills/modules/lifecycle'), ['macss-plan']);
    });

    test('listDirectory throws FileSystemException for missing dir', () {
      final assets = Assets(root: tempDir.path);
      expect(
        () => assets.listDirectory('missing'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('project-base templates exist in repo assets', () {
      // Verifies that the shipped templates are present in the source tree.
      // Assets root is two levels above bin/ — in tests we use cwd (code/cli/).
      final assets = Assets(root: Directory.current.path);
      expect(
        assets.fileExists(
          'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
        ),
        isTrue,
        reason: 'Run tests from code/cli/',
      );
      expect(
        assets.fileExists('templates/project-base/docs/architecture.md'),
        isTrue,
      );
      expect(
        assets.fileExists('templates/project-base/docs/roadmap.md'),
        isTrue,
      );
    });
  });
}
