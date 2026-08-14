import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 将 Requests 导出的 OpenAPI 描述写入默认输出目录。
Future<void> exportOpenApiToFile(
  BuildContext context,
  WorkspaceViewModel viewModel,
) async {
  try {
    await viewModel.exportOpenApiToDefaultDirectory();
    if (context.mounted) {
      publishUserMessage(
        context,
        AppLocalizations.of(context).openApiExported,
        severity: UserMessageSeverity.success,
        deduplicationKey: 'openapi.export.succeeded',
      );
    }
  } on Object {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      publishUserMessage(
        context,
        l10n.openApiExportFailed(l10n.notificationActionFailed),
        severity: UserMessageSeverity.error,
        deduplicationKey: 'openapi.export.failed',
      );
    }
  }
}
