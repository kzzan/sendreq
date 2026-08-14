import 'package:flutter/material.dart';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_form_controls.dart';

/// 编辑器分段标题会在窄宽下保持标题与操作的自然阅读顺序。
class MockEditorSectionHeader extends StatelessWidget {
  const MockEditorSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      );
      final action = TextButton.icon(
        onPressed: onAction,
        icon: const Icon(Icons.add, size: 16),
        label: Text(actionLabel),
      );
      if (constraints.maxWidth < 420) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
            action,
          ],
        );
      }
      return Row(children: [heading, const Spacer(), action]);
    },
  );
}

class MockEndpointEditor extends StatelessWidget {
  const MockEndpointEditor({
    super.key,
    required this.endpoint,
    required this.onChange,
    required this.sourceAction,
  });

  final MockEndpoint endpoint;
  final ValueChanged<MockEndpoint> onChange;
  final Widget sourceAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final method = PopupMenuButton<String>(
        tooltip: AppLocalizations.of(context).changeHttpMethod,
        onSelected: (value) => onChange(
          endpoint.copyWith(matcher: endpoint.matcher.copyWith(method: value)),
        ),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'GET', child: Text('GET')),
          PopupMenuItem(value: 'POST', child: Text('POST')),
          PopupMenuItem(value: 'PUT', child: Text('PUT')),
          PopupMenuItem(value: 'PATCH', child: Text('PATCH')),
          PopupMenuItem(value: 'DELETE', child: Text('DELETE')),
        ],
        child: MethodPill(endpoint.matcher.method),
      );
      final path = TextFormField(
        key: const Key('saved-mock-endpoint-path-input'),
        initialValue: endpoint.matcher.path,
        onChanged: (value) {
          final normalized = value.trim();
          if (!normalized.startsWith('/')) return;
          try {
            onChange(
              endpoint.copyWith(
                matcher: endpoint.matcher.copyWith(path: normalized),
              ),
            );
          } on ArgumentError {
            // Keep the current draft until the path becomes valid.
          }
        },
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).path,
        ),
      );
      final enabled = SizedBox(
        width: 124,
        child: InlineSwitch(
          label: AppLocalizations.of(context).enabled,
          value: endpoint.enabled,
          onChanged: (value) => onChange(endpoint.copyWith(enabled: value)),
        ),
      );
      if (constraints.maxWidth < 600) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [method, const Spacer(), sourceAction]),
            const SizedBox(height: 8),
            path,
            const SizedBox(height: 8),
            enabled,
          ],
        );
      }
      return Row(
        children: [
          method,
          const SizedBox(width: 8),
          Expanded(child: path),
          const SizedBox(width: 8),
          enabled,
          const SizedBox(width: 4),
          sourceAction,
        ],
      );
    },
  );
}

class MockVariantEditor extends StatelessWidget {
  const MockVariantEditor({
    super.key,
    required this.variant,
    required this.onChange,
    required this.onRemove,
    required this.sourceAction,
  });

  final MockResponseVariant variant;
  final ValueChanged<MockResponseVariant> onChange;
  final VoidCallback? onRemove;
  final Widget sourceAction;

  @override
  Widget build(BuildContext context) {
    final matcherEntry = variant.matcher.headers.entries.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = <Widget>[
              SizedBox(
                width: 100,
                child: TextFormField(
                  key: const Key('saved-mock-variant-status-input'),
                  initialValue: '${variant.statusCode}',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final status = int.tryParse(value);
                    if (status != null && status >= 100 && status <= 599) {
                      onChange(variant.copyWith(statusCode: status));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).status,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextFormField(
                  key: const Key('saved-mock-variant-delay-input'),
                  initialValue: '${variant.delayMs}',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final delay = int.tryParse(value);
                    if (delay != null &&
                        delay >= 0 &&
                        delay <= MockResponseVariant.maxDelayMs) {
                      onChange(variant.copyWith(delayMs: delay));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).delayMs,
                  ),
                ),
              ),
              SizedBox(
                width: 148,
                child: InlineSwitch(
                  label: AppLocalizations.of(context).enabled,
                  value: variant.enabled,
                  onChanged: (enabled) =>
                      onChange(variant.copyWith(enabled: enabled)),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: AppLocalizations.of(context).removeVariant,
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              sourceAction,
            ];
            if (constraints.maxWidth < 560) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: fields,
              );
            }
            return Row(
              children: [
                fields[0],
                const SizedBox(width: 8),
                fields[1],
                const SizedBox(width: 8),
                fields[2],
                const Spacer(),
                if (onRemove != null) fields[3],
                fields.last,
              ],
            );
          },
        ),
        if (!variant.matcher.isDefault) ...[
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).matchesRequestHeader,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 190,
                child: TextFormField(
                  initialValue: matcherEntry?.key ?? '',
                  onChanged: (key) {
                    final normalized = key.trim().toLowerCase();
                    if (normalized.isEmpty) return;
                    try {
                      onChange(
                        variant.copyWith(
                          matcher: MockVariantMatcher(
                            headers: {normalized: matcherEntry?.value ?? ''},
                          ),
                        ),
                      );
                    } on ArgumentError {
                      // 安全 Header 名校验由领域模型强制执行。
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).headerName,
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  initialValue: matcherEntry?.value ?? '',
                  onChanged: (value) {
                    final key = matcherEntry?.key;
                    if (key == null) return;
                    onChange(
                      variant.copyWith(
                        matcher: MockVariantMatcher(headers: {key: value}),
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).headerValue,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: TextFormField(
            key: const Key('saved-mock-variant-body-input'),
            initialValue: variant.body,
            expands: true,
            minLines: null,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (value) => onChange(variant.copyWith(body: value)),
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).responseBody,
            ),
          ),
        ),
      ],
    );
  }
}

class CompactSelectionItem<T> {
  const CompactSelectionItem({
    required this.value,
    required this.label,
    this.controlKey,
  });

  final T value;
  final String label;
  final Key? controlKey;
}

/// A compact desktop selection strip with a restrained radio indicator.
class CompactSelectionStrip<T> extends StatelessWidget {
  const CompactSelectionStrip({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<CompactSelectionItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.chakra;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final item in items)
          TextButton(
            key: item.controlKey,
            style: ChakraRecipes.compactSelectableFor(
              context,
              selected: item.value == selected,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => onSelected(item.value),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: ValueKey('compact-selection-indicator-${item.value}'),
                  width: 12,
                  height: 12,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.value == selected
                          ? tokens.colorPaletteSolid
                          : tokens.borderEmphasized,
                    ),
                  ),
                  child: item.value == selected
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.colorPaletteSolid,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
      ],
    );
  }
}

class MockRuntimeBadge extends StatelessWidget {
  const MockRuntimeBadge({super.key, required this.runtime});

  final MockServerRuntimeProjection runtime;

  @override
  Widget build(BuildContext context) {
    final running = runtime.status == MockServerRuntimeStatus.running;
    final color = running ? context.chakra.success : context.chakra.fgSubtle;
    return Tooltip(
      message:
          runtime.loopbackUrl ?? AppLocalizations.of(context).serverStopped,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            running ? Icons.play_circle_outline : Icons.stop_circle_outlined,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          MonoText(
            running
                ? AppLocalizations.of(context).running
                : AppLocalizations.of(context).stopped,
            color: color,
            size: 10,
          ),
        ],
      ),
    );
  }
}

/// 禁用的图标操作仍保留原因提示，避免在工作台里悄然失效。
class MockTooltipIconButton extends StatelessWidget {
  const MockTooltipIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 18)),
  );
}

class MockMenuLabel extends StatelessWidget {
  const MockMenuLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
