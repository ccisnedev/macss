/// Shared helpers for the **requisitions workspace**.
///
/// Requisitions are historical documentation —like ADRs— so they live under
/// `docs/requisitions/` (the CLI is the *hands*; this centralizes
/// the one location every command agrees on). Each requisition folder is named
/// `<YYYYMMDD>-<slug>` so an alphabetical listing sorts **chronologically**
/// (the compact, hyphen-free date sorts cleanly and is good for ~7 more
/// millennia). The **active** requisition is recorded in
/// `.macss/active_requisition.yaml` so downstream commands (`issue new`,
/// `specification check`, `issue publish`) need not repeat the slug.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../src/workspace_dir.dart';

export '../../src/workspace_dir.dart' show workspaceDirName;

/// The two path segments under the project root where requisitions live.
const _base = ['docs', 'requisitions'];

/// The pointer's file name, under `.macss/`.
///
/// It says *which* requisition is being worked on — `slug`, `path`, `created` —
/// so it is a pointer and not a state. It carried the name `state.yaml` while
/// nothing else in the project held a state; the requisition's own state file
/// makes that name a second answer to a different question.
///
/// Named once because it is read in one place and written in another, and a
/// rename reaching only one of them would leave the two disagreeing in silence.
const activeRequisitionFileName = 'active_requisition.yaml';

/// Compact, hyphen-free date stamp that sorts chronologically: `YYYYMMDD`.
String dateStamp(DateTime now) =>
    now.year.toString().padLeft(4, '0') +
    now.month.toString().padLeft(2, '0') +
    now.day.toString().padLeft(2, '0');

/// The folder name for a new requisition: `<YYYYMMDD>-<slug>`.
String datedFolder(String slug, DateTime now) => '${dateStamp(now)}-$slug';

/// Absolute path of a requisition folder under `<root>/docs/requisitions/`.
String requisitionDir(String root, String folder) =>
    p.join(root, _base[0], _base[1], folder);

/// Repo-relative (posix) path of a requisition folder — for messages and the
/// active-requisition pointer.
String requisitionRelDir(String folder) => p.posix.join(_base[0], _base[1], folder);

/// The repo-relative (posix) path of the active requisition, read from
/// `.macss/active_requisition.yaml`, or null when the pointer is absent.
String? activeRequisitionPath(String root) {
  final f = File(p.join(root, workspaceDirName, activeRequisitionFileName));
  if (!f.existsSync()) return null;
  final m = RegExp(r'^path:\s*(.+)$', multiLine: true)
      .firstMatch(f.readAsStringSync());
  return m?.group(1)?.trim();
}

/// Resolves a requisition folder to an absolute path, or null when none exists.
///
/// With no [slug], it follows the active pointer (`.macss/active_requisition.yaml`).
/// With a [slug], it prefers a folder under `docs/requisitions/` whose name is
/// exactly `<slug>` or ends in `-<slug>` (the dated form; newest wins), then
/// falls back to the **legacy** repo-root `requisitions/<slug>/`.
String? resolveRequisitionDir(String root, [String? slug]) {
  if (slug == null || slug.isEmpty) {
    final rel = activeRequisitionPath(root);
    if (rel == null) return null;
    final dir = p.joinAll([root, ...p.posix.split(rel)]);
    return Directory(dir).existsSync() ? dir : null;
  }

  final base = Directory(p.join(root, _base[0], _base[1]));
  if (base.existsSync()) {
    final exact = p.join(base.path, slug);
    if (Directory(exact).existsSync()) return exact;

    // More than one folder can end in the same slug: the date prefix makes
    // folder *names* unique, not slugs. This used to sort them and return the
    // newest, which is inventing a decision the caller is entitled to make —
    // forbidden by ADR 0009. Ambiguity resolves to nothing; the caller reports
    // it with `ambiguousRequisitionFailure`.
    final dated = requisitionsMatching(root, slug);
    if (dated.length == 1) return p.join(base.path, dated.single);
  }

  final legacy = p.join(root, 'requisitions', slug);
  return Directory(legacy).existsSync() ? legacy : null;
}

/// Every requisition folder whose name ends in `-[slug]`, sorted.
///
/// Returns folder names rather than paths: they are what a person reads and
/// what a command shows when it refuses to choose between them.
List<String> requisitionsMatching(String root, String slug) {
  final base = Directory(p.join(root, _base[0], _base[1]));
  if (!base.existsSync()) return const [];

  return base
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .where((name) => name.endsWith('-$slug'))
      .toList()
    ..sort();
}

/// The usage error to report when [slug] names more than one requisition, or
/// null when it does not.
///
/// Every command taking `--slug` asks this before its own "not found" message,
/// so ambiguity is answered with the candidates instead of being resolved by
/// picking one. One implementation, so the six of them cannot disagree.
String? ambiguousRequisitionFailure(String root, String? slug) {
  if (slug == null || slug.isEmpty) return null;

  final candidates = requisitionsMatching(root, slug);
  if (candidates.length < 2) return null;

  return '"$slug" names ${candidates.length} requisitions:\n'
      '${candidates.map((c) => '  $c').join('\n')}\n'
      'Name one of them exactly with --slug.';
}

/// Records the **active** requisition in `.macss/active_requisition.yaml` so other
/// commands can resolve the folder without repeating the slug. Overwrites any
/// previous pointer (the newest `specification new` wins).
///
/// It is a pointer and nothing else. The language used to travel with it,
/// which made the pointer a place the language could be answered from — and a
/// second answer is a chance to disagree with `.macss/config.yaml`.
void writeActiveRequisition(
  String root, {
  required String slug,
  required String relDir,
  required String isoDate,
}) {
  // Through `ensureWorkspace`: the pointer and the plan files are two paths
  // into the same directory, and both must find it already ignoring itself.
  ensureWorkspace(root);
  File(p.join(root, workspaceDirName, activeRequisitionFileName))
      .writeAsStringSync(
    '# MACSS — active requisition pointer (local; git-ignored)\n'
    'slug: $slug\n'
    'path: $relDir\n'
    'created: $isoDate\n',
  );
}
