import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sendreq/app/desktop_persistence_startup.dart';
import 'package:sendreq/app/desktop_window_controls.dart';
import 'package:sendreq/app/sendreq_app.dart';
import 'package:sendreq/app/window_spec.dart';

/// 应用启动入口：初始化窗口环境、桌面控件与偏好存储后启动 Flutter 应用。
Future<void> main() async {
  // 确保在调用平台 API 之前 Flutter 绑定已就绪。
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化桌面窗口管理器。
  await windowManager.ensureInitialized();
  // 初始化平台相关的窗口控件（如 Niri 会话下的系统托盘）。
  await DesktopWindowControls.initialize();
  // 配置原生窗口的初始尺寸、最小尺寸与隐藏标题栏样式。
  const windowOptions = WindowOptions(
    size: Size(DesktopWindowSpec.width, DesktopWindowSpec.height),
    minimumSize: Size(1100, 700),
    title: DesktopWindowSpec.title,
    titleBarStyle: TitleBarStyle.hidden,
  );
  // 窗口准备就绪后显示并聚焦，避免启动瞬间出现白屏。
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  // 所有迁移按依赖顺序运行；失败时保留旧数据并将恢复状态交给应用界面。
  final startupController = await DesktopPersistenceStartupController.start(
    DesktopPersistenceStartup.production(),
  );
  runApp(SendreqApp(startupController: startupController));
}
