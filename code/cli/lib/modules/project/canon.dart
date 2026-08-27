/// What a MACSS project is made of, and how to tell whether one conforms.
///
/// This is the single definition of the canon documented in
/// `code/books/macss/src/es/project-structure.md`. `project create` stamps it,
/// `project check` verifies it, and `project adopt` fills its gaps — so the
/// three cannot disagree about what a MACSS project is. They used to: the book
/// required a root `CHANGELOG.md` that `create` never produced, and nothing
/// detected it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../src/checks.dart';

// ─── The canon ──────────────────────────────────────────────────────────────

/// A file every MACSS project carries, and the template it is stamped from.
class CanonFile {
  /// Repo-relative, posix-separated.
  final String path;

  /// Asset path, relative to `assets/`.
  final String template;

  const CanonFile(this.path, this.template);
}

/// The module anchors. Each README is the architectural signal of its layer and
/// makes the directory survive the first commit, since git ignores empty dirs.
/// The shape `project create` opens a new project on — **offered, not
/// required**.
///
/// `infra` / `db` / `api` / `app` is the most common way to articulate a
/// solution and a good default, which is why a new project starts there. It is
/// not what a MACSS project *is*: see [ADR 0011](../../../../docs/adr/0011-code-is-free.md).
/// `check` never asks for these and `adopt` never adds them, so a project that
/// does not need one deletes the directory and is done.
///
/// That leaves `create` stamping more than `check` requires. The reverse — the
/// canon demanding what `create` never produced — is the defect this module was
/// built to prevent, and it breaks a project the moment it is born. This
/// direction is only an offer that can be declined, and a test pins it: a
/// created project conforms, and so does the same project with all four
/// directories removed.
const starterLayers = <CanonFile>[
  CanonFile('code/infra/README.md', 'templates/project-base/code/infra/README.md'),
  CanonFile('code/db/README.md', 'templates/project-base/code/db/README.md'),
  CanonFile('code/api/README.md', 'templates/project-base/code/api/README.md'),
  CanonFile('code/app/README.md', 'templates/project-base/code/app/README.md'),
];

/// Architectural documentation. `docs/` holds decisions and overviews only;
/// code-level documentation lives next to the code.
const canonDocs = <CanonFile>[
  CanonFile(
    'docs/adr/0001-record-architecture-decisions.md',
    'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
  ),
  CanonFile('docs/architecture.md', 'templates/project-base/docs/architecture.md'),
  CanonFile('docs/roadmap.md', 'templates/project-base/docs/roadmap.md'),
];

/// Root files.
const canonRootFiles = <CanonFile>[
  CanonFile('README.md', 'templates/project-base/README.md'),
  // No root CHANGELOG. It was canon for a while and no project ever filled
  // one — not across 25 releases of inquiry nor 10 of macss — because in a
  // project whose deliverable is one package, the package's own changelog is
  // the delivery history, and a second one at the root only restates it and
  // drifts. What was stamped was a header promising "all notable changes are
  // documented in this file" above nothing, in the first place a reader looks.
  // A project that ships several versioned artifacts may want such a file;
  // that is its judgement to make, not a rule to stamp.
  CanonFile('.gitignore', 'templates/project-base/.gitignore'),
  CanonFile('.gitattributes', 'templates/project-base/.gitattributes'),
];

/// Everything a canonical project carries, in stamping order.
const canonFiles = <CanonFile>[
  ...canonDocs,
  ...canonRootFiles,
];

/// What `project create` writes: the canon, plus the starting shape.
const createFiles = <CanonFile>[...canonFiles, ...starterLayers];

/// Client surfaces that mirror the backend's modules by name.
const canonClientLayers = <String>['app', 'cli'];

// ─── Inspection ─────────────────────────────────────────────────────────────

