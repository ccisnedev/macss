import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/requisition/commands/list.dart';
import 'package:macss_cli/modules/specification/workspace.dart';

/// The listing has one job beyond convenience: it must be believable.
///
/// The requisition puts it plainly — *"a listing that can drift from reality is
/// worse than no listing, because it is believed"*. So the tests that matter
/// here are not the ones checking that three rows appear; they are the ones
/// checking that the row marked `active` is the folder the commands actually
/// act on, and that a broken pointer is shown rather than tidied away.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_list_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A requisition on disk, in one of the three states the listing reports.
  void makeRequisition(
    String folder, {
    bool withSpecification = false,
    int? issue,
  }) {
    final dir = Directory(p.join(root.path, 'docs', 'requisitions', folder))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'requisition.md')).writeAsStringSync('# Requisition\n');
    if (withSpecification) {
      File(p.join(dir.path, 'specification.md'))
          .writeAsStringSync('# Specification\n');
    }
    File(p.join(dir.path, 'state.yaml')).writeAsStringSync(
      'title: "t"\nlabels: []\n'
      'state: ${issue == null ? 'opened' : 'published'}\n'
      '${issue == null ? '' : 'issue: $issue\n'}',
    );
  }

  void activate(String folder, String slug) => writeActiveRequisition(
        root.path,
        slug: slug,
        relDir: 'docs/requisitions/$folder',
        isoDate: '2026-08-06',
      );

  Future<RequisitionListOutput> list() =>
      RequisitionListCommand(RequisitionListInput(),
              workingDirectory: root.path)
          .execute();

  group('what it shows', () {
    test('every requisition in the project', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');
      makeRequisition('20260806-gamma');

      final out = await list();

      expect(out.entries, hasLength(3));
      expect(out.entries.map((e) => e.slug),
          containsAll(['alpha', 'beta', 'gamma']));
    });

    test('the slug without its date, and the date beside it', () async {
      makeRequisition('20260804-alpha');

      final entry = (await list()).entries.single;

      expect(entry.slug, 'alpha');
      expect(entry.folder, '20260804-alpha');
      expect(entry.toText(), contains('alpha'));
    });

    /// The state is what the commands recorded, not what the files imply. The
    /// two used to be the same answer badly: a `specification.md` on disk says
    /// the document was written, never that anybody else can read it.
    test('how far the work has got, and what carries it', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260806-gamma', withSpecification: true, issue: 31);

      final byslug = {for (final e in (await list()).entries) e.slug: e};

      expect(byslug['alpha']!.stage, 'opened');
      expect(byslug['alpha']!.issue, isNull);
      expect(byslug['gamma']!.stage, 'published');
      expect(byslug['gamma']!.issue, 31);
    });

    /// The fact `prune` will act on, displayed before anything acts on it: a
    /// destructive command whose criterion has never been shown is one nobody
    /// can audit before running it.
    test('the pull request beside the issue', () async {
      final dir = Directory(
          p.join(root.path, 'docs', 'requisitions', '20260807-delta'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'state.yaml')).writeAsStringSync(
          'title: "t"\nstate: delivered\nissue: 56\npr: 57\n');

      final entry = (await list()).entries.single;

      expect(entry.pr, 57);
      expect(entry.toText(), contains('#56'));
      expect(entry.toText(), contains('!57'));
      expect(entry.toJson()['pr'], 57);
    });

    /// A folder with no readable record is **broken**, not empty, and the
    /// listing says so instead of leaving it out. It is the same rule the
    /// dangling pointer already follows: a listing that hides a broken state is
    /// how it becomes trusted and wrong — and this one decides what `prune`
    /// will eventually be allowed to destroy.
    test('a folder with no readable record is shown as unreadable', () async {
      makeRequisition('20260804-alpha');
      Directory(p.join(root.path, 'docs', 'requisitions', '20260805-broken'))
          .createSync(recursive: true);

      final out = await list();

      final broken =
          out.entries.firstWhere((e) => e.slug == 'broken');
      expect(broken.isReadable, isFalse);
      expect(out.toText(), contains('unreadable'));
    });

    test('a record whose state is a word nobody defined is unreadable too',
        () async {
      final dir =
          Directory(p.join(root.path, 'docs', 'requisitions', '20260805-typo'))
            ..createSync(recursive: true);
      File(p.join(dir.path, 'state.yaml'))
          .writeAsStringSync('title: "t"\nstate: dsicarded\n');

      final out = await list();

      expect(out.entries.single.isReadable, isFalse);
    });

    // The date column was removed: it existed to tell two rows apart, and the
    // order it carried is already given by the row position, since the folder's
    // date prefix is what sorts them. What it did cover was two requisitions
    // sharing a slug — possible in a project that already has them — so that
    // case brings the folder back, on those rows only.
    test('rows are the slug and nothing else when slugs are unique', () async {
      makeRequisition('20260804-alpha');

      expect(out(await list()).first, isNot(contains('20260804')));
    });

    test('two requisitions sharing a slug show which folder each is', () async {
      makeRequisition('20260804-dup');
      makeRequisition('20260806-dup');
      makeRequisition('20260805-alone');

      final lines = out(await list());

      expect(lines.where((l) => l.contains('20260804-dup')), hasLength(1));
      expect(lines.where((l) => l.contains('20260806-dup')), hasLength(1));
      expect(lines.firstWhere((l) => l.contains('alone')),
          isNot(contains('20260805')),
          reason: 'the unambiguous row stays clean');
    });

    test('a project with no requisitions says so', () async {
      final out = await list();

      expect(out.entries, isEmpty);
      expect(out.toText(), contains('No requisitions'));
    });
  });

  group('the active marker', () {
    test('marks exactly one row, and it is the one the pointer names',
        () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');
      activate('20260805-beta', 'beta');

      final out = await list();

      final marked = out.entries.where((e) => e.isActive).toList();
      expect(marked, hasLength(1));
      expect(marked.single.slug, 'beta');
    });

    test('the word active appears on that row and no other', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');
      activate('20260805-beta', 'beta');

      final lines = out(await list());

      expect(lines.where((l) => l.contains('active')), hasLength(1));
      expect(lines.firstWhere((l) => l.contains('active')), contains('beta'));
    });

    // The property the listing lives or dies by: it must agree with what the
    // commands act on. Asserted against the resolver rather than against text,
    // because comparing two code paths is the only way to show they cannot
    // drift apart.
    test('agrees with what the commands would act on', () async {
      makeRequisition('20260804-alpha');
      makeRequisition('20260805-beta');
      activate('20260805-beta', 'beta');

      final marked =
          (await list()).entries.firstWhere((e) => e.isActive);

      expect(resolveRequisitionDir(root.path), endsWith(marked.folder));
    });
  });

  group('states that are broken, and shown rather than hidden', () {
    test('a pointer naming a folder that is gone', () async {
      makeRequisition('20260804-alpha');
      activate('20260806-deleted', 'deleted');

      final out = await list();

      expect(out.entries.any((e) => e.isActive), isFalse,
          reason: 'no folder on disk can carry the marker');
      expect(out.toText(), contains('deleted'),
          reason: 'the broken pointer is information, not noise to omit');
    });

    test('nothing active at all is visible, not an oversight', () async {
      makeRequisition('20260804-alpha');

      final out = await list();

      expect(out.entries.any((e) => e.isActive), isFalse);
      expect(out.toText(), contains('none is active'));
    });
  });
}

List<String> out(RequisitionListOutput o) =>
    (o.toText() ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
