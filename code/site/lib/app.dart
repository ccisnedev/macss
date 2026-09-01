import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'pages/home.dart';
import 'pages/modular_api.dart';

/// Two pages, pre-rendered.
///
/// No component here is annotated `@client`, so the router runs during the
/// build and not in a browser: each route becomes an HTML file and the links
/// between them are ordinary links.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) => Router(
    routes: [
      Route(
        path: '/',
        title: 'MACSS — Modular Architecture for Comprehensive Software Solutions',
        builder: (context, state) => const Home(),
      ),
      Route(
        path: '/modular-api',
        title: 'modular_api — the api layer of MACSS',
        builder: (context, state) => const ModularApi(),
      ),
    ],
  );
}
