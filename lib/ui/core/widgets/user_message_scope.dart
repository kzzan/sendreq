import 'package:flutter/widgets.dart';

import 'package:sendreq/ui/core/application/user_message.dart';

typedef UserMessagePublisher = void Function(UserMessage message);

/// 将 Shell 拥有的消息命令注入到深层 Feature，不暴露通知仓库或队列。
class UserMessageScope extends InheritedWidget {
  const UserMessageScope({
    super.key,
    required this.publish,
    required super.child,
  });

  final UserMessagePublisher publish;

  static UserMessageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserMessageScope>();

  @override
  bool updateShouldNotify(UserMessageScope oldWidget) =>
      publish != oldWidget.publish;
}

/// 发布统一消息通知。独立组件预览未注入 Shell 时保持无副作用。
void publishUserMessage(
  BuildContext context,
  String message, {
  UserMessageSeverity severity = UserMessageSeverity.info,
  String? deduplicationKey,
}) {
  UserMessageScope.maybeOf(context)?.publish(
    UserMessage(
      message: message,
      severity: severity,
      deduplicationKey: deduplicationKey,
    ),
  );
}
