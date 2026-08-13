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

  factory UpgradeInput.fromCliRequest(CliRequest req) => UpgradeInput(
    installDir: p.dirname(p.dirname(Platform.resolvedExecutable)),
  );

  /// The install dir is derived, so this command takes nothing but the three
  /// flags the SDK gives every command.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'installDir': installDir};
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Fetches [url] into the file at [destination].
///
/// A function rather than an `HttpClient`, so the step that replaces the
/// installation does not have to know how bytes arrive — and so a test can
/// stand in for the network without faking thirty members of an interface it
/// never uses.
typedef Downloader = Future<void> Function(String url, String destination);

/// Downloads over HTTP, which is how it happens outside a test.
Future<void> downloadOverHttp(String url, String destination) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'macss-cli/$macssVersion');
    final response = await request.close();
    await response.pipe(File(destination).openWrite());
  } finally {
    client.close();
  }
}

/// Downloads a release and extracts it over the installation.
///
/// Everything this needs — which version, which asset, which URL — was settled
/// when the step was built, from **one** call to the releases API. Asking again
/// at perform time could answer differently: a release published in between
/// would be downloaded without ever having been approved.
///
/// **It says what it is doing while it does it.** The plan states what *will*
/// happen; this states that it *is* happening, which is a different thing and
/// the only one that helps during a download of several megabytes. It goes to
/// [progress] — stderr by default — so `--json` stays machine-readable.
class ReplaceInstallation implements Step {
  ReplaceInstallation({
    required this.platformOps,
    required this.installDir,
    required this.from,
    required this.to,
    required this.asset,
    required this.downloadUrl,
    Downloader? download,
    IOSink? progress,
    String? runningExecutable,
  }) : download = download ?? downloadOverHttp,
       progress = progress ?? stderr,
       runningExecutable = runningExecutable ?? Platform.resolvedExecutable;

  final PlatformOps platformOps;
  final Downloader download;
  final String installDir;
  final String from;
  final String to;
  final String asset;
  final String downloadUrl;

  /// Where the running commentary goes. Injected so a test can read it — which
  /// is the whole reason this is here: the commentary was lost once already,
  /// in a refactor, because nothing asserted it.
  final IOSink progress;

  /// The binary this step is replacing, which on Windows has to be moved aside
  /// before it can be overwritten.
  ///
  /// **Injected, and that is not optional.** `Platform.resolvedExecutable` is
  /// `macss.exe` only when a compiled `macss.exe` is what is running. Under
  /// `dart test` and `dart run` it is the Dart VM — so a test that reached the
  /// default would rename the Dart SDK's own `dart.exe` and take the toolchain
  /// down with it. That is not hypothetical; it is how this seam came to exist.
  final String runningExecutable;

  @override
  Preview preview() => Preview(
    verb: 'replace',
    target: installDir,
    detail: ['$from → $to', 'asset $asset', 'from $downloadUrl'].join('; '),
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final tempDir = Directory.systemTemp.createTempSync('macss_upgrade_');
    try {
      progress.writeln('Downloading $asset ($from → $to)...');
      final zipFile = File(p.join(tempDir.path, asset));
      await download(downloadUrl, zipFile.path);

      if (Platform.isWindows) {
        // The running executable cannot be overwritten in place, so it is moved
        // aside first and cleaned up on the way out — or on the next upgrade,
        // if the file is still locked.
        final bak = File('$runningExecutable.bak');
        if (bak.existsSync()) bak.deleteSync();
        File(runningExecutable).renameSync(bak.path);
      }

      progress.writeln('Extracting into $installDir...');
      await platformOps.expandArchive(zipFile.path, installDir);

      if (Platform.isWindows) {
        try {
          final bak = File('$runningExecutable.bak');
          if (bak.existsSync()) bak.deleteSync();
        } on FileSystemException {
          // Still locked — cleaned up on the next upgrade.
        }
      }

      progress.writeln('Verifying installation...');
      await platformOps.runPostInstall(installDir);
    } finally {
      tempDir.deleteSync(recursive: true);
    }

    return Outcome(
      verb: 'replace',
      target: installDir,
      values: {'from': from, 'to': to},
    );
  }
}

