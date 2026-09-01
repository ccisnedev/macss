import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// What else there is, and where to get it.
///
/// Not a `Rows`, although it looks like one at a glance: the description here
/// is followed by a set of registry links, and folding those into a definition
/// would make the link list read as part of the sentence. Left as its own
/// markup, and recorded in the design system's journal as a candidate — one
/// page wanting a shape is not yet evidence of one.
class Ecosystem extends StatelessComponent {
  const Ecosystem({super.key});

  @override
  Component build(BuildContext context) => Band(
    heading: 'Ecosystem',
    children: [
      div(classes: 'eco', [
        div(classes: 'eco-row', [
          h3([a(href: '/modular-api', [.text('modular_api')])]),
          p([
            .text('The api layer, implemented. Use cases, CQRS, generated '
                'OpenAPI, health and metrics with no configuration.'),
          ]),
          p(classes: 'registries', [
            a(href: 'https://pub.dev/packages/modular_api', [.text('pub.dev')]),
            a(href: 'https://www.npmjs.com/package/@macss/modular-api', [.text('npm')]),
            a(href: 'https://pypi.org/project/macss-modular-api/', [.text('PyPI')]),
          ]),
        ]),
        div(classes: 'eco-row', [
          h3([.text('the macss CLI')]),
          p([
            .text('The delivery cycle, end to end. Scaffolds the structure, '
                'carries a requisition to a pull request, and runs the stage '
                'gates.'),
          ]),
          p(classes: 'registries', [
            a(href: 'https://github.com/ccisnedev/macss', [.text('GitHub')]),
          ]),
        ]),
      ]),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.eco', [
      css('&').styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        gap: Gap(row: Space.stride),
      ),
      css('h3').styles(fontFamily: Type.monoStack, fontSize: Type.body),
      css('p').styles(margin: Margin.only(top: Space.tight)),
      css('.registries').styles(
        display: Display.flex,
        gap: Gap(column: Space.step),
        fontSize: Type.micro,
      ),
    ]),
  ];
}
