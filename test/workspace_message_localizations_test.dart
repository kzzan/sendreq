import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('localizes the frozen environment in a Bearer failure', () {
    const message =
        'Bearer authentication failed. This call uses the Environment Bearer token from Production. Switch to the intended environment or update its Bearer token, then restart the call.';

    expect(message.localized(en), contains('Production'));
    expect(message.localized(zh), contains('环境“Production”'));
    expect(message.localized(zh), contains('切换到预期环境'));
  });

  test('localizes each request-owned gRPC authentication failure', () {
    expect(
      'Bearer authentication failed. This call uses the request Bearer token. Update the request token, then restart the call.'
          .localized(zh),
      contains('请求中配置的 Bearer 令牌'),
    );
    expect(
      'API key authentication failed. Update the request API key name and value, then restart the call.'
          .localized(zh),
      contains('API Key 名称和值'),
    );
    expect(
      'Basic authentication failed. Update the request username and password, then restart the call.'
          .localized(zh),
      contains('用户名和密码'),
    );
  });

  test('localizes canonical resource and notification messages', () {
    expect('Environment created.'.localized(zh), '环境已创建。');
    expect('Demo example loaded.'.localized(zh), '演示示例已载入。');
    expect('Mock Server created.'.localized(zh), 'Mock Server 已创建。');
    expect(
      'Could not clear notifications. Retry.'.localized(zh),
      '无法清空通知，请重试。',
    );
  });
}
