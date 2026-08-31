import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Nothing macss stamps into somebody else's project may name a host macss does
/// not own or has not checked.
///
/// The site once advertised `macss.dev`, which does not resolve, and so did the
/// README template. The site's version was embarrassing; the template's
/// **multiplied** — every project created with that release carried the dead
/// link into its own repository, in the first place a reader looks. It was
/// fixed by hand, and nothing stopped it coming back.
///
/// This is an **allowlist and not a reachability check**. Asking the network
/// whether a host answers makes the suite slow, flaky and dependent on being
/// online, and it would go red for an outage rather than for a mistake. What
/// actually went wrong was a host nobody had decided on appearing in shipped
/// content — so the test is that every host was decided on, once, in writing.
///
/// Adding one is editing the list below, which is the deliberate act the defect
/// lacked.
void main() {
  // Tests run from code/cli.
  final assets = Directory('assets');

  /// Every host that may appear in shipped content, and why it is here.
  const allowed = {
    // The project's own site. `macss.dev` was never registered.
    'macss.ccisne.dev',
    // GitHub's documentation, linked from the .gitattributes template.
    'docs.github.com',
  };

  /// `https://host/...` — the scheme and authority, nothing after it.
  final urlPattern = RegExp(r'https?://([a-zA-Z0-9.-]+)');

  /// Every (file, host) pair in the shipped assets.
  List<({String file, String host})> hostsInAssets() {
    final found = <({String file, String host})>[];

    for (final entity in assets.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      // Binaries carry no links, and reading them as text is meaningless.
      if (const ['.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf']
          .contains(p.extension(entity.path).toLowerCase())) {
        continue;
      }

      final relative = p.relative(entity.path, from: assets.path).replaceAll(r'\', '/');
      for (final match in urlPattern.allMatches(entity.readAsStringSync())) {
        found.add((file: relative, host: match.group(1)!));
      }
    }

    return found;
  }

  test('every host in a shipped asset was decided on', () {
    final undeclared = hostsInAssets().where((h) => !allowed.contains(h.host)).toList();

    expect(
      undeclared,
      isEmpty,
      reason: undeclared
          .map((h) => '${h.file} names ${h.host}, which is not in the allowlist. '
              'If it is correct, add it above with a line saying why. '
              'If it is a typo or a domain that was never registered, this is '
              'the defect this test exists for.')
          .join('\n'),
    );
  });

  test('the allowlist has no entry nothing uses', () {
    // A list that only ever grows stops describing anything. An entry left
    // behind by content that was deleted would quietly re-permit the host.
    final used = hostsInAssets().map((h) => h.host).toSet();
    expect(allowed.difference(used), isEmpty,
        reason: 'Allowed but unused — remove it.');
  });
}
