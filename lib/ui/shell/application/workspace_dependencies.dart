import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/domain/repositories/mock_server_repository.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';

/// Workspace feature 的依赖契约与启动快照。
class WorkspaceDependencies {
  const WorkspaceDependencies({
    required this.preferenceStore,
    required this.assetRepository,
    required this.environmentStore,
    required this.mockServerRepository,
    required this.userNoticeRepository,
    required this.demoCollection,
  });

  final WorkspacePreferenceStore preferenceStore;
  final ApiAssetRepository assetRepository;
  final EnvironmentStore environmentStore;
  final MockServerRepository mockServerRepository;
  final UserNoticeRepository userNoticeRepository;
  final ApiCollection demoCollection;
}
