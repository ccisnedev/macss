import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Monorepo extends StatelessComponent {
  const Monorepo({super.key});

  @override
  Component build(BuildContext context) => Band(
    heading: 'Monorepo structure',
    children: [
      p([
        .text('Every MACSS project is one repository, and exactly one line in '
            'it is rigid: '),
        strong([.text('code lives under code/, documentation under docs/')]),
        .text('. That separation is the canon. What goes inside '),
        code([.text('code/')]),
        .text(' is the project’s own business.'),
      ]),
      const Listing(source: '''
project/
├── code/            → the canon ends here
├── docs/
│   ├── adr/          → architecture decision records
│   ├── architecture.md
│   └── roadmap.md
└── README.md'''),
      p([
        code([.text('macss project create')]),
        .text(' opens a project on four layers, because most software has '
            'them:'),
      ]),
      const Listing(source: '''
code/
├── db/    → SQL schemas, DDL scripts, repositories
├── api/   → use cases, endpoints, server
├── app/   → services, controllers, views
└── infra/ → CI, containers, environment config'''),
      p([
        .text('They are an offer and not a requirement. '),
        code([.text('macss project check')]),
        .text(' never asks for them and does not object to what it finds '
            'instead — a CLI, a documentation site, a book, an editor '
            'extension. '),
        a(
          href: 'https://github.com/ccisnedev/macss/blob/main/docs/adr/0011-code-is-free.md',
          [.text('ADR 0011')],
        ),
        .text(' says why: both projects meant to demonstrate the methodology '
            'broke the old rule in the same direction, and when that happens '
            'the rule is what is wrong.'),
      ]),
      p([
        .text('Inside '),
        code([.text('code/')]),
        .text(', business logic is organised as '),
        strong([.text('modules')]),
        .text(' — vertical slices grouping the use cases of one domain:'),
      ]),
      const Listing(source: '''
code/api/modules/
├── clients/   → create, list, get, update, delete
├── billing/   → invoice, payment, refund
└── inventory/ → stock, transfer, adjustment'''),
      p([
        .text('Each module declares its boundaries and its dependencies. One '
            'that needs to scale on its own can be extracted as a service '
            'without changing anything inside it.'),
      ]),
    ],
  );
}
