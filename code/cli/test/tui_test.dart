import 'package:test/test.dart';

import 'package:macss_cli/modules/global/commands/tui.dart';
import 'package:macss_cli/modules/global/commands/version.dart';
import 'package:macss_cli/src/version_check.dart';

TuiCommand _makeTui() => TuiCommand(
  TuiInput(),
  versionChecker: ({required String currentVersion}) async =>
      const VersionCheckResult(updateAvailable: false),
);

void main() {
  group('TUI Command', () {
    test('TuiInput.fromCliRequest returns TuiInput', () {
      expect(TuiInput(), isA<TuiInput>());
    });

    test('TuiOutput contains version string', () async {
      final output = await _makeTui().execute();
      expect(output.version, equals(macssVersion));
    });

    test('TuiOutput.banner contains version', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains(macssVersion));
    });

    test('TuiOutput.banner contains command names', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains('create'));
      expect(output.banner, contains('doctor'));
      expect(output.banner, contains('upgrade'));
      expect(output.banner, contains('uninstall'));
      expect(output.banner, contains('version'));
    });

    test('TuiOutput.banner contains quickstart hint', () async {
      final output = await _makeTui().execute();
      expect(output.banner, contains('macss create'));
    });

    test('TuiOutput.exitCode is 0', () async {
      final output = await _makeTui().execute();
      expect(output.exitCode, 0);
    });

    test('TuiOutput.toText returns banner only', () async {
      final output = await _makeTui().execute();
      expect(output.toText(), equals(output.banner));
      expect(output.toText(), isNot(contains('version:')));
      expect(output.toText(), isNot(contains('banner:')));
    });

    test('TuiCommand.validate returns null', () {
      expect(_makeTui().validate(), isNull);
    });

    test('shows update hint when new version is available', () async {
      final tui = TuiCommand(
        TuiInput(),
        versionChecker: ({required String currentVersion}) async =>
            const VersionCheckResult(
              updateAvailable: true,
              latestVersion: '9.9.9',
            ),
      );
      final output = await tui.execute();
      expect(output.banner, contains('9.9.9'));
      expect(output.banner, contains('upgrade'));
    });
  });
}
