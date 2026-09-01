/// Pre-rendering entry point. This site has no client half.
library;

import 'package:design_system/design_system.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    Document(
      title: 'MACSS — Modular Architecture for Comprehensive Software Solutions',
      meta: const {
        'description':
            'A software architecture methodology that structures projects as '
            'modules with single-responsibility layers, so a developer and an '
            'AI agent share complete, unambiguous context over the system.',
      },
      lang: 'en',
      styles: baseStyles(),
      body: const App(),
    ),
  );
}
