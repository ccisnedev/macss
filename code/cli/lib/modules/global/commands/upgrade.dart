/// `macss upgrade` — downloads and installs the latest MACSS release.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/version.dart';
import '../../../targets/platform_ops.dart';

const String _repo = 'ccisnedev/macss';

// ─── Input ──────────────────────────────────────────────────────────────────

class UpgradeInput extends Input {
  final String installDir;

  UpgradeInput({required this.installDir});

  factory UpgradeInput.fromCliRequest(CliRequest req) {
    final installDir = p.dirname(p.dirname(Platform.resolvedExecutable));
    return UpgradeInput(installDir: installDir);
  }

  @override
  Map<String, dynamic> toJson() => {'installDir': installDir};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class UpgradeOutput extends Output {
  final String message;
  final String previousVersion;
  final String newVersion;
  final bool upgraded;

  UpgradeOutput({
    required this.message,
    required this.previousVersion,
    required this.newVersion,
    required this.upgraded,
  });

  @override
  Map<String, dynamic> toJson() => {
    'message': message,
    'previousVersion': previousVersion,
    'newVersion': newVersion,
    'upgraded': upgraded,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() {
    if (!upgraded) return message;
    return '✓ Upgraded: $previousVersion → $newVersion';
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class UpgradeCommand implements Command<UpgradeInput, UpgradeOutput> {
  @override
  final UpgradeInput input;

  final PlatformOps platformOps;
  final HttpClient? httpClientOverride;

  UpgradeCommand(
    this.input, {
    PlatformOps? platformOps,
    this.httpClientOverride,
  }) : platformOps = platformOps ?? PlatformOps.current();

  @override
  String? validate() => null;

  @override
  Future<UpgradeOutput> execute() async {
    final client = httpClientOverride ?? HttpClient();
    try {
      stderr.writeln('Current version: $macssVersion');
      stderr.writeln('Checking for updates...');

      // 1. Fetch latest release metadata
      final releaseUrl = Uri.parse(
        'https://api.github.com/repos/$_repo/releases/latest',
      );
      final metaRequest = await client.getUrl(releaseUrl);
      metaRequest.headers.set('Accept', 'application/vnd.github+json');
      metaRequest.headers.set('User-Agent', 'macss-cli/$macssVersion');
      final metaResponse = await metaRequest.close();

      if (metaResponse.statusCode != 200) {
        return UpgradeOutput(
          message:
              'Failed to fetch release info (HTTP ${metaResponse.statusCode})',
          previousVersion: macssVersion,
          newVersion: macssVersion,
          upgraded: false,
        );
      }

      final body = await metaResponse.transform(utf8.decoder).join();
      final release = jsonDecode(body) as Map<String, dynamic>;
      final tagName = release['tag_name'] as String;
      final latestVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;

      // Skip prereleases
      if ((release['prerelease'] as bool? ?? false)) {
        return UpgradeOutput(
          message: 'Latest release is a prerelease — skipping.',
          previousVersion: macssVersion,
          newVersion: macssVersion,
          upgraded: false,
        );
      }

      stderr.writeln('Latest version available: $latestVersion');

      if (latestVersion == macssVersion) {
        return UpgradeOutput(
          message: 'Already on the latest version',
          previousVersion: macssVersion,
          newVersion: macssVersion,
          upgraded: false,
        );
      }

      stderr.writeln('Found v$latestVersion, downloading...');

      // 2. Find asset for this platform
      final expectedAsset = platformOps.assetName;
      final assets = release['assets'] as List<dynamic>;
      final asset = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String) == expectedAsset,
        orElse: () => throw Exception(
          'No $expectedAsset asset in release $tagName',
        ),
      );

      final downloadUrl = asset['browser_download_url'] as String;

      // 3. Download to temp
      final tempDir = Directory.systemTemp.createTempSync('macss_upgrade_');
      final zipFile = File(p.join(tempDir.path, expectedAsset));

      final dlRequest = await client.getUrl(Uri.parse(downloadUrl));
      dlRequest.headers.set('User-Agent', 'macss-cli/$macssVersion');
      final dlResponse = await dlRequest.close();
      final sink = zipFile.openWrite();
      await dlResponse.pipe(sink);

      // 4. Extract over current installation
      final installDir = input.installDir;
      stderr.writeln('Applying update in: $installDir');
      try {
        if (Platform.isWindows) {
          final bakFile = File('${Platform.resolvedExecutable}.bak');
          if (bakFile.existsSync()) bakFile.deleteSync();
          File(Platform.resolvedExecutable).renameSync(bakFile.path);
        }

        await platformOps.expandArchive(zipFile.path, installDir);

        if (Platform.isWindows) {
          try {
            final bakFile = File('${Platform.resolvedExecutable}.bak');
            if (bakFile.existsSync()) bakFile.deleteSync();
          } on FileSystemException {
            // Still locked — cleaned up on next upgrade
          }
        }
      } catch (e) {
        tempDir.deleteSync(recursive: true);
        return UpgradeOutput(
          message: 'Failed to extract: $e',
          previousVersion: macssVersion,
          newVersion: latestVersion,
          upgraded: false,
        );
      }

      tempDir.deleteSync(recursive: true);

      // 5. Post-install
      stderr.writeln('Verifying installation...');
      await platformOps.runPostInstall(installDir);

      return UpgradeOutput(
        message: '✓ Upgraded: $macssVersion → $latestVersion',
        previousVersion: macssVersion,
        newVersion: latestVersion,
        upgraded: true,
      );
    } finally {
      if (httpClientOverride == null) client.close();
    }
  }
}
