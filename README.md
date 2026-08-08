# sendreq

sendreq 是面向开发与测试团队的桌面 API 工作台。它把请求编辑、协议调试、环境变量、接口资产和执行记录放在一个本地优先的工作区中，帮助使用者更快地复现、验证和交付接口行为。

## 核心能力

- **多协议调试**：发送 HTTP 请求、连接 WebSocket，并通过导入 `.proto` 文件发起 gRPC 调用。
- **接口资产管理**：以 Collection、Folder 和 Request 组织接口；可导入受限的 OpenAPI 3.x JSON，并导出 HTTP 请求的 OpenAPI 3.0.3 JSON。
- **环境与变量**：管理多个环境，在 URL、请求头和正文中解析变量；敏感请求头在历史和导出内容中保持脱敏。
- **请求与响应工作流**：支持认证、查询参数、请求头、JSON、表单和 multipart 请求体，保留执行快照与近期历史记录。
- **本地协作产物**：从响应快照生成 Markdown 接口文档；提供 Quick Mock 以便本地验证接口响应。
- **本地优先存储**：工作区、环境和历史保存在系统应用数据目录；文档与 OpenAPI 默认导出到 `Documents/sendreq`，也可在设置中自定义目录。

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
