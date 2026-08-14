import 'package:flutter/material.dart';

import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/formatted_json_viewer.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// gRPC 请求消息编辑器与 protobuf schema 提示。
class GrpcMessageEditor extends StatefulWidget {
  const GrpcMessageEditor({
    super.key,
    required this.body,
    required this.method,
    required this.message,
    required this.preview,
    required this.canSendMessage,
    required this.canEndSending,
    required this.onChanged,
    required this.onFormatJson,
    required this.onSendMessage,
    required this.onEndSending,
  });

  final String body;
  final ProtobufMethodDescriptor? method;
  final ProtobufMessageDescriptor? message;
  final ProtobufEncodePreview? preview;
  final bool canSendMessage;
  final bool canEndSending;
  final ValueChanged<String> onChanged;
  final String? Function() onFormatJson;
  final Future<void> Function() onSendMessage;
  final Future<void> Function() onEndSending;

  @override
  State<GrpcMessageEditor> createState() => _GrpcMessageEditorState();
}

class _GrpcMessageEditorState extends State<GrpcMessageEditor> {
  late final TextEditingController _controller;
  late FormattedJsonContent _jsonContent;
  final _scrollController = ScrollController();
  var _showPreview = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.body);
    _jsonContent = FormattedJsonContent.parse(widget.body);
  }

  @override
  void didUpdateWidget(covariant GrpcMessageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      _jsonContent = FormattedJsonContent.parse(widget.body);
    }
    if (_controller.text != widget.body) {
      _controller.value = TextEditingValue(
        text: widget.body,
        selection: TextSelection.collapsed(offset: widget.body.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final method = widget.method;
    final message = widget.message;
    final preview = widget.preview;
    final valid = preview?.isSuccess == true;
    final json = _jsonContent;
    final statusColor = valid ? context.chakra.success : context.chakra.error;
    return DensePanel(
      key: const Key('grpc-message-editor'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.chakra.bgEmphasized,
              border: Border(bottom: BorderSide(color: context.chakra.border)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.input_outlined,
                  size: 16,
                  color: context.chakra.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoText(
                        l10n.grpcRequestMessage.toUpperCase(),
                        color: context.chakra.fgSubtle,
                        size: 10,
                        weight: FontWeight.w700,
                      ),
                      MonoText(
                        method?.requestType ?? l10n.grpcNoRequestSchema,
                        color: context.chakra.fg,
                        size: 11,
                      ),
                    ],
                  ),
                ),
                if (method != null)
                  _GrpcModePill(clientStreaming: method.clientStreaming),
              ],
            ),
          ),
          if (message == null)
            Expanded(
              child: Center(
                child: Text(
                  l10n.grpcNoRequestSchema,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  _GrpcInputSectionLabel(
                    label: l10n.grpcRequestMessage,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (preview != null) ...[
                          MonoText(
                            valid
                                ? l10n.byteCount(preview.byteLength!)
                                : l10n.grpcWireInvalid,
                            color: statusColor,
                            size: 10,
                            weight: FontWeight.w700,
                          ),
                          const SizedBox(width: 8),
                        ],
                        SegmentedTabs(
                          key: const Key('grpc-json-mode'),
                          tabs: [l10n.edit, l10n.preview],
                          active: _showPreview ? l10n.preview : l10n.edit,
                          onSelected: (value) {
                            if (value == l10n.preview && !json.isJson) return;
                            setState(
                              () => _showPreview = value == l10n.preview,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 196,
                    decoration: ChakraSlotRecipes.codeSurface(context.chakra),
                    child: _showPreview && json.isJson
                        ? SingleChildScrollView(
                            key: const Key('grpc-message-json-preview'),
                            padding: const EdgeInsets.all(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: FormattedJsonTree(
                                value: json.value,
                                nodeKeyPrefix: 'grpc-request-json',
                                textStyle: TextStyle(
                                  color: context.chakra.fg,
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  height: 1.52,
                                ),
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: TextFormField(
                              key: const Key('grpc-message-input'),
                              controller: _controller,
                              scrollController: _scrollController,
                              onChanged: widget.onChanged,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: TextStyle(
                                color: context.chakra.fg,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                height: 1.52,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(12),
                                hintText: '{}',
                                hintStyle: TextStyle(
                                  color: context.chakra.fgSubtle,
                                ),
                              ),
                            ),
                          ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final error = widget.onFormatJson();
                            if (error != null) {
                              publishUserMessage(
                                context,
                                error.localized(l10n)!,
                                severity: UserMessageSeverity.warning,
                                deduplicationKey: 'grpc.message.format.failed',
                              );
                            }
                            if (error == null) setState(() {});
                          },
                          icon: const Icon(Icons.format_align_left, size: 15),
                          label: Text(l10n.formatJson),
                        ),
                        const Spacer(),
                        if (method?.clientStreaming == true &&
                            widget.canEndSending)
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  key: const Key('grpc-message-end-sending'),
                                  onPressed: widget.onEndSending,
                                  icon: const Icon(
                                    Icons.call_end_outlined,
                                    size: 15,
                                  ),
                                  label: Text(l10n.grpcEndRequestStream),
                                ),
                                if (widget.canSendMessage)
                                  FilledButton.icon(
                                    key: const Key('grpc-message-send-next'),
                                    onPressed: valid
                                        ? widget.onSendMessage
                                        : null,
                                    icon: const Icon(
                                      Icons.send_outlined,
                                      size: 15,
                                    ),
                                    label: Text(l10n.grpcSendMessage),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (preview?.isSuccess == false) ...[
                    const SizedBox(height: 2),
                    _GrpcValidationNotice(message: preview!.error!),
                    const SizedBox(height: 8),
                  ],
                  _GrpcInputSectionLabel(label: l10n.grpcMessageSchema),
                  const SizedBox(height: 6),
                  for (final field in message.fields)
                    _GrpcSchemaField(
                      field: field,
                      oneof: field.oneofIndex == null
                          ? null
                          : message.oneofs[field.oneofIndex!],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GrpcInputSectionLabel extends StatelessWidget {
  const _GrpcInputSectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelWidget = MonoText(
        label.toUpperCase(),
        color: context.chakra.fgSubtle,
        size: 10,
      );
      if (trailing != null && constraints.maxWidth < 360) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        );
      }
      return Row(children: [labelWidget, const Spacer(), ?trailing]);
    },
  );
}

class _GrpcModePill extends StatelessWidget {
  const _GrpcModePill({required this.clientStreaming});

  final bool clientStreaming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = clientStreaming
        ? l10n.grpcClientStreaming
        : l10n.grpcCallPayload;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.chakra.success.withValues(alpha: 0.12),
        border: Border.all(
          color: context.chakra.success.withValues(alpha: 0.55),
        ),
        borderRadius: ChakraRadii.control,
      ),
      child: MonoText(
        label,
        color: context.chakra.success,
        size: 9,
        weight: FontWeight.w700,
      ),
    );
  }
}

class _GrpcSchemaField extends StatelessWidget {
  const _GrpcSchemaField({required this.field, this.oneof});

  final ProtobufFieldDescriptor field;
  final String? oneof;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: context.chakra.bgEmphasized,
        border: Border.all(color: context.chakra.border),
        borderRadius: ChakraRadii.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: MonoText(
                  '#${field.number}',
                  color: context.chakra.fgSubtle,
                  size: 10,
                ),
              ),
              Expanded(
                child: MonoText(
                  field.name,
                  color: context.chakra.colorPaletteFg,
                  size: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MonoText(
                  _grpcFieldType(field),
                  color: context.chakra.warning,
                  size: 10,
                ),
                if (field.repeated)
                  _GrpcConstraintPill(label: l10n.grpcFieldRepeated),
                if (oneof != null)
                  _GrpcConstraintPill(label: l10n.grpcFieldOneof(oneof!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrpcValidationNotice extends StatelessWidget {
  const _GrpcValidationNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: context.chakra.error.withValues(alpha: 0.1),
      border: Border.all(color: context.chakra.error.withValues(alpha: 0.45)),
      borderRadius: ChakraRadii.control,
    ),
    child: Text(
      message,
      style: TextStyle(
        color: context.chakra.error,
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        height: 1.4,
      ),
    ),
  );
}

class _GrpcConstraintPill extends StatelessWidget {
  const _GrpcConstraintPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 110),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: context.chakra.colorPaletteFg.withValues(alpha: 0.1),
      borderRadius: ChakraRadii.control,
    ),
    child: MonoText(
      label,
      color: context.chakra.colorPaletteFg,
      size: 9,
      weight: FontWeight.w700,
    ),
  );
}

String _grpcFieldType(ProtobufFieldDescriptor field) => switch (field.type) {
  8 => 'bool',
  5 => 'int32',
  13 => 'uint32',
  3 => 'int64',
  4 => 'uint64',
  17 => 'sint32',
  18 => 'sint64',
  9 => 'string',
  12 => 'bytes',
  14 => field.typeName?.split('.').last ?? 'enum',
  11 => field.typeName?.split('.').last ?? 'message',
  _ => 'field',
};
