import 'package:flutter/material.dart';

import 'package:sendreq/domain/request_runtime/grpc_session_projection.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';

/// gRPC 会话创建时的冻结上下文；环境变化时同时展示下一次调用环境。
class GrpcSessionSnapshotStrip extends StatelessWidget {
  const GrpcSessionSnapshotStrip({
    super.key,
    required this.call,
    required this.nextEnvironmentName,
  });

  final GrpcCallSnapshot call;
  final String nextEnvironmentName;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 5,
    children: [
      if (call.endpoint != null)
        _SessionDetail(icon: Icons.dns_outlined, label: call.endpoint!),
      _SessionDetail(
        icon: Icons.layers_outlined,
        label: call.requiresRestart
            ? AppLocalizations.of(
                context,
              ).currentSessionEnvironment(call.sessionContext.environmentName)
            : call.sessionContext.environmentName,
      ),
      if (call.requiresRestart)
        _SessionDetail(
          icon: Icons.next_plan_outlined,
          label: AppLocalizations.of(
            context,
          ).nextCallEnvironment(nextEnvironmentName),
          warning: true,
        ),
      _SessionDetail(
        icon: Icons.verified_user_outlined,
        label: call.sessionContext.authenticationLabel,
      ),
      if (call.sessionContext.serviceName != null)
        _SessionDetail(
          icon: Icons.account_tree_outlined,
          label:
              '${call.sessionContext.serviceName}/${call.sessionContext.methodName} (${call.rpcShape.storageValue})',
        ),
      _SessionDetail(
        icon: Icons.schema_outlined,
        label: call.sessionContext.schemaSource.storageValue,
      ),
      _SessionDetail(
        icon: call.sessionContext.useTls
            ? Icons.lock_outline
            : Icons.lock_open_outlined,
        label: call.sessionContext.useTls ? 'TLS' : 'Plaintext',
      ),
      if (call.sessionContext.deadlineMs != null)
        _SessionDetail(
          icon: Icons.timer_outlined,
          label: '${call.sessionContext.deadlineMs} ms',
        ),
      if (call.sessionContext.metadataKeys.isNotEmpty)
        _SessionDetail(
          icon: Icons.list_alt_outlined,
          label: call.sessionContext.metadataKeys.join(', '),
        ),
      if (call.requiresRestart)
        _SessionDetail(
          icon: Icons.restart_alt_outlined,
          label: AppLocalizations.of(context).restartToApplyChanges,
          warning: true,
        ),
    ],
  );
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(
      color: (warning ? context.chakra.warning : context.chakra.bgSubtle)
          .withValues(alpha: warning ? 0.12 : 1),
      border: Border.all(
        color: (warning ? context.chakra.warning : context.chakra.border)
            .withValues(alpha: 0.7),
      ),
      borderRadius: ChakraRadii.control,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: warning ? context.chakra.warning : context.chakra.fgMuted,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: warning ? context.chakra.warning : context.chakra.fgMuted,
            ),
          ),
        ),
      ],
    ),
  );
}
