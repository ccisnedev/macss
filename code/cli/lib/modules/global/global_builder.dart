import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import 'commands/create.dart';
import 'commands/doctor.dart';
import 'commands/help.dart';
import 'commands/tui.dart';
import 'commands/uninstall.dart';
import 'commands/upgrade.dart';
import 'commands/version.dart';

void buildGlobalModule(ModuleBuilder m, {required Assets assets}) {
  m.command<TuiInput, TuiOutput>(
    '',
    (req) => TuiCommand(TuiInput.fromCliRequest(req)),
    description: 'Display MACSS banner and available commands',
  );

  m.command<HelpInput, HelpOutput>(
    'help',
    (req) => HelpCommand(HelpInput.fromCliRequest(req)),
    description: 'Show available commands',
  );

  m.command<CreateInput, CreateOutput>(
    'create',
    (req) => CreateCommand(CreateInput.fromCliRequest(req), assets: assets),
    description: 'Scaffold a new MACSS project',
  );

  m.command<DoctorInput, DoctorOutput>(
    'doctor',
    (req) => DoctorCommand(DoctorInput.fromCliRequest(req), assets: assets),
    description: 'Verify local installation and assets integrity',
  );

  m.command<UpgradeInput, UpgradeOutput>(
    'upgrade',
    (req) => UpgradeCommand(UpgradeInput.fromCliRequest(req)),
    description: 'Download and install latest release from GitHub',
  );

  m.command<UninstallInput, UninstallOutput>(
    'uninstall',
    (req) => UninstallCommand(UninstallInput.fromCliRequest(req)),
    description: 'Remove MACSS CLI from the system',
  );

  m.command<VersionInput, VersionOutput>(
    'version',
    (req) => VersionCommand(VersionInput.fromCliRequest(req)),
    description: 'Print the current CLI version',
  );
}
