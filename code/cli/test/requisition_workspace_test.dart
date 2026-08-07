import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/specification/workspace.dart';

/// Resolving a requisition by name must never choose for the caller.
///
/// The date prefix makes folder *names* unique; it does not make slugs unique.
/// When two folders end in the same slug, the resolver used to sort them and
/// return the newest, silently — a default that invents a decision, which ADR
/// 0009 forbids and which this requirement's own words rule out: *"refuses and
/// shows the candidates rather than guessing."*
///
/// It is reachable from every command that takes `--slug`, not only from the two
/// this requirement adds.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_ws_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void makeRequisition(String folder) =>
      Directory(p.join(root.path, 'docs', 'requisitions', folder))
          .createSync(recursive: true);

  group('resolving one requisition by slug', () {
    test('a single match resolves', () {
      makeRequisition('20260804-demo');

      expect(resolveRequisitionDir(root.path, 'demo'),
          endsWith('20260804-demo'));
    });

    test('an exact folder name wins over a suffix match', () {
      makeRequisition('20260804-demo');
      makeRequisition('demo');

      expect(resolveRequisitionDir(root.path, 'demo'), endsWith('demo'));
      expect(resolveRequisitionDir(root.path, 'demo'),
          isNot(endsWith('20260804-demo')));
    });

    test('a slug matching nothing resolves to nothing', () {
      makeRequisition('20260804-demo');

      expect(resolveRequisitionDir(root.path, 'nothing-like-it'), isNull);
    });

    // The defect. Two requisitions opened on different days under one slug is
    // possible, and picking one of them is not the resolver's decision to make.
    test('two folders under one slug resolve to nothing at all', () {
      makeRequisition('20260804-demo');
      makeRequisition('20260806-demo');

      expect(resolveRequisitionDir(root.path, 'demo'), isNull,
          reason: 'choosing the newest would be inventing a decision');
    });

    test('the candidates are available to whoever has to report them', () {
      makeRequisition('20260804-demo');
      makeRequisition('20260806-demo');

      expect(requisitionsMatching(root.path, 'demo'),
          ['20260804-demo', '20260806-demo']);
    });

    test('one match is not ambiguity', () {
      makeRequisition('20260804-demo');

      expect(requisitionsMatching(root.path, 'demo'), hasLength(1));
    });
  });

  group('the failure a command reports', () {
    test('names every candidate when a slug is ambiguous', () {
      makeRequisition('20260804-demo');
      makeRequisition('20260806-demo');

      final failure = ambiguousRequisitionFailure(root.path, 'demo');

      expect(failure, isNotNull);
      expect(failure, contains('20260804-demo'));
      expect(failure, contains('20260806-demo'));
    });

    test('is silent when there is nothing ambiguous', () {
      makeRequisition('20260804-demo');

      expect(ambiguousRequisitionFailure(root.path, 'demo'), isNull);
      expect(ambiguousRequisitionFailure(root.path, 'absent'), isNull);
      expect(ambiguousRequisitionFailure(root.path, null), isNull);
    });
  });

  group('following the pointer', () {
    test('resolves the folder the pointer names', () {
      makeRequisition('20260804-demo');
      writeActiveRequisition(root.path,
          slug: 'demo',
          relDir: 'docs/requisitions/20260804-demo',
          isoDate: '2026-08-04');

      expect(resolveRequisitionDir(root.path), endsWith('20260804-demo'));
    });

    test('resolves to nothing when the pointer names a folder that is gone',
        () {
      writeActiveRequisition(root.path,
          slug: 'demo',
          relDir: 'docs/requisitions/20260804-demo',
          isoDate: '2026-08-04');

      expect(resolveRequisitionDir(root.path), isNull);
    });
  });
}
