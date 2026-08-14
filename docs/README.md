# sendreq 维护文档

sendreq 的当前产品表面只有 Requests、Mock 和 Settings。Collection 与 Environment 是 Requests 的输入上下文，不是独立工具入口；HTTP Response、WebSocket Timeline 和 gRPC Timeline 是当前 Request 的输出。

## 代码结构

- `app`：唯一组合根，创建 data adapters、domain services 和 UI controllers。
- `domain`：纯 Dart model、port 与执行规则，不依赖 Flutter、data 或 ui。
- `data`：持久化和 transport adapter，只实现 domain contracts。
- `ui/core`：Chakra token、recipe、共享 JSON/code surface 与 PC 布局原语。
- `ui/features/requests`：Collection、Environment、Request Editor 与当前 Output。
- `ui/features/mock`：HTTP-only Mock Server 编辑与回环运行时控制。
- `ui/features/settings`：即时预览、自动保存的常规偏好。
- `ui/shell`：三工具导航与跨模块命令编排；`WorkspaceViewModelState` 是拆分命令模块的显式内部状态契约。

非三入口能力不属于当前产品表面。除兼容清理 key 和缺失性架构断言外，新代码、测试、文档和规格不得重新引入独立资源页或长连接模拟运行时。

生产文件应保持单一职责；手写 Dart 文件常规上限为 500 行。手写模块必须使用显式 import，`part/part of` 只允许 Isar 等生成的 `.g.dart` 配对。结构边界由 `test/code_structure_test.dart` 和模块边界测试约束。

当前登记的高内聚例外为 API asset 值对象表、Mock 值对象表和 Protobuf 描述符/wire reader。职责发生分裂或继续增长时必须先拆分；降到阈值内后立即移出例外。

## 运行数据

- HTTP 当前结果只保存在活动 Request 的内存状态中，新执行替换旧结果。
- WebSocket 与 gRPC 时间线按 Request 隔离并受数量、字节预算限制。
- 关闭 Request 或销毁 Workspace 必须释放相关 transport 和时间线。
- Mock 只能从当前 HTTP 安全快照创建，创建后不依赖来源 Request，且不支持 WebSocket/gRPC 模拟。
- Secret、token、Cookie、API Key、Basic 密码和环境解析值不得进入结果、时间线、Mock、通知或可见错误。

## 协议验收

统一示例和本地协议服务说明见 [local-protocol-testing.md](local-protocol-testing.md)。服务端权威契约位于 [SERVER_CAPABILITIES.md](../../SERVER_CAPABILITIES.md)。

```bash
flutter analyze
flutter test
flutter build linux
```

修改跨模块流程后必须同时更新 OpenSpec、README、协议手册和相关测试。
