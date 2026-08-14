import 'package:flutter/foundation.dart';

import 'package:sendreq/domain/app_updates/app_update.dart';

enum AppUpdateState { idle, checking, upToDate, updateAvailable, failed }

/// Owns the transient state of one explicit update-check workflow.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required AppReleaseRepository releaseRepository,
    required InstalledAppVersionProvider installedVersionProvider,
    required ExternalReleaseLauncher releaseLauncher,
  }) : this._(releaseRepository, installedVersionProvider, releaseLauncher);

  AppUpdateController._(
    this._releaseRepository,
    this._installedVersionProvider,
    this._releaseLauncher,
  );

  final AppReleaseRepository _releaseRepository;
  final InstalledAppVersionProvider _installedVersionProvider;
  final ExternalReleaseLauncher _releaseLauncher;

  AppUpdateState state = AppUpdateState.idle;
  String? currentVersion;
  AppRelease? latestRelease;

  Future<void> checkForUpdates() async {
    if (state == AppUpdateState.checking) return;
    state = AppUpdateState.checking;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        _installedVersionProvider.readVersion(),
        _releaseRepository.fetchLatest(),
      ]);
      currentVersion = values[0] as String;
      latestRelease = values[1] as AppRelease;
      state =
          AppVersion.parse(
                latestRelease!.version,
              ).compareTo(AppVersion.parse(currentVersion!)) >
              0
          ? AppUpdateState.updateAvailable
          : AppUpdateState.upToDate;
    } on Object {
      state = AppUpdateState.failed;
    }
    notifyListeners();
  }

  Future<void> update() async {
    final release = latestRelease;
    if (release == null) return;
    try {
      await _releaseLauncher.open(release.releasePage);
    } on Object {
      state = AppUpdateState.failed;
      notifyListeners();
    }
  }
}
