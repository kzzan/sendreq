import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/repositories/mock_server_repository.dart';

/// 用于测试和无磁盘组合的 Mock Server 仓储。
///
/// 模型本身不可变，因此保存和读取可以直接共享安全定义，而端点和变体顺序始终保持。
class InMemoryMockServerRepository implements MockServerRepository {
  InMemoryMockServerRepository({Iterable<MockServer> initial = const []}) {
    for (final server in initial) {
      if (_servers.containsKey(server.id)) {
        throw ArgumentError.value(
          initial,
          'initial',
          'Mock Server identifiers must be unique.',
        );
      }
      _servers[server.id] = server;
    }
  }

  final Map<String, MockServer> _servers = {};

  @override
  Future<void> delete(String id) async {
    _servers.remove(id);
  }

  @override
  Future<MockServer?> findById(String id) async => _servers[id];

  @override
  Future<List<MockServer>> list() async {
    final servers = _servers.values.toList()
      ..sort((left, right) {
        final updated = right.updatedAt.compareTo(left.updatedAt);
        return updated != 0 ? updated : left.id.compareTo(right.id);
      });
    return List.unmodifiable(servers);
  }

  @override
  Future<void> save(MockServer server) async {
    _servers[server.id] = server;
  }
}
