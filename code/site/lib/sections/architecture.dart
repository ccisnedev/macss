import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Architecture extends StatelessComponent {
  const Architecture({super.key});

  static const _layers = <(String, String)>[
    ('Interface', 'Presents information and captures interactions. A UI, or a CLI.'),
    ('Controller', 'Holds application state and orchestrates interface and services.'),
    ('Service', 'The transport between client and server. Abstracts HTTP away.'),
    ('API', 'Exposes endpoints and routes each request to a use case.'),
    ('UseCase', 'Business logic. Typed input and output, validate() then execute().'),
    ('Repository', 'Data access. Executes queries and commands.'),
    ('DB', 'Persistence, managed as Database as Code — DDL scripts, no ORMs.'),
  ];

  @override
  Component build(BuildContext context) => Band(
    heading: 'Layer architecture',
    children: [
      p([
        .text('Every request crosses layers that each do one thing, and the '
            'separation is enforced rather than encouraged: the interface never '
            'touches the database, business logic never knows about HTTP, and '
            'persistence never formats a response.'),
      ]),
      const Diagram(
        src: '/img/architecture.svg',
        alt: 'A sequence diagram of one request crossing the layers: user to '
            'interface, controller, service, API, use case, repository and '
            'database, and the response back along the same path.',
        caption: 'One request, and the layers it crosses',
      ),
      Rows(
        rows: [
          for (final (term, describes) in _layers) Row(term, [.text(describes)]),
        ],
      ),
      p([
        .text('The '),
        code([.text('api')]),
        .text(' and '),
        code([.text('app')]),
        .text(' layers have an implementation: '),
        a(href: '/modular-api', [.text('modular_api')]),
        .text(' provides the use-case lifecycle, CQRS routing, generated '
            'OpenAPI, health and metrics on the server, and transport-agnostic '
            'REST and GraphQL clients for the presentation layer.'),
      ]),
    ],
  );
}
