/// UI 可以发布到 Workspace Shell 的安全会话消息级别。
enum UserMessageSeverity { info, success, warning, error }

/// 应用自有、只在当前会话显示的短消息。
class UserMessage {
  UserMessage({
    required String message,
    this.severity = UserMessageSeverity.info,
    this.deduplicationKey,
  }) : message = message.trim() {
    if (this.message.isEmpty || this.message.length > maxLength) {
      throw ArgumentError.value(
        message,
        'message',
        'User messages must contain 1 to $maxLength characters.',
      );
    }
  }

  static const maxLength = 240;

  final String message;
  final UserMessageSeverity severity;
  final String? deduplicationKey;
}
