/// `macss help` — prints the global CLI help summary.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

const String macssHelpText =
    'Usage:\n'
    '  macss                 Display MACSS banner and available commands\n'
    '  macss help            Show this help\n'
    '  macss --help          Show this help\n'
    '  macss -h              Show this help\n'
    '  macss <command> ...\n'
    '\n'
    'Root commands:\n'
    '  help       Show available commands\n'
    '  create     Scaffold a new MACSS project\n'
    '  doctor     Verify local installation and assets integrity\n'
    '  upgrade    Download and install latest release from GitHub\n'
    '  uninstall  Remove MACSS CLI from the system\n'
    '  version    Print the current CLI version\n'
    '\n'
    'Modules:\n'
    '  api graphql compile   Compile GraphQL artifacts for modular_api\n';

class HelpInput extends Input {
  HelpInput();

  factory HelpInput.fromCliRequest(CliRequest req) => HelpInput();

  @override
  Map<String, dynamic> toJson() => {};
}

class HelpOutput extends Output {
  final String text;

  HelpOutput({required this.text});

  @override
  Map<String, dynamic> toJson() => {'help': text};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => text;
}

class HelpCommand implements Command<HelpInput, HelpOutput> {
  @override
  final HelpInput input;

  HelpCommand(this.input);

  @override
  String? validate() => null;

  @override
  Future<HelpOutput> execute() async => HelpOutput(text: macssHelpText);
}