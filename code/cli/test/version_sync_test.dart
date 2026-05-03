import 'dart:io';

import 'package:macss_cli/modules/global/commands/version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late String yamlVersion;

  setUpAll(() {
    final pubspecFile = File('pubspec.yaml');
    expect(
      pubspecFile.existsSync(),
      isTrue,
      reason: 'pubspec.yaml must exist — run tests from code/cli/',
    );
    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as Map;
    yamlVersion = pubspec['version'].toString();
  });

  test('version.dart matches pubspec.yaml', () {
    expect(
      macssVersion,
      equals(yamlVersion),
      reason: 'version.dart ($macssVersion) != pubspec.yaml ($yamlVersion). '
          'Fix: update code/cli/lib/src/version.dart OR code/cli/pubspec.yaml',
    );
  });
}
