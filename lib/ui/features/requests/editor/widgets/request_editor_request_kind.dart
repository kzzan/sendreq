import 'package:flutter/material.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

/// 用户可直接操作的请求种类。HTTP 方法与 WebSocket/gRPC 在此处同级。
enum RequestKind {
  get('get', 'GET', ApiRequestProtocol.http, httpMethod: 'GET'),
  post('post', 'POST', ApiRequestProtocol.http, httpMethod: 'POST'),
  put('put', 'PUT', ApiRequestProtocol.http, httpMethod: 'PUT'),
  patch('patch', 'PATCH', ApiRequestProtocol.http, httpMethod: 'PATCH'),
  delete('delete', 'DELETE', ApiRequestProtocol.http, httpMethod: 'DELETE'),
  webSocket('websocket', 'WebSocket', ApiRequestProtocol.webSocket),
  grpc('grpc', 'gRPC', ApiRequestProtocol.grpc);

  const RequestKind(this.id, this.label, this.protocol, {this.httpMethod});

  final String id;
  final String label;
  final ApiRequestProtocol protocol;
  final String? httpMethod;

  Color color(ChakraSemanticTokens tokens) => switch (this) {
    RequestKind.get => tokens.methodGet,
    RequestKind.post => tokens.methodPost,
    RequestKind.put || RequestKind.patch => tokens.methodPut,
    RequestKind.delete => tokens.methodDelete,
    RequestKind.webSocket => tokens.success,
    RequestKind.grpc => tokens.colorPaletteFg,
  };

  String get compactLabel => this == RequestKind.webSocket ? 'WS' : label;

  bool matches({
    required ApiRequestProtocol protocol,
    required String method,
  }) =>
      this.protocol == protocol &&
      (httpMethod == null || httpMethod == method.toUpperCase());
}

class RequestKindSelector extends StatefulWidget {
  const RequestKindSelector({
    super.key,
    required this.protocol,
    required this.method,
    required this.compact,
    required this.onSelected,
  });

  final ApiRequestProtocol protocol;
  final String method;
  final bool compact;
  final ValueChanged<RequestKind> onSelected;

  @override
  State<RequestKindSelector> createState() => _RequestKindSelectorState();
}

class _RequestKindSelectorState extends State<RequestKindSelector> {
  RequestKind get _selected => RequestKind.values.firstWhere(
    (kind) => kind.matches(protocol: widget.protocol, method: widget.method),
    orElse: () => RequestKind.get,
  );

  Future<void> _openMenu() async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final value = await showMenu<RequestKind>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy + button.size.height + 4, 84, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final kind in RequestKind.values)
          PopupMenuItem<RequestKind>(
            key: Key('request-kind-option-${kind.id}'),
            value: kind,
            child: Row(
              children: [
                SizedBox(
                  width: 82,
                  child: MonoText(
                    kind.label,
                    color: kind.color(context.chakra),
                    size: 11,
                    weight: FontWeight.w800,
                  ),
                ),
                if (kind == _selected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: kind.color(context.chakra),
                  ),
              ],
            ),
          ),
      ],
    );
    if (value != null) widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return SizedBox(
      key: const Key('request-kind-selector'),
      width: widget.compact ? 64 : 92,
      height: 36,
      child: Tooltip(
        message: 'Change request type',
        child: Material(
          color: context.chakra.transparent,
          child: InkWell(
            onTap: _openMenu,
            borderRadius: ChakraRadii.panel,
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                left: widget.compact ? 8 : 10,
                right: widget.compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: selected.color(context.chakra).withValues(alpha: 0.1),
                border: Border.all(
                  color: selected.color(context.chakra).withValues(alpha: 0.62),
                ),
                borderRadius: ChakraRadii.panel,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MonoText(
                      widget.compact ? selected.compactLabel : selected.label,
                      color: selected.color(context.chakra),
                      size: 11.5,
                      weight: FontWeight.w800,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 17,
                    color: selected.color(context.chakra),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
