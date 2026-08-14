import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/domain/grpc/protobuf_descriptor_set.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  testWidgets('gRPC timeline events use finite content height', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final transport = _TestGrpcTransport();
    final viewModel = workspaceViewModel(
      grpcTransport: transport,
      protobufSource: _TestProtobufSource(),
    );
    addTearDown(viewModel.dispose);
    viewModel.selectRequest('demo-grpc-create-order');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) => ResponsePanel(viewModel: viewModel),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(viewModel.activeGrpcMethod, isNotNull);

    viewModel.updateActiveDraftBody('{"name":"api"}');
    await viewModel.sendActiveGrpcRequest();
    transport.call.emit(
      GrpcTransportEvent.message(Uint8List.fromList([10, 3, 97, 112, 105])),
    );
    transport.call.emit(const GrpcTransportEvent.status(0, 'OK'));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'grpc-event-copy-',
            ),
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('grpc-response-send-message')), findsNothing);
    expect(find.text('Send closed'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'grpc-event-toggle-',
            ),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.contains('-tree'),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}

class _TestProtobufSource implements ProtobufSourcePort {
  _TestProtobufSource()
    : _descriptor = const ProtoSourceParser().parse(
        entryPath: 'orders.proto',
        sources: const {
          'orders.proto':
              'syntax = "proto3"; package order.v1; '
              'message CreateOrderRequest { string name = 1; } '
              'message Order { string name = 1; } '
              'service OrderService { '
              'rpc CreateOrder (CreateOrderRequest) returns (Order); }',
        },
      );

  final ProtobufDescriptorSet _descriptor;

  @override
  bool exists(String path) => true;

  @override
  ProtobufDescriptorSet parseDescriptorSet(Uint8List bytes) => _descriptor;

  @override
  Future<ProtobufDescriptorSet> parseSourceFile(String path) async =>
      _descriptor;

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);
}

class _TestGrpcTransport implements GrpcTransport {
  final call = _TestGrpcCall();

  @override
  Future<GrpcCall> start(GrpcCallConfiguration configuration) async => call;
}

class _TestGrpcCall implements GrpcCall {
  final _events = StreamController<GrpcTransportEvent>.broadcast();

  @override
  Stream<GrpcTransportEvent> get events => _events.stream;

  void emit(GrpcTransportEvent event) => _events.add(event);

  @override
  Future<void> send(Uint8List message) async {}

  @override
  Future<void> closeRequestStream() async {}

  @override
  Future<void> cancel() async {
    await _events.close();
  }
}
