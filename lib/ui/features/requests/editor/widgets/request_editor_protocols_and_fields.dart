import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_form_controls.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_authentication.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_body.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_grpc_message.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_key_value_table.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 按激活标签分发请求编辑器的正文、鉴权、协议和字段表格。
class RequestTabBody extends StatelessWidget {
  const RequestTabBody({super.key, required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.activeRequestTab) {
      case 'Headers':
        return KeyValueTable(
          title: viewModel.isActiveGrpc
              ? AppLocalizations.of(context).grpcMetadata
              : AppLocalizations.of(context).requestHeaders,
          rows: viewModel.activeDraft.headers,
          headers: true,
          viewModel: viewModel,
        );
      case 'Body':
        if (viewModel.isActiveGrpc) {
          return _grpcMessageEditor();
        }
        if (!viewModel.activeRequestSupportsBody) {
          return _parameterTable(context);
        }
        return BodyEditor(
          body: viewModel.activeDraft.body,
          onChanged: viewModel.updateActiveDraftBody,
          onFormatJson: viewModel.formatActiveDraftJson,
          contentType: viewModel.activeContentType,
          usesJson: viewModel.usesJsonBody,
          usesFormUrlEncoded: viewModel.usesFormUrlEncodedBody,
          usesMultipart: viewModel.usesMultipartBody,
          onContentTypeChanged: viewModel.updateActiveContentType,
          formUrlEncodedFields: viewModel.activeDraft.formUrlEncodedFields,
          onAddFormUrlEncodedField: viewModel.addActiveFormUrlEncodedField,
          onUpdateFormUrlEncodedField:
              viewModel.updateActiveFormUrlEncodedField,
          onRemoveFormUrlEncodedField:
              viewModel.removeActiveFormUrlEncodedField,
          multipartFields: viewModel.activeDraft.multipartFields,
          multipartFiles: viewModel.activeDraft.multipartFiles,
          onAddMultipartField: viewModel.addActiveMultipartField,
          onUpdateMultipartField: viewModel.updateActiveMultipartField,
          onRemoveMultipartField: viewModel.removeActiveMultipartField,
          onAddMultipartFile: viewModel.addActiveMultipartFile,
          onUpdateMultipartFile: viewModel.updateActiveMultipartFile,
          onRemoveMultipartFile: viewModel.removeActiveMultipartFile,
          onApplyMultipartFileFieldName:
              viewModel.updateAllActiveMultipartFileKeyNames,
        );
      case 'Auth':
        return AuthEditor(viewModel: viewModel);
      case 'Protocol':
        return viewModel.isActiveGrpc
            ? _GrpcProtocolEditor(viewModel: viewModel)
            : _WebSocketProtocolEditor(viewModel: viewModel);
      case 'Params':
      default:
        return _parameterTable(context);
    }
  }

  Widget _parameterTable(BuildContext context) => KeyValueTable(
    title: AppLocalizations.of(context).queryParameters,
    rows: viewModel.activeDraft.params,
    headers: false,
    viewModel: viewModel,
  );

  Widget _grpcMessageEditor() => GrpcMessageEditor(
    body: viewModel.activeDraft.body,
    method: viewModel.activeGrpcMethod,
    message: viewModel.activeGrpcRequestMessage,
    preview: viewModel.activeGrpcRequestPreview,
    canSendMessage: viewModel.canSendActiveGrpcMessage,
    canEndSending: viewModel.activeGrpcCall.can(GrpcCallCommand.endSending),
    onChanged: viewModel.updateActiveDraftBody,
    onFormatJson: viewModel.formatActiveDraftJson,
    onSendMessage: viewModel.sendActiveGrpcMessage,
    onEndSending: viewModel.closeActiveGrpcRequestStream,
  );
}

