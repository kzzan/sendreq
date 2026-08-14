# 本地协议验收

sendreq 的 **Sendreq Demo Example** 使用三个仓库外部、本地启动、只监听回环地址的验收服务：

```bash
cd ../go-rest && go run .
cd ../go-ws && go run .
cd ../go-grpc && go run .
```

默认地址为 REST `http://127.0.0.1:8081`、WebSocket `ws://127.0.0.1:8080`、gRPC `http://127.0.0.1:50051`。端点、认证和输入限制以 [SERVER_CAPABILITIES.md](../../SERVER_CAPABILITIES.md) 为准。

## Environment

在 Request 顶栏选择目标 Environment 后立即用于下一次调用，不需要保存。仓库默认数据不会自动创建产品内置协议服务环境；验收或本地调试时请显式创建/选择指向上述服务的 Environment，或在 Request 级 Auth 中直接配置凭据。只有编辑变量、Secret、Auth 或环境结构才需要 Apply/Discard。

运行中的 WebSocket/gRPC 会话保留启动时的 Environment/Auth 快照。切换 Environment 或修改 token 后，旧会话继续运行并提示 Reconnect/Restart。

## REST

依次发送 List users、Create user、Replace user 1、Patch user 1、API key users、Delete user 1，预期状态分别为 `200/201/200/200/200/204`。响应只保留在当前 Request 中。

从任一当前 HTTP 响应创建 Mock，确认响应正文和 headers 已脱敏。重启后 Mock 定义仍在但状态为 stopped，必须显式 Start 才监听 `127.0.0.1`。

## WebSocket

- Local echo：Bearer
- Basic echo：Basic
- API key echo：API Key
- Public echo：No auth

连接后发送 Text、JSON、XML 和 MessagePack。每条消息应在当前 Request 的有界时间线中显示。切换页面后继续接收；关闭 Request 后释放连接和时间线。

## gRPC

gRPC Request 默认 No auth。只有服务要求时才选择 Bearer、Basic 或 API Key；No auth 时不得发送 `authorization` metadata。

| Request | RPC shape | Auth | 预期 |
| --- | --- | --- | --- |
| Create order | unary | No auth | status `0`，单个格式化 JSON 响应 |
| Get order | unary | API Key | status `0`，错误 key 返回 status `16` |
| Submit orders | client streaming | Basic | Start，Send next，End sending，单个汇总响应 |
| Order chat | bidirectional streaming | Bearer | 多次 Send next，同时接收入站消息 |
| Watch orders | server streaming | Bearer | 按顺序接收 created/processing/completed |

请求 Preview、每条 outbound 与 inbound 消息都应使用两空格格式化 JSON，并支持事件折叠、节点折叠和复制。unary 不显示流发送状态；client/bidirectional stream 可以 End sending；所有运行中调用可以 Cancel，终态可以 Restart。

认证错误显示 gRPC status `16` 和与当前 Auth 来源匹配的修复提示。更新请求或 Environment token 后，必须显式 Restart；旧 HTTP/2 流不得被热替换。

## 开放实例

可在不同端口启动无鉴权兼容实例：

```bash
cd ../go-ws && PORT=8082 SENDREQ_REQUIRE_AUTH=0 go run .
cd ../go-grpc && PORT=50052 SENDREQ_REQUIRE_AUTH=0 go run .
```

指向这些实例时使用 No auth，确认 WebSocket handshake 和 gRPC metadata 都不包含 Authorization。

## 自动化验证

默认与开放实例同时运行后执行：

```bash
SENDREQ_LIVE_PROTOCOL_SERVICES=1 flutter test test/go_protocol_interop_test.dart
flutter test test/protocol_server_contract_test.dart
flutter analyze
flutter test
```

测试输出、当前响应、长连接时间线、Mock、通知和可见错误均不得包含真实 token、Cookie、API Key、Basic 密码或环境 Secret。
