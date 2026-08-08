import 'package:flutter/material.dart';

import '../../../data/services/openapi_file_exporter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../../workspace/view_models/workspace_view_model.dart';

/// 将当前工作区导出的 OpenAPI 文档写入统一的接口文档目录。
Future<void> exportOpenApiToFile(
  BuildContext context,
  WorkspaceViewModel viewModel,
) async {
  // 导出成功：以 SnackBar 提示文档写入的完整路径。
  try {
    final file = await const OpenApiFileExporter().export(
      outputDirectory: await viewModel.ensureDocumentationOutputDirectory(),
      source: viewModel.exportOpenApi(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).openApiExportedTo(file.path),
          ),
        ),
      );
    }
    // 导出失败：将本地化后的错误原因通过 SnackBar 展示给用户。
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).openApiExportFailed(
              error.toString().localized(AppLocalizations.of(context)) ??
                  error.toString(),
            ),
          ),
        ),
      );
    }
  }
}