/// gRPC 协议配置：proto 导入、服务/方法选择与 TLS 设置。
class _GrpcProtocolEditor extends StatelessWidget {
  const _GrpcProtocolEditor({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = viewModel.activeDraft.grpc;
    final method = viewModel.activeGrpcMethod;
    return DensePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.grpcConfiguration,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('grpc-discover-services'),
                onPressed: viewModel.isDiscoveringGrpcServices
                    ? null
                    : () async {
                        final error = await viewModel
                            .discoverActiveGrpcServices();
                        if (context.mounted && error != null) {
                          publishUserMessage(
                            context,
                            error.localized(l10n)!,
                            severity: UserMessageSeverity.error,
                            deduplicationKey: 'grpc.reflection.failed',
                          );
                        }
                      },
                icon: viewModel.isDiscoveringGrpcServices
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_search_outlined, size: 16),
                label: Text(
                  viewModel.isDiscoveringGrpcServices
                      ? l10n.discoveringGrpcServices
                      : l10n.discoverGrpcServices,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final path = (await FilePicker.pickFiles(
                    allowedExtensions: const ['proto'],
                    type: FileType.custom,
                  ))?.files.singleOrNull?.path;
                  if (path == null) return;
                  final error = await viewModel.importActiveGrpcProto(path);
                  if (context.mounted && error != null) {
                    publishUserMessage(
                      context,
                      error.localized(l10n)!,
                      severity: UserMessageSeverity.error,
                      deduplicationKey: 'grpc.proto.import.failed',
                    );
                  }
                },
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(l10n.importProto),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            config.useReflection
                ? l10n.grpcSchemaFromReflection
                : config.protoSchema?.path ?? l10n.noProtoSelected,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: l10n.grpcService,
            child: CompactSelect<String>(
              value: config.serviceName,
              items: [
                for (final service in viewModel.activeGrpcServices)
                  CompactSelectItem(value: service.name, label: service.name),
              ],
              onChanged: viewModel.activeGrpcServices.isEmpty
                  ? null
                  : viewModel.selectActiveGrpcService,
            ),
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: l10n.grpcMethod,
            child: CompactSelect<String>(
              value: config.methodName,
              items: [
                for (final candidate in viewModel.activeGrpcMethods)
                  CompactSelectItem(
                    value: candidate.name,
                    label: candidate.name,
                  ),
              ],
              onChanged: viewModel.activeGrpcMethods.isEmpty
                  ? null
                  : viewModel.selectActiveGrpcMethod,
            ),
          ),
          if (method != null &&
              (method.clientStreaming || method.serverStreaming))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MonoText(
                method.clientStreaming && method.serverStreaming
                    ? l10n.grpcBidirectionalStreaming
                    : method.clientStreaming
                    ? l10n.grpcClientStreaming
                    : l10n.grpcServerStreaming,
                color: context.chakra.colorPaletteFg,
                size: 11,
              ),
            ),
          const SizedBox(height: 8),
          InlineSwitch(
            label: l10n.grpcTls,
            helperText: l10n.grpcMetadataHint,
            value: config.useTls,
            onChanged: viewModel.updateActiveGrpcUseTls,
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: l10n.grpcDeadline,
            child: KeyedSubtree(
              key: ValueKey('grpc-deadline-${viewModel.activeRequest.id}'),
              child: TextFormField(
                key: const Key('grpc-deadline-input'),
                initialValue: config.deadlineMs,
                keyboardType: TextInputType.number,
                onChanged: viewModel.updateActiveGrpcDeadline,
                decoration: InputDecoration(
                  hintText: l10n.grpcDeadlineHint,
                  suffixText: l10n.millisecondsShort,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// WebSocket 握手子协议编辑器。
class _WebSocketProtocolEditor extends StatefulWidget {
  const _WebSocketProtocolEditor({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  State<_WebSocketProtocolEditor> createState() =>
      _WebSocketProtocolEditorState();
}

class _WebSocketProtocolEditorState extends State<_WebSocketProtocolEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.viewModel.activeDraft.webSocket.subprotocols.join(', '),
    );
  }

  @override
  void didUpdateWidget(covariant _WebSocketProtocolEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final source = widget.viewModel.activeDraft.webSocket.subprotocols.join(
      ', ',
    );
    if (_controller.text != source) _controller.text = source;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DensePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).webSocketProtocol,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).webSocketProtocolHint,
          style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controller,
          onChanged: widget.viewModel.updateActiveWebSocketSubprotocols,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).subprotocols,
            hintText: AppLocalizations.of(context).subprotocolsHint,
          ),
        ),
      ],
    ),
  );
}
