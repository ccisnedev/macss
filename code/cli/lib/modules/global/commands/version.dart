/// `macss version` — prints the current CLI version.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../src/version.dart';
export '../../../src/version.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class VersionInput extends Input {
  VersionInput();

  factory VersionInput.fromCliRequest(CliRequest req) => VersionInput();

  /// Declares an EMPTY contract: `version` accepts no option, so any option
  /// passed to it is rejected. Omitting `params` would leave it unchecked.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class VersionOutput extends Output {
  final String version;

  VersionOutput({required this.version});

  @override
  Map<String, dynamic> toJson() => {'version': version};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => version;
}

// ─── Command ────────────────────────────────────────────────────────────────

class VersionCommand implements Query<VersionInput, VersionOutput> {
  @override
  final VersionInput input;

  VersionCommand(this.input);

  @override
  String? validate() => null;

  @override
  Future<VersionOutput> execute() async =>
      VersionOutput(version: macssVersion);
}
