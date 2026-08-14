import 'dart:async';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/data/repositories/file_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/workspace_asset_snapshot_codec.dart';

/// 以 Isar 工作区文档持久化 API 资产，同时维持既有同步 repository 接口。
class IsarApiAssetRepository implements ApiAssetRepository {
  /// 私有构造：包装工作区文档与内存仓库。
  IsarApiAssetRepository._(this._workspace, this._delegate);

  /// 存储 API 资产所用的工作区文档 key。
  static const _workspaceKey = 'api-assets-v1';

  /// 承载资产文档的工作区数据库。
  final IsarWorkspace _workspace;

  /// 内存委托：持有全部资产状态并执行数据变更规则。
  final InMemoryApiAssetRepository _delegate;

  /// 串行写盘队列，保证多次变更按顺序落盘。
  Future<void> _writeQueue = Future.value();

  /// 从 Isar 加载仓库；无文档时从旧 JSON 仓库（或空工作区）初始化并首次落盘。
  static Future<IsarApiAssetRepository> load({
    required IsarWorkspace workspace,
    FileApiAssetRepository? legacyRepository,
  }) async {
    final document = await workspace.instance.workspaceDocuments.getByKey(
      _workspaceKey,
    );
    final restored = document == null
        ? null
        : WorkspaceAssetSnapshotCodec.decode(document.payloadJson);
    if (restored != null) return IsarApiAssetRepository._(workspace, restored);
    // 文档存在但解码失败时不能静默重建，交由启动层进入恢复流程。
    if (document != null) {
      throw const FormatException('Stored Isar workspace assets are invalid.');
    }

    final delegate = legacyRepository == null
        ? InMemoryApiAssetRepository(collections: const [])
        : InMemoryApiAssetRepository(
            collections: legacyRepository.listCollections(),
            openTabs: legacyRepository.listOpenTabs(),
            activeRequestId: legacyRepository.activeRequestId,
          );
    if (legacyRepository != null) await legacyRepository.backupIfPresent();
    final repository = IsarApiAssetRepository._(workspace, delegate);
    // 首次初始化立即落盘，保证后续打开能读到同一份数据。
    await repository._write();
    return repository;
  }

  /// 标记数据已变更，将写盘追加到串行队列。
  void _changed() => _writeQueue = _writeQueue.then((_) => _write());

  /// 等待所有排队的写盘操作完成。
  @override
  Future<void> flush() => _writeQueue;

  /// 将当前全部资产编码后写入工作区文档。
  Future<void> _write() async {
    final existing = await _workspace.instance.workspaceDocuments.getByKey(
      _workspaceKey,
    );
    // 复用已有文档或新建，确保同一 key 下只保留一份快照。
    final document = existing ?? WorkspaceDocument();
    document
      ..key = _workspaceKey
      ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
      ..updatedAt = DateTime.now().toUtc()
      ..payloadJson = WorkspaceAssetSnapshotCodec.encode(
        collections: _delegate.listCollections(),
        openTabs: _delegate.listOpenTabs(),
        activeRequestId: _delegate.activeRequestId,
      );
    await _workspace.instance.writeTxn(
      () => _workspace.instance.workspaceDocuments.put(document),
    );
  }

  /// 列出全部集合（返回只读快照）。
  @override
  List<ApiCollection> listCollections() => _delegate.listCollections();

  /// 列出全部扁平化请求定义。
  @override
  List<ApiRequestDefinition> listRequests() => _delegate.listRequests();

  /// 按 ID 获取请求定义，不存在时抛出异常。
  @override
  ApiRequestDefinition getRequest(String id) => _delegate.getRequest(id);

  /// 当前活动请求的 ID。
  @override
  String? get activeRequestId => _delegate.activeRequestId;

  /// 列出当前打开的选项卡。
  @override
  List<RequestTab> listOpenTabs() => _delegate.listOpenTabs();

  /// 新建一个空集合并持久化。
  @override
  ApiCollection createCollection() {
    final value = _delegate.createCollection();
    _changed();
    return value;
  }

  /// 在指定集合下新建一个空文件夹并持久化。
  @override
  ApiFolder createFolder({required String collectionId}) {
    final value = _delegate.createFolder(collectionId: collectionId);
    _changed();
    return value;
  }

  /// 新建一个请求定义并持久化。
  @override
  ApiRequestDefinition createRequest({
    String? collectionId,
    String? folderId,
    ApiRequestProtocol protocol = ApiRequestProtocol.http,
  }) {
    final value = _delegate.createRequest(
      collectionId: collectionId,
      folderId: folderId,
      protocol: protocol,
    );
    _changed();
    return value;
  }

  /// 导入已有集合（必要时重命名 ID）并持久化。
  @override
  ApiCollection addCollection(ApiCollection value) {
    final result = _delegate.addCollection(value);
    _changed();
    return result;
  }

  /// 重命名集合并持久化。
  @override
  void renameCollection(String id, String name) {
    _delegate.renameCollection(id, name);
    _changed();
  }

  /// 删除集合并持久化。
  @override
  void deleteCollection(String id) {
    _delegate.deleteCollection(id);
    _changed();
  }

  /// 重命名文件夹并持久化。
  @override
  void renameFolder({
    required String collectionId,
    required String folderId,
    required String name,
  }) {
    _delegate.renameFolder(
      collectionId: collectionId,
      folderId: folderId,
      name: name,
    );
    _changed();
  }

  /// 删除文件夹并持久化。
  @override
  void deleteFolder({required String collectionId, required String folderId}) {
    _delegate.deleteFolder(collectionId: collectionId, folderId: folderId);
    _changed();
  }

  /// 重命名请求并持久化。
  @override
  void renameRequest(String id, String name) {
    _delegate.renameRequest(id, name);
    _changed();
  }

  /// 删除请求并持久化。
  @override
  void deleteRequest(String id) {
    _delegate.deleteRequest(id);
    _changed();
  }

  /// 批量导入请求并持久化。
  @override
  void addRequests(List<ApiRequestDefinition> values) {
    _delegate.addRequests(values);
    _changed();
  }

  /// 更新请求内容并持久化。
  @override
  void updateRequest(ApiRequestDefinition value) {
    _delegate.updateRequest(value);
    _changed();
  }

  /// 打开请求选项卡并持久化。
  @override
  RequestTab openRequestTab(String id) {
    final value = _delegate.openRequestTab(id);
    _changed();
    return value;
  }

  /// 激活指定选项卡并持久化。
  @override
  void activateRequestTab(String id) {
    _delegate.activateRequestTab(id);
    _changed();
  }

  /// 关闭指定选项卡并持久化。
  @override
  void closeRequestTab(String id) {
    _delegate.closeRequestTab(id);
    _changed();
  }
}
