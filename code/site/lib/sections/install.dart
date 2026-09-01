import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// First on the page, above the argument.
///
/// Whoever came to install installs. Whoever came to read scrolls, and has lost
/// nothing. This section used to sit at 67% of the page, inside the section
/// about the CLI, where it was reached after 589 words.
class Install extends StatelessComponent {
  const Install({super.key});

  @override
  Component build(BuildContext context) => Band(
    heading: 'Install',
    children: [
      const Command(
        caption: 'Windows · PowerShell',
        command: 'irm https://macss.ccisne.dev/install.ps1 | iex',
      ),
      const Command(
        caption: 'Linux · bash',
        command: 'curl -fsSL https://macss.ccisne.dev/install.sh | bash',
      ),
      p([
        .text('Both install to '),
        code([.text(r'%LOCALAPPDATA%\macss')]),
        .text(' or '),
        code([.text('~/.macss')]),
        .text(', add the directory to your PATH and create the '),
        code([.text('ma')]),
        .text(' alias.'),
      ]),
      p(classes: 'aside', [
        .text('Both scripts are worth a minute before you run them: '),
        a(href: 'https://macss.ccisne.dev/install.ps1', [.text('install.ps1')]),
        .text(', '),
        a(href: 'https://macss.ccisne.dev/install.sh', [.text('install.sh')]),
        .text('.'),
      ]),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.aside').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
