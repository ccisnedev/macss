/// The project's own configuration: `.macss/config.yaml`.
///
/// One key today, and deliberately one — the language every document in the
/// project is written in. It grows with evidence rather than with keys imagined
/// in advance, the same discipline by which `diagnosis check` was left unwritten.
///
/// **It is the one thing in `.macss/` that is versioned.** Everything else there
/// is machine-written and reproducible; a project's language is a decision a
/// human made, and it has to be the same for everyone who clones. The
/// workspace's own allowlist names it as an exception for exactly that reason.
///
/// **There is no default.** A project that never declared a language does not
/// have one, and answering "English" on its behalf would be inventing a choice
/// the caller was entitled to make — which ADR 0009 forbids. Commands that need
/// a template stop and say so.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'workspace_dir.dart';

/// The file, relative to a project root.
const projectConfigPath = '$workspaceDirName/config.yaml';

/// The language this project's documents are written in, or null when it has
/// not declared one.
String? projectLanguage(String root) {
  final file = File(p.join(root, workspaceDirName, 'config.yaml'));
  if (!file.existsSync()) return null;

  final match = RegExp(r'^language:\s*(\S+)\s*$', multiLine: true)
      .firstMatch(file.readAsStringSync());
  return match?.group(1);
}

/// Declares [language] as the project's, creating the workspace if needed.
///
/// Rewrites rather than appends: two declarations would be two answers, and a
/// project that answers differently on Tuesday does not have an answer.
void writeProjectConfig(String root, {required String language}) {
  final dir = ensureWorkspace(root);
  File(p.join(dir.path, 'config.yaml')).writeAsStringSync(
    '# MACSS — this project\'s configuration. Versioned: the answer travels\n'
    '# with the repository rather than living on one machine.\n'
    'language: $language\n',
  );
}

/// The usage error for a project that has not declared a language, or null when
/// it has.
///
/// One message, shared by every command that needs a template. A project opened
/// before this existed and a directory that is not a MACSS project at all are
/// the same fact from the command's side — there is nothing to resolve a
/// template with — so they are not told apart.
String? undeclaredLanguageFailure(String root) {
  if (projectLanguage(root) != null) return null;

  return 'This project does not declare a language, so there is no way to know '
      'which template to write.\n'
      'Declare it once:\n'
      '  macss project adopt --lang <en|es> --apply';
}
