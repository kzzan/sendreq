import 'package:sendreq/domain/app_updates/app_update.dart';
import 'package:sendreq/ui/features/settings/view_models/app_update_controller.dart';

class FakeAppReleaseRepository implements AppReleaseRepository {
  FakeAppReleaseRepository({this.version = '0.1.0'});

  String version;
  int calls = 0;

  @override
  Future<AppRelease> fetchLatest() async {
    calls++;
    return AppRelease(
      version: version,
      releasePage: Uri.parse(
        'https://github.com/kzzan/sendreq/releases/latest',
      ),
    );
  }
}

class FakeInstalledAppVersionProvider implements InstalledAppVersionProvider {
  const FakeInstalledAppVersionProvider([this.version = '0.1.0']);

  final String version;

  @override
  Future<String> readVersion() async => version;
}

class FakeExternalReleaseLauncher implements ExternalReleaseLauncher {
  Uri? opened;

  @override
  Future<void> open(Uri uri) async => opened = uri;
}

AppUpdateController fakeAppUpdateController() => AppUpdateController(
  releaseRepository: FakeAppReleaseRepository(),
  installedVersionProvider: const FakeInstalledAppVersionProvider(),
  releaseLauncher: FakeExternalReleaseLauncher(),
);
