import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../sections/architecture.dart';
import '../sections/cli.dart';
import '../sections/ecosystem.dart';
import '../sections/monorepo.dart';
import '../sections/principles.dart';
import '../widgets/colophon.dart';

class Home extends StatelessComponent {
  const Home({super.key});

  @override
  Component build(BuildContext context) => Page(
    children: [
      Masthead(
        name: 'macss',
        tagline: 'Modular Architecture for Comprehensive Software Solutions',
        children: [
          p([
            .text('A software architecture methodology for development done '
                'with an AI agent. It defines layers with a single '
                'responsibility and a monorepo structure that gives the '
                'developer and the agent the same complete, unambiguous view '
                'of the system.'),
          ]),
        ],
      ),
      const Principles(),
      const Architecture(),
      const Monorepo(),
      const Cli(),
      const Ecosystem(),
      const Colophon(),
    ],
  );
}