// ─── Output ─────────────────────────────────────────────────────────────────

class UpgradeOutput extends Output {
  UpgradeOutput({
    required this.previousVersion,
    required this.newVersion,
    required this.upgraded,
    this.reason,
  });

  final String previousVersion;
  final String newVersion;
  final bool upgraded;

  /// Why nothing happened, when nothing did.
  final String? reason;

  @override
  Map<String, dynamic> toJson() => {
    'previousVersion': previousVersion,
    'newVersion': newVersion,
    'upgraded': upgraded,
    if (reason != null) 'reason': reason,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => upgraded
      ? '✓ Upgraded: $previousVersion → $newVersion'
      : (reason ?? 'Already on the latest version');
}

// ─── Command ────────────────────────────────────────────────────────────────

class UpgradeCommand implements Command<UpgradeInput, UpgradeOutput> {
  @override
  final UpgradeInput input;

  final PlatformOps platformOps;

  /// Answers the releases API. Overridden by the tests that exercise what the
  /// lookup returns.
  final HttpClient? httpClientOverride;

  /// How the release archive is fetched. A seam for the tests, and the reason
  /// the step itself knows nothing about HTTP.
  final Downloader? download;

  /// Where the step's running commentary goes. A seam for the tests.
  final IOSink? progress;

  UpgradeCommand(
    this.input, {
    PlatformOps? platformOps,
    this.httpClientOverride,
    this.download,
    this.progress,
  }) : platformOps = platformOps ?? PlatformOps.current();

  @override
  String? validate() => null;

  String _latest = macssVersion;
  String? _reason;

  /// One step, and everything it needs read before the plan is built.
  ///
  /// The releases API is asked **once**, here. That is what makes the plan
  /// honest: the version, the asset and the URL a person approves are the ones
  /// that get downloaded. Asking again inside the step could resolve a release
  /// published in the meantime, and the upgrade would then not be the one that
  /// was shown.
  ///
  /// Nothing to upgrade to is not a failure, so it builds no steps and says
  /// why — already current, or the newest release is a prerelease.
  @override
  Future<List<Step>> steps() async {
    final client = httpClientOverride ?? HttpClient();

    final releaseUrl = Uri.parse(
      'https://api.github.com/repos/$_repo/releases/latest',
    );
    final metaRequest = await client.getUrl(releaseUrl);
    metaRequest.headers.set('Accept', 'application/vnd.github+json');
    metaRequest.headers.set('User-Agent', 'macss-cli/$macssVersion');
    final metaResponse = await metaRequest.close();

    if (metaResponse.statusCode != 200) {
      throw CommandException(
        code: 'RELEASE_LOOKUP_FAILED',
        message:
            'Failed to fetch release info (HTTP ${metaResponse.statusCode})',
        exitCode: ExitCode.apiError,
        isRetryable: true,
      );
    }

    final release =
        jsonDecode(await metaResponse.transform(utf8.decoder).join())
            as Map<String, dynamic>;

    if (release['prerelease'] as bool? ?? false) {
      _reason = 'Latest release is a prerelease — skipping.';
      return const [];
    }

    final tagName = release['tag_name'] as String;
    _latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    if (_latest == macssVersion) {
      _reason = 'Already on the latest version';
      return const [];
    }

    final expectedAsset = platformOps.assetName;
    final asset = (release['assets'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((a) => a['name'] == expectedAsset)
        .firstOrNull;
    if (asset == null) {
      throw CommandException(
        code: 'ASSET_NOT_FOUND',
        message: 'No $expectedAsset asset in release $tagName',
        exitCode: ExitCode.notFound,
      );
    }

    return [
      ReplaceInstallation(
        platformOps: platformOps,
        download: download,
        installDir: input.installDir,
        from: macssVersion,
        to: _latest,
        asset: expectedAsset,
        downloadUrl: asset['browser_download_url'] as String,
        progress: progress,
      ),
    ];
  }

  @override
  UpgradeOutput describe(Execution execution) => UpgradeOutput(
    previousVersion: macssVersion,
    newVersion: _latest,
    upgraded: execution.outcomes.any((o) => o.verb == 'replace'),
    reason: _reason,
  );
}