/// Inspects [root] against the canon.
///
/// Returns one check per rule. A **missing** canonical file is an `error`: it is
/// required and `project adopt` can create it. Anything **extra or deviating**
/// is a `warning`: it needs human judgement, so no command will act on it.
List<DoctorCheck> inspectProject(String root) => [
      ...canonFiles.map((f) => _fileCheck(root, f)),
      // No check over the *contents* of `code/`. Nothing there is required and
      // nothing there deviates — a project articulates its own solution (ADR
      // 0011). What survives is relational: it asks whether a pattern the
      // project chose is internally consistent, and says nothing to a project
      // that did not choose it.
      ..._moduleMirrorChecks(root),
      ..._documentationBoundaryChecks(root),
    ];

/// The canonical files absent from [root] — exactly what `adopt` would create.
List<CanonFile> missingCanonFiles(String root) => canonFiles
    .where((f) => !File(p.join(root, p.joinAll(f.path.split('/')))).existsSync())
    .toList(growable: false);

DoctorCheck _fileCheck(String root, CanonFile file) {
  final exists =
      File(p.join(root, p.joinAll(file.path.split('/')))).existsSync();
  return DoctorCheck(
    name: file.path,
    status: exists ? CheckStatus.ok : CheckStatus.error,
    detail: exists ? 'present' : 'missing',
    remediation: exists ? null : 'Run: macss project adopt --lang <en|es> --apply',
  );
}

/// "If `api/modules/X` exists, `db/modules/X` must also exist", and "client
/// modules mirror backend modules by name" — two of the canon's invariants.
///
/// Reported as warnings: creating an empty mirror directory would satisfy the
/// letter of the rule while hiding the real question, which is whether that
/// module was meant to exist at all.
List<DoctorCheck> _moduleMirrorChecks(String root) {
  final apiModules = _modulesOf(root, 'api');
  if (apiModules.isEmpty) return const [];

  final checks = <DoctorCheck>[];

  for (final module in apiModules) {
    final hasDb = _modulesOf(root, 'db').contains(module);
    checks.add(
      DoctorCheck(
        name: 'db/modules/$module',
        status: hasDb ? CheckStatus.ok : CheckStatus.warning,
        detail: hasDb ? 'mirrors api' : 'api/modules/$module has no db module',
        remediation: hasDb
            ? null
            : 'Every api module needs its data module, or the api module '
                'belongs elsewhere',
      ),
    );
  }

  for (final layer in canonClientLayers) {
    for (final module in _modulesOf(root, layer)) {
      if (apiModules.contains(module)) continue;
      checks.add(
        DoctorCheck(
          name: 'code/$layer/modules/$module',
          status: CheckStatus.warning,
          detail: 'no api module of the same name',
          remediation:
              'Client modules mirror backend modules by name — rename it, or '
              'the backend module is missing',
        ),
      );
    }
  }

  return checks;
}

/// "Documentation is never mixed with code" — checked in its one unambiguous
/// form: a `docs/` directory nested inside a layer.
/// Applies to **whatever** `code/` contains, not to a list of known layer
/// names. That list is gone (ADR 0011), and its absence makes this rule
/// stronger: `code/site/docs` was never reported while the check only walked
/// `infra` / `db` / `api` / `app`.
List<DoctorCheck> _documentationBoundaryChecks(String root) {
  final code = Directory(p.join(root, 'code'));
  if (!code.existsSync()) return const [];

  final offenders = <String>[];
  for (final dir in code.listSync().whereType<Directory>()) {
    final layer = p.basename(dir.path);
    if (Directory(p.join(dir.path, 'docs')).existsSync()) {
      offenders.add('code/$layer/docs');
    }
  }

  return offenders
      .map(
        (path) => DoctorCheck(
          name: path,
          status: CheckStatus.warning,
          detail: 'documentation nested inside a layer',
          remediation:
              'Cross-cutting docs belong in the root docs/; code-level notes '
              'belong next to the code they describe',
        ),
      )
      .toList();
}

/// The module names declared under `code/<layer>/modules/`.
List<String> _modulesOf(String root, String layer) {
  final dir = Directory(p.join(root, 'code', layer, 'modules'));
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .toList()
    ..sort();
}
