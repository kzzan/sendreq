import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sendreq/data/services/github_release_update_checker.dart';
import 'package:sendreq/domain/app_updates/app_update.dart';
import 'package:sendreq/ui/features/settings/view_models/app_update_controller.dart';

import 'support/app_update_fakes.dart';

void main() {
  test('semantic versions compare release and pre-release tags correctly', () {
    expect(AppVersion.parse('v1.2.0').compareTo(AppVersion.parse('1.1.9')), 1);
    expect(AppVersion.parse('1.2.0').compareTo(AppVersion.parse('1.2.0')), 0);
    expect(
      AppVersion.parse(
        '1.2.0-beta.2',
      ).compareTo(AppVersion.parse('1.2.0-beta.10')),
      -1,
    );
    expect(
      AppVersion.parse('1.2.0').compareTo(AppVersion.parse('1.2.0-rc.1')),
      1,
    );
  });

  test('GitHub repository parses latest release and sends API headers', () async {
    final client = MockClient((request) async {
      expect(
        request.url,
        Uri.parse('https://api.github.com/repos/kzzan/sendreq/releases/latest'),
      );
      expect(request.headers['Accept'], 'application/vnd.github+json');
      expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
      return http.Response(
        '{"tag_name":"v0.2.0","html_url":"https://github.com/kzzan/sendreq/releases/tag/v0.2.0"}',
        200,
      );
    });

    final release = await GitHubReleaseRepository(client: client).fetchLatest();

    expect(release.version, 'v0.2.0');
    expect(
      release.releasePage,
      Uri.parse('https://github.com/kzzan/sendreq/releases/tag/v0.2.0'),
    );
  });

  test(
    'every explicit check fetches latest and update opens release',
    () async {
      final repository = FakeAppReleaseRepository(version: 'v0.2.0');
      final launcher = FakeExternalReleaseLauncher();
      final controller = AppUpdateController(
        releaseRepository: repository,
        installedVersionProvider: const FakeInstalledAppVersionProvider(
          '0.1.0',
        ),
        releaseLauncher: launcher,
      );
      addTearDown(controller.dispose);

      await controller.checkForUpdates();
      await controller.checkForUpdates();

      expect(repository.calls, 2);
      expect(controller.state, AppUpdateState.updateAvailable);
      await controller.update();
      expect(
        launcher.opened,
        Uri.parse('https://github.com/kzzan/sendreq/releases/latest'),
      );
    },
  );

  test('equal or older GitHub release reports up to date', () async {
    final controller = AppUpdateController(
      releaseRepository: FakeAppReleaseRepository(version: 'v0.1.0'),
      installedVersionProvider: const FakeInstalledAppVersionProvider('0.1.0'),
      releaseLauncher: FakeExternalReleaseLauncher(),
    );
    addTearDown(controller.dispose);

    await controller.checkForUpdates();

    expect(controller.state, AppUpdateState.upToDate);
  });
}
