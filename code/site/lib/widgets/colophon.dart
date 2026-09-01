import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Shared by both pages, and site-specific: what belongs in a footer is what
/// this project wants to say last, which is not something a design system can
/// know.
class Colophon extends StatelessComponent {
  const Colophon({super.key});

  @override
  Component build(BuildContext context) => footer(classes: 'colophon', [
    p([
      a(href: 'https://github.com/ccisnedev/macss', [.text('Source')]),
      .text(' · '),
      a(href: 'https://pub.dev/packages/modular_api', [.text('modular_api')]),
      .text(' · '),
      a(href: 'https://inquiry.ccisne.dev', [.text('inquiry')]),
    ]),
  ]);

  @css
  static List<StyleRule> get styles => [
    css('.colophon', [
      css('&').styles(
        padding: Padding.only(top: Space.stride),
        margin: Margin.only(top: Space.chasm),
        border: Border.only(
          top: BorderSide(color: role('rule'), width: Unit.pixels(1)),
        ),
        color: role('muted'),
        fontSize: Type.micro,
      ),
      css('p').styles(margin: Margin.zero),
    ]),
  ];
}
