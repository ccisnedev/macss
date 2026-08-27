import 'dart:io' as io;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import '../../assets.dart';
import 'commands/doctor.dart';
import 'commands/tui.dart';
import 'commands/uninstall.dart';
import 'commands/migrate_skills.dart';
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

  // Temporary: one upgrade off the prefix era, removed in 0.13.0. Outside the
  // `skill` module because PRD 12.2 fixes that at five routes and R12.1 makes
  // it identical in every consumer — a migration belonging to one consumer's
  // history belongs somewhere else.
  m.command<MigrateSkillsInput, MigrateSkillsOutput>(
    'migrate-skills',
    (req) => MigrateSkillsCommand(
      MigrateSkillsInput.fromCliRequest(req),
      home: io.Platform.environment['HOME'] ??
          io.Platform.environment['USERPROFILE'] ??
          '',
      ledgerFile: LedgerFile.resolve(
        home: io.Platform.environment['HOME'] ??
            io.Platform.environment['USERPROFILE'] ??
            '',
        environment: io.Platform.environment,
      ),
    ),
    description: 'One-time: remove the lifecycle skills this CLI deployed before '
        'the ledger existed, so they can be deployed again and recorded',
    params: MigrateSkillsInput.params,
  );

  m.query<VersionInput, VersionOutput>(
    'version',
    (req) => VersionCommand(VersionInput.fromCliRequest(req)),
    description: 'Print the current CLI version',
    params: VersionInput.params,
  );
}
