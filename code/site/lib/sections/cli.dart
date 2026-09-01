import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Cli extends StatelessComponent {
  const Cli({super.key});

  static const _routes = <(String, String)>[
    (
      'macss project create --path <dir> --lang <en|es> --apply',
      'Open a project on docs/, code/ and the four starter layers. Delete the '
          'ones that do not apply.',
    ),
    (
      'macss requisition new <slug> --apply',
      'Open a requisition: the product owner’s form, its issue metadata, and '
          'the active pointer.',
    ),
    (
      'macss requisition publish --plan',
      'Show what would reach GitHub — the exact gh line included — and change '
          'nothing.',
    ),
    ('macss dor check', 'Definition of Ready: the request, the contract, and a published issue.'),
    ('macss delivery publish --apply', 'Push the branch and open the pull request from the delivery.'),
    (
      'macss skill deploy --host <hosts> --scope <global|repo> --all --apply',
      'Put the lifecycle skills where your AI coding host reads them — Claude '
          'Code, Codex, Antigravity, OpenCode, Copilot. list, remove, doctor '
          'and validate come with it.',
    ),
    (
      'macss skill doctor',
      'What is deployed on this machine, which tool owns it, and what has '
          'changed since. Other tools deploy skills too; this says which are '
          'yours.',
    ),
    ('macss help', 'Every route this CLI accepts, listing what reads apart from what changes.'),
  ];

  @override
  Component build(BuildContext context) => Band(
    heading: 'The CLI',
    children: [
      p([
        .text('It carries the delivery cycle end to end: it opens the '
            'requisition, adds the contract, publishes both to a GitHub issue, '
            'runs the stage gates, and takes the delivery and its evidence to a '
            'pull request.'),
      ]),
      p([
        .text('Routes are one of two kinds. A '),
        strong([.text('query')]),
        .text(' reads and answers. A '),
        strong([.text('command')]),
        .text(' changes something and says what it would change first: every '
            'one takes '),
        code([.text('--plan')]),
        .text(' or '),
        code([.text('--apply')]),
        .text(', and neither is the default.'),
      ]),
      Rows(
        rows: [
          for (final (term, describes) in _routes) Row(term, [.text(describes)]),
        ],
      ),
    ],
  );
}
