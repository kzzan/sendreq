import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/app/desktop_window_controls.dart';

void main() {
  // 验证 Niri 会话的识别逻辑：无论通过 NIRI_SOCKET 环境变量、直接匹配
  // XDG_CURRENT_DESKTOP，还是冒号分隔的复合标识（GNOME:niri）都应判定为 Niri。
  test('detects Niri from its socket or desktop identifier', () {
    expect(
      DesktopWindowControls.isNiriSession({'NIRI_SOCKET': '/run/user/niri'}),
      isTrue,
    );
    expect(
      DesktopWindowControls.isNiriSession({'XDG_CURRENT_DESKTOP': 'niri'}),
      isTrue,
    );
    expect(
      DesktopWindowControls.isNiriSession({
        'XDG_CURRENT_DESKTOP': 'GNOME:niri',
      }),
      isTrue,
    );
  });

  // 反向验证：其他桌面环境或缺失环境变量时不应误判为 Niri，避免启用不兼容的窗口控制。
  test('does not select Niri behavior in other desktop sessions', () {
    expect(
      DesktopWindowControls.isNiriSession({'XDG_CURRENT_DESKTOP': 'KDE'}),
      isFalse,
    );
    expect(DesktopWindowControls.isNiriSession({}), isFalse);
  });
}
