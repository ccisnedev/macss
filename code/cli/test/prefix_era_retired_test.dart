import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

/// `migrate-skills` existed for one upgrade and is gone.
///
/// Before 0.12.0 macss proved ownership of a deployed skill with a `macss-`
/// filename prefix and kept no ledger. Those copies could not be adopted into
/// the ledger, because their frontmatter predated `license` and `metadata` and
/// R10.6 adopts only an identical hash — so they had to be removed before the
/// new deploy could create them. The route did that, once.
///
/// It declared its own retirement in its doc comment: *"This route is
/// temporary. It exists for one upgrade and is removed in 0.13.0."* A comment
/// is not a mechanism. A one-time migration that nobody deletes becomes a
/// permanent route that deletes files, kept alive by nothing but the fact that
/// removing it was never anybody's task.
void main() {
  test('the route is not offered', () async {
    final stdout = MemorySink();
    final stderr = MemorySink();

    final code = await runMacss(
      const ['help'],
      stdout: stdout.sink,
      stderr: stderr.sink,
    );

    expect(code, 0);
    expect(
      await stdout.text(),
      isNot(contains('migrate-skills')),
      reason: 'The prefix-era migration was due for removal in 0.13.0.',
    );
  });

  test('the command no longer exists', () async {
    final stdout = MemorySink();
    final stderr = MemorySink();

    final code = await runMacss(
      const ['migrate-skills', '--plan'],
      stdout: stdout.sink,
      stderr: stderr.sink,
    );

    expect(code, isNot(0), reason: 'Running it still succeeds.');
  });

  test('its source is deleted, not merely unregistered', () {
    // An unregistered command still compiles, still carries the code that
    // deletes directories, and is one line away from returning.
    expect(
      File('lib/modules/global/commands/migrate_skills.dart').existsSync(),
      isFalse,
    );
  });
}
