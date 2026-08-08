# sendreq 文档

## 统一示例

**Sendreq Demo Example** 是唯一的内置示例集合。首次启动时会创建一份；**Load Demo Example** 会追加同一示例的独立副本，不会覆盖已有集合。

该集合固定包含 7 个独立请求：

- REST：List users、Create user、Replace user 1、Patch user 1、Delete user 1
- WebSocket：Local echo
- gRPC：Create order

端点、请求正文和 gRPC schema 配置的可执行定义位于 `lib/data/demo/demo_example_catalog.dart`。产品文案、测试夹具和协议验收必须与这一来源保持同步。

## 发布约定

推送与 `pubspec.yaml` 版本一致的 `vX.Y.Z` 标签会启动跨平台发布工作流。Windows、macOS、Linux 分别执行静态检查、完整测试、Release 构建和平台包验证；只有三条构建线全部成功后才创建 GitHub Release。

Release 提供 Windows x64 Inno Setup 安装程序、MSI 与便携 ZIP、macOS x64 DMG、Linux x64 DEB 和 RPM，以及每个资产的 SHA-256 校验和。Windows EXE 与 MSI 都会实际安装、启动并卸载；ZIP 会解压并启动；DMG 会挂载并检查应用包；DEB/RPM 会检查包元数据和可执行文件。准确的标签命令与安装说明见仓库 README。

## 协议验收

本地 REST、WebSocket、gRPC 与文档导出的验收路径见 [local-protocol-testing.md](local-protocol-testing.md)。
