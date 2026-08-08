# sendreq

面向开发和测试团队的本地优先 API 工作台。sendreq 将 REST、WebSocket 和 gRPC 调试，以及接口资产、环境变量、Mock、执行历史和接口文档汇集在一个桌面应用中，让接口从调试到交付保持在同一条工作流内。

> A local-first desktop API workbench for development and test teams. sendreq brings REST, WebSocket, and gRPC debugging together with API assets, environments, mocks, execution history, and publishable API documentation.

## 核心能力 | Highlights

### 多端桌面交付 | Cross-platform desktop delivery

- **中文**：提供 Windows、macOS 和 Linux 桌面安装包，适合个人调试、测试验证和团队内部分发。工作区与历史记录默认保存在本地，离线也能继续组织和查看接口资产。
- **English**: Native desktop packages are available for Windows, macOS, and Linux. Workspaces and history are stored locally by default, so API assets remain available when offline.

### 为桌面工作台而构建 | Built for a desktop workbench

- **中文**：客户端采用 Flutter 构建，使用原生桌面窗口与控件能力，不打包 Chromium 运行时。相较于基于 Electron 的同类架构，这通常有利于控制安装体积和常驻资源开销；具体内存占用取决于操作系统、接口数量、响应体大小和实际使用方式，应以目标环境的实测数据为准。
- **English**: The client is built with Flutter and uses native desktop window and control capabilities without bundling a Chromium runtime. Compared with Electron-based architectures, this typically helps control installation size and resident resource overhead. Actual memory use depends on the operating system, request volume, response size, and workload, and should be measured in the target environment.

### REST、WebSocket 与 gRPC | REST, WebSocket, and gRPC

- **中文**：发送 REST 请求，管理查询参数、请求头、认证、JSON、表单与 multipart 请求体；连接并调整 WebSocket 长连接，发送文本、JSON、XML、二进制或 MessagePack 帧，查看完整收发时间线；导入 `.proto` 后调用 gRPC service/method，并查看 Protobuf 响应和 status trailer。
- **English**: Send REST requests with query parameters, headers, authentication, JSON, form, and multipart bodies. Connect to and tune long-lived WebSocket sessions, send text, JSON, XML, binary, or MessagePack frames, and inspect the full inbound/outbound timeline. Import `.proto` files to invoke gRPC services and methods, then inspect Protobuf responses and status trailers.

### 接口文档与 Swagger UI 互通 | API documentation and Swagger UI interoperability

- **中文**：从已验证的请求与响应快照生成 Markdown 接口文档，包含方法、URL、请求信息、响应头、格式化响应示例和 cURL；文档可导出到本地目录。支持导入受限的 OpenAPI 3.x JSON，并将 HTTP 请求导出为 OpenAPI 3.0.3 JSON，可与 Swagger UI 使用同一份 OpenAPI 定义进行展示、维护和交换。
- **English**: Generate Markdown API references from verified request and response snapshots, including method, URL, request details, response headers, formatted examples, and cURL. Export the generated document locally. Import supported OpenAPI 3.x JSON and export HTTP requests as OpenAPI 3.0.3 JSON, so the same definition can be exchanged with and rendered by Swagger UI.

### 从调试到协作 | From debugging to collaboration

- **中文**：使用 Collection、Folder 和 Request 管理接口；在 URL、请求头和正文中解析环境变量；保留执行快照与近期历史；可从最新响应快速创建仅绑定回环地址的本地 Mock，方便前后端并行验证。敏感请求头在历史和导出内容中保持脱敏。
- **English**: Organize APIs with Collections, Folders, and Requests; resolve environment variables in URLs, headers, and bodies; retain execution snapshots and recent history; and create loopback-only local mocks directly from the latest response for parallel frontend and backend verification. Sensitive headers remain redacted in history and exported content.

## 功能一览 | Feature list

