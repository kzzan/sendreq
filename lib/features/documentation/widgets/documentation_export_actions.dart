import 'package:flutter/material.dart';

import '../../../data/services/markdown_documentation_exporter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../workspace/view_models/workspace_view_model.dart';

/// 将当前文档草稿导出到设置中指定的 Markdown 输出目录。
Future<void> exportMarkdownDocumentationToFile(
  BuildContext context,
  WorkspaceViewModel viewModel,
) async {
  final l10n = AppLocalizations.of(context);
  final draft = viewModel.documentationDraft;
  final documentation = viewModel.generatedDocumentation;
  if (draft == null || documentation == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.configureDocumentationOutputDirectory)),
    );
    return;
  }

  try {
    final file = await const MarkdownDocumentationExporter().export(
      documentation: documentation,
      draft: draft,
      outputDirectory: await viewModel.ensureDocumentationOutputDirectory(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.markdownExportedTo(file.path))),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.markdownExportFailed(error.toString()))),
      );
    }
  }
}
