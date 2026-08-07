import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/specification/workspace.dart';

void main() {
  late Directory tempDir;
  String root() => tempDir.path;

  Directory mkReq(String rel) {
    final d = Directory(p.join(tempDir.path, p.joinAll(rel.split('/'))));
    d.createSync(recursive: true);
    return d;
  }

  setUp(() => tempDir = Directory.systemTemp.createTempSync('iq_ws_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('datedFolder / dateStamp', () {
    test('date stamp is compact YYYYMMDD, zero-padded', () {
      expect(dateStamp(DateTime(2026, 7, 9)), '20260709');
      expect(datedFolder('motores-fase-8', DateTime(2026, 12, 31)),
          '20261231-motores-fase-8');
    });
  });

  group('writeActiveRequisition / activeRequisitionPath', () {
    test('round-trips the active pointer', () {
      writeActiveRequisition(root(),
          slug: 'x',
          relDir: 'docs/requisitions/20260709-x',
          isoDate: '2026-07-09');
      expect(activeRequisitionPath(root()), 'docs/requisitions/20260709-x');
    });

    test('returns null when the pointer is absent', () {
      expect(activeRequisitionPath(root()), isNull);
    });
  });

  group('resolveRequisitionDir', () {
    test('no slug → follows the active pointer', () {
      final dir = mkReq('docs/requisitions/20260709-alpha');
      writeActiveRequisition(root(),
          slug: 'alpha',
          relDir: 'docs/requisitions/20260709-alpha',
          isoDate: '2026-07-09');
      expect(resolveRequisitionDir(root()), dir.path);
    });

    test('explicit slug → matches the dated folder', () {
      final dir = mkReq('docs/requisitions/20260709-beta');
      expect(resolveRequisitionDir(root(), 'beta'), dir.path);
    });

    test('explicit slug → exact (undated) folder also matches', () {
      final dir = mkReq('docs/requisitions/gamma');
      expect(resolveRequisitionDir(root(), 'gamma'), dir.path);
    });

    // This used to assert that the newest match wins. That was the resolver
    // choosing for the caller: the date prefix makes folder *names* unique, not
    // slugs, and picking one of two is a decision the caller is entitled to
    // make — forbidden by ADR 0009, and ruled out by #31's own words, *"refuses
    // and shows the candidates rather than guessing"*.
    test('multiple dated matches → nothing, so the caller can report both', () {
      mkReq('docs/requisitions/20260101-dup');
      mkReq('docs/requisitions/20261231-dup');

      expect(resolveRequisitionDir(root(), 'dup'), isNull);
      expect(requisitionsMatching(root(), 'dup'),
          ['20260101-dup', '20261231-dup']);
    });

    test('falls back to legacy repo-root requisitions/<slug>/', () {
      final dir = mkReq('requisitions/legacy');
      expect(resolveRequisitionDir(root(), 'legacy'), dir.path);
    });

    test('returns null when nothing matches', () {
      expect(resolveRequisitionDir(root(), 'missing'), isNull);
      expect(resolveRequisitionDir(root()), isNull);
    });
  });
}
