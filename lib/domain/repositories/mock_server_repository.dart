import 'package:sendreq/domain/contract_publishing/mock_server.dart';

/// Contract Publishing 对已保存 Mock Server 定义的持久化边界。
///
/// 该仓储只保存资产定义，不保存运行中的监听器、端口或 socket。
abstract interface class MockServerRepository {
  /// 按稳定的最近更新优先顺序返回所有资产，包括已归档项。
  Future<List<MockServer>> list();

  /// 按稳定 ID 查找资产；不存在时返回 null。
  Future<MockServer?> findById(String id);

  /// 原子创建或更新一个已验证的 Server 定义。
  Future<void> save(MockServer server);

  /// 删除定义；调用方必须先停止关联的临时运行时。
  Future<void> delete(String id);
}
