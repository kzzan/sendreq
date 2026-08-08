import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';
import 'documentation_export_actions.dart';

/// 文档草稿面板：根据最新响应快照生成并展示 API 参考文档、cURL 与响应示例。
class DocumentationPanel extends StatelessWidget {
  /// 构造文档草稿面板。
  const DocumentationPanel({super.key, required this.viewModel});

  /// 工作区视图模型，提供文档草稿与生成结果。
  final WorkspaceViewModel viewModel;

  /// 构建文档草稿面板：无草稿时展示引导态，有草稿时渲染文档与代码示例。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = viewModel.documentationDraft;
    final canTryDraft = viewModel.canTryDocumentationDraft;
    // 尚无文档草稿时展示引导态，提示用户先从集合中打开请求。
    if (draft == null) {
      return Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(12),
        child: DensePanel(
          child: Center(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noDocumentationDraft,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.documentationDraftDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: viewModel.openCollections,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: Text(l10n.openCollections),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 草稿存在时强制取生成的文档内容进行渲染。
    final documentation = viewModel.generatedDocumentation!;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            title: l10n.documentationDraft,
            subtitle: l10n.fromResponseSnapshot,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: canTryDraft
                      ? viewModel.tryDocumentationDraft
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(l10n.tryIt),
                ),
                const SizedBox(width: 6),
                DenseIconButton(
                  icon: Icons.copy_all_outlined,
                  tooltip: l10n.copyApiReference,
                  onPressed: () => copyToClipboard(
                    context,
                    documentation.markdown,
                    l10n.apiReferenceCopied,
                  ),
                ),
                const SizedBox(width: 4),
                DenseIconButton(
                  icon: Icons.download_outlined,
                  tooltip: l10n.exportMarkdown,
                  onPressed: () =>
                      exportMarkdownDocumentationToFile(context, viewModel),
                ),
                const SizedBox(width: 4),
                DenseIconButton(
                  icon: Icons.arrow_back,
                  tooltip: l10n.returnToResponse,
                  onPressed: viewModel.returnFromDocumentationDraft,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DensePanel(
            child: Row(
              children: [
                RequestKindPill(
                  protocol: draft.request.protocol,
                  method: draft.request.method,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MonoText(
                    draft.request.resolvedUrl,
                    color: AppColors.text,
                  ),
                ),
                StatusPill(draft.response.statusCode),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 窄屏下将三个代码块纵向堆叠，宽屏则左右分栏展示。
                if (constraints.maxWidth < 940) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 280,
                          child: _CodeExample(
                            title: l10n.apiReference,
                            code: documentation.markdown,
                            onCopy: () => copyToClipboard(
                              context,
                              documentation.markdown,
                              l10n.apiReferenceCopied,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: _CodeExample(
                            title: l10n.curl,
                            code: documentation.curl,
                            onCopy: () => copyToClipboard(
                              context,
                              documentation.curl,
                              l10n.curlCopied,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: _CodeExample(
                            title: l10n.responseExample,
                            code: draft.response.body,
                            onCopy: () => copyToClipboard(
                              context,
                              draft.response.body,
                              l10n.responseExampleCopied,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CodeExample(
                        title: l10n.apiReference,
                        code: documentation.markdown,
                        onCopy: () => copyToClipboard(
                          context,
                          documentation.markdown,
                          l10n.apiReferenceCopied,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: _CodeExample(
                              title: l10n.curl,
                              code: documentation.curl,
                              onCopy: () => copyToClipboard(
                                context,
                                documentation.curl,
                                l10n.curlCopied,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _CodeExample(
                              title: l10n.responseExample,
                              code: draft.response.body,
                              onCopy: () => copyToClipboard(
                                context,
                                draft.response.body,
                                l10n.responseExampleCopied,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 代码示例卡片：带标题栏与复制按钮的可滚动代码区。
class _CodeExample extends StatelessWidget {
  /// 构造代码示例卡片。
  const _CodeExample({
    required this.title,
    required this.code,
    required this.onCopy,
  });

  /// 卡片标题，如“cURL”。
  final String title;

  /// 要展示的代码内容。
  final String code;

  /// 点击复制按钮时触发的回调。
  final VoidCallback onCopy;

  /// 构建代码示例卡片：标题栏 + 可滚动代码区。
  @override
  Widget build(BuildContext context) => DensePanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            border: Border(bottom: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: MonoText(title, color: AppColors.textFaint, size: 10),
              ),
              DenseIconButton(
                icon: Icons.copy_outlined,
                tooltip: AppLocalizations.of(context).copyNamedValue(title),
                onPressed: onCopy,
                size: 28,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              code,
              style: TextStyle(
                color: AppColors.text,
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
