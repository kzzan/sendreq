import '../../domain/models/workspace_models.dart';

/// 原型期的内存种子数据，后续可被真实 Repository 替换。
class WorkbenchSeed {
  /// 构造种子数据，各字段分别对应工作台的一个功能分区。
  const WorkbenchSeed({
    required this.requests,
    required this.drafts,
    required this.variables,
    required this.metrics,
    required this.history,
  });

  /// 工作区中的请求资源列表（含方法、路径与所属文件夹）。
  final List<RequestResource> requests;

  /// 请求 ID 到请求草稿的映射，描述每个请求的编辑态配置。
  final Map<String, RequestDraft> drafts;

  /// 环境变量列表，涵盖全局与按环境（如 Staging）划分的作用域。
  final List<EnvironmentVariable> variables;

  /// 仪表盘指标卡片数据（请求量、时延、错误率等）。
  final List<MetricSummary> metrics;

  /// 近期执行记录，供历史面板回看。
  final List<ExecutionRecord> history;

  /// 生成一套覆盖主要功能分区（集合 / 环境 / 仪表盘 / 历史）的演示数据，
  /// 用于原型期快速预览工作台效果。
  factory WorkbenchSeed.sample() {
    // 仅保留安装包内 Demo 的 REST、WebSocket 与 gRPC 上下文。
    const requests = [
      RequestResource(
        id: 'demo-rest-list-users',
        method: 'GET',
        name: 'List users',
        path: '/api/v1/users',
        folder: 'REST',
      ),
      RequestResource(
        id: 'demo-websocket-echo',
        method: 'WebSocket',
        name: 'Local echo',
        path: '/ws',
        folder: 'WebSocket',
      ),
      RequestResource(
        id: 'demo-grpc-create-order',
        method: 'gRPC',
        name: 'Create order',
        path: '/order.v1.OrderService/CreateOrder',
        folder: 'gRPC',
      ),
    ];

    return WorkbenchSeed(
      requests: requests,
      // 每个请求 ID 对应的草稿：演示查询参数、独立认证与请求体。
      drafts: const {
        'demo-rest-list-users': RequestDraft(
          method: 'GET',
          baseUrlToken: 'http://127.0.0.1:8081',
          path: '/api/v1/users',
          params: [
            KeyValueRow(keyName: 'page', value: '1'),
            KeyValueRow(keyName: 'limit', value: '20'),
          ],
          headers: [],
          body: '',
        ),
      },
      // 环境变量：包含 Staging 作用域的基础地址与令牌，以及 Global 的通用超时。
      variables: const [
        EnvironmentVariable(
          scope: 'Staging',
          keyName: 'baseUrl',
          value: 'https://staging.sendreq.io',
          type: 'String',
        ),
        EnvironmentVariable(
          scope: 'Staging',
          keyName: 'token',
          value: '••••••••••••••••',
          type: 'Secret',
          secret: true,
        ),
        EnvironmentVariable(
          scope: 'Global',
          keyName: 'timeout',
          value: '8000',
          type: 'Number',
        ),
      ],
      // 仪表盘指标：数值与相对上一周期变化（增量），用于演示趋势展示。
      metrics: const [
        MetricSummary(label: 'Requests 24h', value: '1,284', delta: '+12.8%'),
        MetricSummary(label: 'Avg latency', value: '184 ms', delta: '-24 ms'),
        MetricSummary(label: 'Error rate', value: '0.7%', delta: '-0.3 pt'),
        MetricSummary(label: 'Active env', value: 'Staging', delta: '3 vars'),
      ],
      // 历史执行记录：方法、路径、状态码、耗时与相对时间，供历史面板回看。
      history: const [
        ExecutionRecord(
          method: 'GET',
          path: '/api/v1/users',
          status: 200,
          timeMs: 186,
          when: 'just now',
        ),
        ExecutionRecord(
          method: 'WebSocket',
          path: '/ws',
          status: 200,
          timeMs: 42,
          when: '3 min ago',
        ),
      ],
    );
  }
}
