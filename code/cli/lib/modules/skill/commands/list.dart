/// `macss skill list` — shows the lifecycle skills this CLI ships.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../assets.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillListInput extends Input {
  SkillListInput();

  factory SkillListInput.fromCliRequest(CliRequest req) => SkillListInput();

  /// Empty contract: `list` takes no option, so any option is rejected.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SkillListOutput extends Output {
  final List<String> skills;

  SkillListOutput({required this.skills});

  @override
  Map<String, dynamic> toJson() => {'skills': skills};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => skills.map((s) => '  $s').join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class SkillListCommand implements Query<SkillListInput, SkillListOutput> {
  @override
  final SkillListInput input;

  final Assets assets;

  SkillListCommand(this.input, {required this.assets});

  @override
  String? validate() {
    if (!assets.directoryExists('skills')) {
      return 'No skills found in the installed assets. Run: macss upgrade --apply';
    }
    return null;
  }

  @override
  Future<SkillListOutput> execute() async =>
      SkillListOutput(skills: assets.listDirectory('skills'));
}
