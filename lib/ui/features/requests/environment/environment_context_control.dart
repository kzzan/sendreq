import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

/// Requests 顶栏唯一的 Environment 上下文入口。
class EnvironmentContextControl extends StatelessWidget {
  const EnvironmentContextControl({
    super.key,
    required this.environments,
    required this.activeEnvironmentId,
    required this.onEnvironmentSelected,
    required this.onManage,
    required this.hasUnsavedChanges,
    this.compact = false,
  });

  final List<EnvironmentProfile> environments;
  final String activeEnvironmentId;
  final ValueChanged<String> onEnvironmentSelected;
  final VoidCallback onManage;
  final bool hasUnsavedChanges;
  final bool compact;

  static const _manageCommand = '__manage_environments__';

  EnvironmentProfile get _activeEnvironment => environments.firstWhere(
    (environment) => environment.id == activeEnvironmentId,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeEnvironment = _activeEnvironment;
    return PopupMenuButton<String>(
      key: const Key('request-topbar-environment-selector'),
      tooltip: l10n.environmentContextTooltip(activeEnvironment.name),
      initialValue: activeEnvironmentId,
      offset: const Offset(0, 36),
      onSelected: (value) {
        if (value == _manageCommand) {
          onManage();
          return;
        }
        onEnvironmentSelected(value);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            l10n.useForNextCall,
            style: TextStyle(
              color: context.chakra.fgSubtle,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final environment in environments)
          PopupMenuItem(
            value: environment.id,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: environment.id == activeEnvironmentId
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: context.chakra.colorPaletteFg,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    environment.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _manageCommand,
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                child: Icon(Icons.settings_outlined, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.manageEnvironments)),
            ],
          ),
        ),
      ],
      child: Semantics(
        key: const Key('environment-context-control'),
        button: true,
        label: l10n.environmentContextTooltip(activeEnvironment.name),
        child: Container(
          width: compact ? 146 : 176,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: context.chakra.bgMuted,
            border: Border.all(
              color: hasUnsavedChanges
                  ? context.chakra.warning
                  : context.chakra.borderEmphasized,
            ),
            borderRadius: ChakraRadii.control,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact
                          ? l10n.environmentLabelShort
                          : l10n.environmentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnsavedChanges
                            ? context.chakra.warning
                            : context.chakra.fgMuted,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      activeEnvironment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.chakra.fg,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    size: 15,
                    color: context.chakra.warning,
                  ),
                ),
              Icon(Icons.expand_more, size: 16, color: context.chakra.fgMuted),
            ],
          ),
        ),
      ),
    );
  }
}