| 能力 | 中文 | English |
| --- | --- | --- |
| HTTP/REST 调试 | 支持 GET、POST、PUT、PATCH、DELETE，请求 URL、查询参数、请求头、认证、JSON、表单和 multipart 请求体均可编辑。 | Supports GET, POST, PUT, PATCH, and DELETE with editable URLs, query parameters, headers, authentication, JSON, form, and multipart bodies. |
| 多环境变量 | 创建、编辑与快速切换开发、测试、预发布、生产等环境；在 URL、请求头和正文中引用变量，缺失变量会明确提示。 | Create, edit, and switch among development, test, staging, and production environments; reference variables in URLs, headers, and bodies with explicit missing-variable feedback. |
| 认证与脱敏 | 支持请求级或环境继承的认证配置；敏感请求头在执行历史与导出文档中保持掩码。 | Supports request-level or environment-inherited authentication; sensitive request headers remain masked in execution history and exported documentation. |
| WebSocket 长连接 | 连接 `ws://` / `wss://` 端点，调整连接配置与请求头，连接、断开或重连长连接；发送 Text、JSON、XML、二进制与 MessagePack 帧，按时间线查看出站和入站消息。 | Connect to `ws://` / `wss://` endpoints, adjust connection settings and headers, and connect, disconnect, or reconnect long-lived sessions; send Text, JSON, XML, binary, and MessagePack frames with an inbound/outbound timeline. |
| gRPC 与 Protobuf | 导入 `.proto` 或 descriptor set，选择 service 和 method，配置 TLS 与 metadata，发送动态编码的 Protobuf 请求，查看消息、响应头与 status trailer。 | Import `.proto` files or descriptor sets, select services and methods, configure TLS and metadata, send dynamically encoded Protobuf requests, and inspect messages, headers, and status trailers. |
| OpenAPI / Swagger UI | 导入受支持的 OpenAPI 3.x JSON 为请求集合；将 HTTP 请求导出为 OpenAPI 3.0.3 JSON，与 Swagger UI 使用同一份定义展示、维护和交换。 | Import supported OpenAPI 3.x JSON as request collections; export HTTP requests as OpenAPI 3.0.3 JSON for viewing, maintaining, and exchanging the same definition with Swagger UI. |
| Markdown 接口文档 | 基于成功执行的请求与响应快照生成 Markdown、cURL 和格式化响应示例，并导出到可配置的本地目录。 | Generate Markdown references, cURL, and formatted response examples from executed request and response snapshots, then export them to a configurable local directory. |
| Quick Mock | 手动创建 Mock，或由最近响应创建 Mock；仅绑定回环地址，按 HTTP 方法和路径返回本地响应，适用于前端联调和测试环境验证。 | Create a mock manually or from the latest response; it binds only to loopback and returns local responses by HTTP method and path for frontend integration and test-environment validation. |
| 执行历史与接口资产 | 使用 Collection、Folder、Request 组织接口；保留近期请求执行快照，按成功、失败和关键字回溯调试过程。 | Organize APIs with Collections, Folders, and Requests; retain recent execution snapshots and trace debugging work by status and keyword. |
| 本地优先与可配置输出 | 工作区、环境、偏好与历史保存在系统应用数据目录；Markdown 和 OpenAPI 输出目录可在设置中配置。 | Workspaces, environments, preferences, and history are stored in the system application-data directory; Markdown and OpenAPI output folders are configurable in Settings. |

## 桌面安装包

每个正式版本都会在 GitHub Releases 提供以下 x64 桌面包及对应 SHA-256 文件：

- `sendreq-<version>-windows-x64-setup.exe`：Windows 安装程序，普通账户可直接安装。
- `sendreq-<version>-windows-x64.msi`：Windows MSI 安装程序，适用于企业软件分发和 `msiexec` 静默部署。
- `sendreq-<version>-windows-x64.zip`：Windows 便携版。解压到任意可写目录后直接运行 `sendreq.exe`，无需安装。
- `sendreq-<version>-macos-x64.dmg`：macOS Intel DMG。挂载后将 `sendreq.app` 拖入 Applications。
- `sendreq-<version>-linux-amd64.deb`：Debian、Ubuntu 及兼容发行版安装包。
- `sendreq-<version>-linux-x86_64.rpm`：Fedora、RHEL、openSUSE 及兼容发行版安装包。

下载后先用与平台对应的 `.sha256` 文件校验完整性。Windows 可使用 PowerShell：

```powershell
Get-FileHash .\sendreq-<version>-windows-x64-setup.exe -Algorithm SHA256
```

Linux 安装命令：

```bash
sudo apt install ./sendreq-<version>-linux-amd64.deb
# 或
sudo rpm -Uvh ./sendreq-<version>-linux-x86_64.rpm
```

Windows 安装后可从开始菜单启动 sendreq，也可通过 Windows 设置卸载。macOS DMG 当前未配置 Apple Developer ID 签名和公证，因此 Gatekeeper 可能要求用户在系统设置中明确允许首次启动。

当前发布流程会在 GitHub 的 Windows、macOS、Linux Runner 上分别完成静态检查、完整测试、Release 构建和平台包验证。Windows EXE 与 MSI 都执行“静默安装 -> 启动应用 -> 卸载 -> 文件校验”，便携 ZIP 执行“解压 -> 启动 -> 文件校验”；DMG 执行挂载与应用包结构检查；DEB/RPM 执行包元数据与已打包可执行文件检查。所有门禁成功后，才会创建或更新 GitHub Release。

> Windows SmartScreen 的信誉提示取决于代码签名证书和下载信誉。仓库尚未配置代码签名证书时，安装包功能已通过自动安装验证，但仍可能显示该系统级提示。

## 发布 0.1.0

将 `pubspec.yaml` 中的版本保持为 `0.1.0+1`，创建并推送精确标签 `v0.1.0`：

```bash
git tag v0.1.0
git push origin v0.1.0
```

`Desktop packages and release` 工作流只接受 `vX.Y.Z` 形式且与 `pubspec.yaml` 主版本完全一致的标签。任一平台构建、测试、打包或验证失败时，工作流失败，Release 不会发布不完整的桌面包。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

运行桌面客户端：`flutter run -d windows`、`flutter run -d macos` 或 `flutter run -d linux`。

## 文档与协议 Demo

产品说明、协议验收和维护约定位于仓库内的 [docs](docs/README.md)。首次启动的示例集合统一命名为 **Sendreq Demo Example**，包含 5 个 REST 请求、1 个 WebSocket 请求和 1 个 gRPC 请求。Collection 工具菜单的 **Load Demo Example** 使用同一份示例定义追加一个独立副本，不会覆盖已有数据。

仓库同级的 `go-ws` 与 `go-grpc` 服务可用于协议互通验证；它们不是桌面客户端发布包的一部分。完整启动步骤见[本地协议测试](docs/local-protocol-testing.md)。
