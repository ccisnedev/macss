import 'dart:convert';

import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

void main() {
  group('macss help', () {
    test('lists every registered command from the SDK catalog', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['help'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      final out = await stdout.text();
      expect(code, 0);
      // SDK-rendered catalog: one source of help that cannot drift from the
      // set of registered commands.
      expect(out, contains('Global options:'));
      for (final route in const [
        'create',
        'doctor',
        'upgrade',
        'uninstall',
        'version',
        'api graphql compile',
        'specification new',
        'specification check',
        'skill deploy',
        'skill list',
        'skill remove',
        'skill doctor',
        'skill validate',
        'migrate-skills',
        'project create',
        'project check',
        'project adopt',
        'requisition export-template',
        'requisition new',
        'requisition check',
        'requisition publish',
        'specification publish',
        'dor check',
      ]) {
        expect(out, contains(route), reason: '$route must appear in help');
      }

      // Of the two documents, only the requisition is handed to somebody
      // outside the team, so only it has a blank form to export. The contract
      // is written on top of a request that already exists.
      expect(
        out,
        isNot(contains('specification export-template')),
        reason: 'the contract has no blank form to hand out',
      );
    });

    // Asked of the CLI's own catalogue rather than of the source, so a sixth
    // command that gains `--lang` tomorrow fails here without anyone
    // remembering the rule. `help --json` is what the CLI says it accepts.
    test('exactly three routes accept --lang, and none of them writes a '
        'document inside a project', () async {
      final stdout = MemorySink();
      final code = await runMacss(
        const ['help', '--json'],
        stdout: stdout.sink,
        stderr: MemorySink().sink,
      );
      expect(code, 0);

      final catalog = jsonDecode(await stdout.text()) as Map<String, dynamic>;
      final withLang = (catalog['commands'] as List)
          .cast<Map<String, dynamic>>()
          .where((c) => (c['params'] as List)
              .cast<Map<String, dynamic>>()
              .any((p) => p['name'] == 'lang'))
          .map((c) => c['route'] as String)
          .toSet();

      expect(
        withLang,
        equals({
          // Two kinds, and both are the moment the choice is made rather than
          // a repetition of it: `project create` and `project adopt` declare
          // the language *for the project*, once...
          'project create',
          'project adopt',
          // ...and `requisition export-template` states it for a single
          // document written where no project need exist, so there is nothing
          // to derive from. No command that writes a document *into* a project
          // appears here: they all derive it.
          'requisition export-template',
        }),
      );
    });

    // The catalogue is what a machine reads to learn how to call this CLI. A
    // parameter the command refuses to run without, declared `required: false`,
    // is the contract describing a behaviour the binary does not have — and the
    // reader who believes it is precisely the reader the JSON exists for.
    test('a parameter the command will not run without is declared required',
        () async {
      final stdout = MemorySink();
      final code = await runMacss(
        const ['help', '--json'],
        stdout: stdout.sink,
        stderr: MemorySink().sink,
      );
      expect(code, 0);

      final catalog = jsonDecode(await stdout.text()) as Map<String, dynamic>;
      final required = <String>{
        for (final c in (catalog['commands'] as List).cast<Map<String, dynamic>>())
          for (final p in (c['params'] as List).cast<Map<String, dynamic>>())
            if (p['required'] == true) '${c['route']} --${p['name']}',
      };

      expect(
        required,
        containsAll(const [
          // No default, and nothing to derive one from.
          'project create --path',
          'project create --lang',
          'project adopt --lang',
          'requisition export-template --lang',
        ]),
      );
    });

    test('normalizes --version and -v to the version command', () {
      expect(normalizeMacssArgs(const ['--version']), equals(const ['version']));
      expect(normalizeMacssArgs(const ['-v']), equals(const ['version']));
    });

    test('leaves --help for the SDK to route', () {
      expect(normalizeMacssArgs(const ['--help']), equals(const ['--help']));
      expect(normalizeMacssArgs(const ['-h']), equals(const ['-h']));
    });
  });
}
