// Hides the SDK's own VersionInput/VersionOutput (from its VersionPlugin):
// this module keeps macss's own `version` command rather than adopting the
// SDK's, so both names must resolve to macss's own commands/version.dart.
import 'package:modular_cli_sdk/modular_cli_sdk.dart'
    hide VersionInput, VersionOutput;

// modular_cli_sdk's own InstallationPlugin declares upgrade/uninstall, and
// DoctorPlugin declares doctor; macss_cli.dart registers those plugins
// directly on ModularCli. This module only keeps the routes MACSS itself
// owns.
import 'commands/tui.dart';
import 'commands/version.dart';

void buildGlobalModule(ModuleBuilder m) {
  m.query<TuiInput, TuiOutput>(
    '',
    (req) => TuiCommand(TuiInput.fromCliRequest(req)),
    description: 'Display MACSS banner and available commands',
    globals: true,
    contract: CliContract.none,
  );

  m.query<VersionInput, VersionOutput>(
    'version',
    (req) => VersionCommand(VersionInput.fromCliRequest(req)),
    description: 'Print the current CLI version',
    globals: true,
    contract: CliContract.none,
  );
}
