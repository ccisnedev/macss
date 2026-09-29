import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/command_extraction.dart';
import 'support/memory_sink.dart';

/// Every `macss ...` invocation this repository suggests to a person or an
/// agent — a hint string a failed command prints, a doc comment, a shipped
/// asset (a skill, a README, an architecture doc) — must be one `cli_router`
/// 0.2.0 actually accepts.
///
/// `cli_router` 0.2.0 structurally rejects five shapes before any command
/// runs: an option that follows a positional operand
/// (`misplaced-option`, e.g. `requisition new demo --apply` instead of
/// `requisition new --apply demo`), a value an option does not accept
/// (`unexpected-value`), an option repeated (`repeated-option`), an option
/// the route does not declare (`unknown-option`), and a route that does not
/// exist at all (`unknown-command`).
///
/// This scans every source this repository ships for suggested command
/// lines — every Dart string literal under `lib/`, every shipped asset
/// (skills, templates), `README.md`, and the whole `docs/` tree — extracts
/// every `macss ...` invocation found there (see
/// `support/command_extraction.dart` for exactly how and what is excluded,
/// each exclusion documented against its own source), fills in its
/// placeholders with a sample value, and runs it, unconditionally and with
/// no pre-filtering, through `runMacss` — the CLI's own production entry
/// point, with every real module mounted. For any of the five rejection
/// kinds above, `ModularCli.run` short-circuits before dispatching to a
/// command, so this exercises exactly the same resolve-and-reject step a
/// direct call to `cli_router`'s `resolve` would.
///
/// A suggestion failing for an unrelated, expected reason (no active
/// requisition, not inside a project, an unknown `--host`) is fine: this
/// only guards against the CLI training its own users to type something the
/// parser refuses outright.
void main() {
  test(
    'every suggested macss command is accepted by the real router',
    () async {
      final root = _repoRoot();
      final suggestions = collectSuggestedCommands(root);

      expect(
        suggestions,
        isNotEmpty,
        reason: 'found no `macss ...` suggestion at all; the scan is broken',
      );

      final rejectedByTheParser = <String>[];
      var routerCalls = 0;

      for (final suggestion in suggestions) {
        final workspace = Directory.systemTemp.createTempSync(
          'macss_suggestion_probe_',
        );
        final args = _neverInstall(toArgs(suggestion.raw));
        final stderrSink = MemorySink();
        var thrown = '';

        try {
          await runMacss(
            args,
            stdout: MemorySink().sink,
            stderr: stderrSink.sink,
            workingDirectory: workspace.path,
          );
        } on Object catch (e) {
          // A command can fail past the router for reasons this suite does
          // not care about — e.g. `project create` reading a template asset
          // that only exists next to an installed build, not in this test
          // run. That is a real, separate failure mode, but not one of the
          // five structural rejections below, so it must not abort the
          // whole scan; its text is still checked, in case a rejection ever
          // surfaces as a thrown error instead of stderr output.
          thrown = e.toString();
        } finally {
          routerCalls++;
          if (workspace.existsSync()) workspace.deleteSync(recursive: true);
        }

        final said = '${await stderrSink.text()}\n$thrown';
        if (said.contains('misplaced-option') ||
            said.contains('unexpected-value') ||
            said.contains('repeated-option') ||
            said.contains('unknown-option') ||
            said.contains('unknown-command')) {
          rejectedByTheParser.add('$suggestion  =>  $said');
        }
      }

      // Guards against exactly the failure mode that made an earlier
      // version of this test hollow: a pre-filter that discarded every
      // candidate before the router ever ran, leaving zero router calls
      // behind a passing test. Every extracted suggestion must reach the
      // router, with no filtering in between.
      expect(routerCalls, greaterThan(0));
      expect(routerCalls, greaterThanOrEqualTo(suggestions.length));

      expect(
        rejectedByTheParser,
        isEmpty,
        reason:
            'these suggestions are rejected by the real parser before the '
            'command they name ever runs:\n${rejectedByTheParser.join('\n')}',
      );
    },
  );
}

/// `code/cli` is two directories under the repository root.
String _repoRoot() => p.normalize(p.join(Directory.current.path, '..', '..'));

/// `upgrade` and `uninstall` act on the install directory of the running
/// executable, which under `dart test` is the Dart SDK itself. Their
/// suggestions are still parsed by the real router, but always in plan
/// mode: `--apply` becomes `--plan` and `--autoapprove` is dropped, so this
/// suite can never replace or delete anything outside its temp workspace.
List<String> _neverInstall(List<String> args) {
  final route = args.firstWhere((a) => !a.startsWith('-'), orElse: () => '');
  if (route != 'upgrade' && route != 'uninstall') return args;
  return [
    for (final a in args)
      if (a == '--apply') '--plan' else if (a != '--autoapprove') a,
  ];
}
