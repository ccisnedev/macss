import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Principles extends StatelessComponent {
  const Principles({super.key});

  static const _principles = <(String, String)>[
    (
      'Single-responsibility layers',
      'each component has one job, so the agent knows where to look and what '
          'to change.',
    ),
    (
      'A monorepo with a canonical structure',
      'code, documentation and infrastructure live together, so the agent sees '
          'the whole picture in one repository.',
    ),
    (
      'Closed-loop verification',
      'automated checks validate every change, so the agent confirms its own '
          'work before the developer reviews it.',
    ),
  ];

  @override
  Component build(BuildContext context) => Band(
    heading: 'Principles',
    children: [
      p([
        .text('An agent reasons best about a codebase with clear boundaries, '
            'predictable structure and explicit contracts. MACSS is those '
            'three things written down.'),
      ]),
      ul(classes: 'principles', [
        for (final (name, rest) in _principles)
          li([strong([.text(name)]), .text(' — $rest')]),
      ]),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.principles', [
      css('&').styles(
        maxWidth: measure,
        padding: Padding.only(left: Space.step),
        margin: Margin.zero,
      ),
      css('li').styles(margin: Margin.only(bottom: Space.tight)),
    ]),
  ];
}
