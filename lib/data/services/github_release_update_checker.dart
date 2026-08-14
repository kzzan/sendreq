import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sendreq/domain/app_updates/app_update.dart';

/// Reads the newest stable release directly from the GitHub Releases API.
class GitHubReleaseRepository implements AppReleaseRepository {
  const GitHubReleaseRepository({
    this.owner = 'kzzan',
    this.repository = 'sendreq',
    this.client,
  });

  final String owner;
  final String repository;
  final http.Client? client;

  @override
  Future<AppRelease> fetchLatest() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repository/releases/latest',
    );
    final response = client == null
        ? await http.get(uri, headers: _headers)
        : await client!.get(uri, headers: _headers);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub release check failed with status ${response.statusCode}.',
        uri: uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('GitHub release response must be an object.');
    }
    final release = Map<String, dynamic>.from(decoded);
    final version = release['tag_name'];
    final page = release['html_url'];
    final pageUri = page is String ? Uri.tryParse(page) : null;
    if (version is! String ||
        version.trim().isEmpty ||
        pageUri == null ||
        !pageUri.hasScheme) {
      throw const FormatException('GitHub release response is incomplete.');
    }
    return AppRelease(version: version, releasePage: pageUri);
  }

  static const _headers = {
    HttpHeaders.acceptHeader: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    HttpHeaders.userAgentHeader: 'sendreq-desktop-update-checker',
  };
}

class PackageInfoInstalledVersionProvider
    implements InstalledAppVersionProvider {
  const PackageInfoInstalledVersionProvider();

  @override
  Future<String> readVersion() async =>
      (await PackageInfo.fromPlatform()).version;
}

class SystemExternalReleaseLauncher implements ExternalReleaseLauncher {
  const SystemExternalReleaseLauncher();

  @override
  Future<void> open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('Could not open the release page.');
  }
}
