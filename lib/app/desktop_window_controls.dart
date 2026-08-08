import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../features/workspace/application/workspace_window_controls.dart';

/// 桌面窗口控制端口的适配器，向 Workspace 隔离具体窗口插件与托盘规则。
class DesktopWorkspaceWindowControls implements WorkspaceWindowControls {
  /// 创建桌面窗口控制适配器。
  const DesktopWorkspaceWindowControls();

  @override
  Future<void> close() => DesktopWindowControls.close();

  @override
  Future<void> minimize() => DesktopWindowControls.minimize();
}

/// 桌面窗口控制系统：按平台会话初始化系统托盘，并封装最小化/关闭行为。
abstract final class DesktopWindowControls {
  // Niri 会话使用的托盘控制器（惰性初始化）。
  static final _LinuxTrayController _linuxTray = _LinuxTrayController();

  /// 初始化窗口控件；在 Niri 会话中额外启用系统托盘。
  static Future<void> initialize() async {
    // 仅在 Niri 合成器会话下初始化托盘。
    if (isNiriSession(Platform.environment)) {
      await _linuxTray.initialize();
    }
  }

  /// 通过环境变量判断当前是否为 Niri 合成器会话。
  static bool isNiriSession(Map<String, String> environment) {
    final desktop = environment['XDG_CURRENT_DESKTOP']?.toLowerCase() ?? '';
    // 同时匹配 NIRI_SOCKET 与 XDG_CURRENT_DESKTOP 两种识别方式。
    return environment['NIRI_SOCKET']?.isNotEmpty == true ||
        desktop.split(':').contains('niri');
  }

  /// 最小化窗口；在 Niri 会话中改为隐藏到系统托盘。
  static Future<void> minimize() async {
    if (isNiriSession(Platform.environment)) {
      // 隐藏窗口以驻留托盘，用户可通过托盘菜单再次唤出。
      await _linuxTray.initialize();
      await windowManager.hide();
      return;
    }
    await windowManager.minimize();
  }

  /// 关闭主窗口。
  static Future<void> close() => windowManager.close();
}

/// Niri 会话下的系统托盘控制器：提供图标与“显示/退出”菜单。
class _LinuxTrayController with TrayListener {
  // 避免重复注册监听与设置菜单的标记。
  bool _initialized = false;

  /// 注册托盘监听并配置图标与右键菜单（仅首次生效）。
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    trayManager.addListener(this);
    await trayManager.setIcon(_iconPath);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_sendreq', label: 'Show sendreq'),
          MenuItem.separator(),
          MenuItem(key: 'exit_sendreq', label: 'Exit sendreq'),
        ],
      ),
    );
    _initialized = true;
  }

  // 托盘图标位于可执行文件同级目录 data 下的相对路径。
  String get _iconPath => File(
    Platform.resolvedExecutable,
  ).parent.uri.resolve('data/tray_icon.png').toFilePath();

  /// 显示并聚焦主窗口。
  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  // 单击托盘图标时唤出主窗口。
  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  // 根据菜单项键处理“显示”或“退出”动作。
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_sendreq':
        _showWindow();
      case 'exit_sendreq':
        windowManager.close();
    }
  }
}
