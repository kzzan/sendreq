import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';

/// 演示用的请求执行运行时：不发送真实网络请求，仅返回固定结构的模拟响应。
class DemoRequestExecutionRuntime implements RequestExecutionRuntime {
  // 统计已发送次数，用于驱动耗时与示例数据的轻微变化。
  int _sendCount = 0;

  /// 模拟发送请求，返回构造好的固定 JSON 响应。
  ///
  /// POST 返回 201、其余方法返回 200；耗时随发送次数递增以模拟真实波动。
  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) {
    // 每次发送递增计数，让示例数据产生可感知的变化。
    _sendCount += 1;
    // 按请求方法区分模拟状态码与响应体大小。
    final status = draft.method == 'POST' ? 201 : 200;
    final timeMs = 172 + (_sendCount * 11);
    final sizeKb = draft.method == 'POST' ? 3.8 : 6.4;
    return Future.value(
      RuntimeResponse(
        statusCode: status,
        timeMs: timeMs,
        sizeKb: sizeKb,
        body:
            '''
{
  "ok": true,
  "demo": "sendreq.desktop",
  "method": "${draft.method}",
  "url": "$resolvedUrl",
  "items": [
    {"id": "usr_1001", "role": "admin"},
    {"id": "usr_1002", "role": "viewer"}
  ]
}''',
        headers: const [
          KeyValueRow(keyName: 'content-type', value: 'application/json'),
          KeyValueRow(keyName: 'x-sendreq-trace', value: 'demo-transport'),
        ],
      ),
    );
  }

  /// 演示运行时没有真实连接，取消为空操作。
  @override
  void cancel() {}
}
