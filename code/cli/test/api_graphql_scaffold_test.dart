import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

void main() {
  group('api graphql scaffold', () {
    test('compile route is registered and serves contextual help', () async {
      final code = await runMacss(['api', 'graphql', 'compile', '--help']);
      expect(code, ExitCode.ok);
    });

    test('unknown api graphql command returns non-zero', () async {
      final code = await runMacss(['api', 'graphql', 'unknown']);
      expect(code, isNot(ExitCode.ok));
    });
  });
}