import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../widgets/colophon.dart';

class ModularApi extends StatelessComponent {
  const ModularApi({super.key});

  static const _quickstart = '''
dependencies:
  modular_api: ^1.0.0''';

  static const _server = '''
import 'package:modular_api/modular_api.dart';

Future<void> main() async {
  final api = ModularApi(
    basePath: '/api',
    title: 'My App',
    version: '1.0.0',
  );

  api.module('clients', (m) {
    m.usecase('create', CreateClient.fromJson);
    m.usecase('list',   ListClients.fromJson);
  });

  await api.serve(port: 8080);
}''';

  static const _calls = r'''
# Commands travel over REST
curl -X POST http://localhost:8080/api/clients/create \
  -H "Content-Type: application/json" \
  -d '{"name":"Acme"}'

# Queries travel over GraphQL, generated from the same use cases
# Docs   http://localhost:8080/docs
# Spec   http://localhost:8080/openapi.json''';

  static const _endpoints = <(String, String)>[
    ('/docs', 'Browsable documentation, generated from the use cases.'),
    ('/health', 'Liveness, with no configuration.'),
    ('/openapi.json', 'The specification, as a consequence of the code.'),
    ('/openapi.yaml', 'The same, for readers who prefer it.'),
    ('/metrics', 'Opt-in.'),
  ];

  @override
  Component build(BuildContext context) => Page(
    children: [
      nav(classes: 'back', [
        a(href: '/', [.text('← macss')]),
        span([.text(' / modular_api')]),
      ]),
      Masthead(
        name: 'modular_api',
        tagline: 'The api layer of MACSS, implemented',
        children: [
          p(classes: 'registries', [
            a(href: 'https://pub.dev/packages/modular_api', [.text('pub.dev')]),
            a(href: 'https://www.npmjs.com/package/@macss/modular-api', [.text('npm')]),
            a(href: 'https://pypi.org/project/macss-modular-api/', [.text('PyPI')]),
            a(href: 'https://github.com/ccisnedev/modular_api', [.text('GitHub')]),
          ]),
          p([
            .text('It is three things at once: a '),
            strong([.text('methodology')]),
            .text(' that is contract-first and use-case driven, a '),
            strong([.text('specification')]),
            .text(' of how modules, DTOs, repositories and use cases relate, '
                'and a set of '),
            strong([.text('SDKs')]),
            .text(' in three languages that produce structurally identical '),
            code([.text('openapi.json')]),
            .text(' from the same model.'),
          ]),
        ],
      ),
      Band(
        heading: 'Philosophy',
        children: [
          p([
            .text('Every operation is a '),
            strong([.text('UseCase')]),
            .text(' — typed '),
            code([.text('Input')]),
            .text(', typed '),
            code([.text('Output')]),
            .text(', a '),
            code([.text('validate()')]),
            .text(' step and an '),
            code([.text('execute()')]),
            .text(' step. Validation, business logic and HTTP stay apart '
                'because the framework has no layer that mixes them.'),
          ]),
          p([
            .text('CQRS is structural: commands travel over REST, queries '
                'over GraphQL. The OpenAPI specification and the GraphQL schema '
                'are generated from the use cases.'),
          ]),
          p([.text('Every server ships these, with no configuration:')]),
          Rows(
            rows: [
              for (final (term, describes) in _endpoints)
                Row(term, [.text(describes)]),
            ],
          ),
        ],
      ),
      Band(
        heading: 'Quick start',
        children: [
          p(classes: 'aside', [
            .text('Dart below. The same model is available in '),
            a(href: 'https://www.npmjs.com/package/@macss/modular-api', [.text('TypeScript')]),
            .text(' and '),
            a(href: 'https://pypi.org/project/macss-modular-api/', [.text('Python')]),
            .text('.'),
          ]),
          const Listing(caption: 'pubspec.yaml', source: _quickstart),
          const Listing(caption: 'bin/server.dart', source: _server),
          const Listing(caption: 'and then', source: _calls),
        ],
      ),
      const Colophon(),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.back').styles(
      margin: Margin.only(bottom: Space.stride),
      color: role('muted'),
      fontSize: Type.micro,
    ),
    css('.registries', [
      css('&').styles(
        display: Display.flex,
        flexWrap: FlexWrap.wrap,
        gap: Gap(row: Space.tight, column: Space.step),
        fontSize: Type.micro,
      ),
    ]),
    css('.aside').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
