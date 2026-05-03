/// Entry point for the `macss` CLI.
///
/// Delegates immediately to [runMacss] to keep the binary thin and testable.
library;

import 'dart:io';

import 'package:macss_cli/macss_cli.dart';

Future<void> main(List<String> args) async {
  final code = await runMacss(args);
  exit(code);
}
