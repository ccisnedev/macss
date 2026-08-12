import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import 'commands/doctor.dart';
import 'commands/tui.dart';
import 'commands/uninstall.dart';
import 'commands/upgrade.dart';
import 'commands/version.dart';

void buildGlobalModule(ModuleBuilder m, {required Assets assets}) {
  m.query<TuiInput, TuiOutput>(
    '',
    (req) => TuiCommand(TuiInput.fromCliRequest(req)),
    description: 'Display MACSS banner and available commands',
    params: TuiInput.params,
  );

  m.query<DoctorInput, DoctorOutput>(
    'doctor',
    (req) => DoctorCommand(DoctorInput.fromCliRequest(req), assets: assets),
    description: 'Verify local installation and assets integrity',
    params: DoctorInput.params,
  );

  m.command<UpgradeInput, UpgradeOutput>(
    'upgrade',
    (req) => UpgradeCommand(UpgradeInput.fromCliRequest(req)),
    description: 'Download and install latest release from GitHub',
    params: UpgradeInput.params,
  );

  m.command<UninstallInput, UninstallOutput>(
    'uninstall',
    (req) => UninstallCommand(UninstallInput.fromCliRequest(req)),
    description: 'Remove MACSS CLI from the system',
    params: UninstallInput.params,
  );

  m.query<VersionInput, VersionOutput>(
    'version',
    (req) => VersionCommand(VersionInput.fromCliRequest(req)),
    description: 'Print the current CLI version',
    params: VersionInput.params,
  );
}
