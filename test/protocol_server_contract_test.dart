import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';

import 'support/protocol_server_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'repository order proto fixture matches the authoritative server schema',
    () async {
      final authoritative = await File(
        '../go-grpc/proto/order.proto',
      ).readAsString();
      final fixture = await File('assets/demo/order.proto').readAsString();

      expect(fixture, authoritative);
    },
  );

  test(
    'Demo WebSocket requests match the go-ws route and credential matrix',
    () {
      final requests = _requestsById();

      for (final contract in ProtocolServerContract.webSockets) {
        final request = requests[contract.requestId]!;
        final endpoint = Uri.parse(request.urlTemplate);

        expect(request.protocol, ApiRequestProtocol.webSocket);
        expect(
          '${endpoint.scheme}://${endpoint.host}:${endpoint.port}',
          ProtocolServerContract.webSocketEndpoint,
        );
        expect(endpoint.path, contract.path);
        _expectAuthentication(request, contract.credential);
      }
    },
  );

  test(
    'Demo gRPC requests match the go-grpc method and credential matrix',
    () async {
      final requests = _requestsById();
      final descriptor = await const ProtoSourceParser().parseFile(
        ProtocolServerContract.protoAsset,
      );
      final service = descriptor.service(ProtocolServerContract.grpcService)!;

      for (final contract in ProtocolServerContract.grpcs) {
        final request = requests[contract.requestId]!;
        final method = service.methods.singleWhere(
          (item) => item.name == contract.methodName,
        );

        expect(request.protocol, ApiRequestProtocol.grpc);
        expect(request.urlTemplate, ProtocolServerContract.grpcEndpoint);
        expect(
          request.grpc.protoSchema?.path,
          ProtocolServerContract.protoAsset,
        );
        expect(request.grpc.serviceName, ProtocolServerContract.grpcService);
        expect(request.grpc.methodName, contract.methodName);
        expect(request.grpc.useTls, isFalse);
        expect(method.clientStreaming, contract.clientStreaming);
        expect(method.serverStreaming, contract.serverStreaming);
        _expectAuthentication(request, contract.credential);
      }
    },
  );

  test(
    'CreateOrder Demo exercises the complete server-owned request shape',
    () {
      final request = _requestsById()['demo-grpc-create-order']!;
      final payload = jsonDecode(request.bodyTemplate) as Map<String, dynamic>;

      expect(payload['priority'], 'ORDER_PRIORITY_HIGH');
      expect(payload['customer'], isA<Map<String, dynamic>>());
      expect(payload['items'], isA<List<dynamic>>());
      expect(payload['attributes'], isA<Map<String, dynamic>>());
      expect(payload['shipping_address'], isA<Map<String, dynamic>>());
      expect(payload.containsKey('pickup_location'), isFalse);
    },
  );
}

Map<String, ApiRequestDefinition> _requestsById() => {
  for (final folder in DemoExampleCatalog.protocolTestCollection.folders)
    for (final request in folder.requests) request.id: request,
};

void _expectAuthentication(
  ApiRequestDefinition request,
  ProtocolCredentialKind credential,
) {
  switch (credential) {
    case ProtocolCredentialKind.environmentBearer:
      expect(
        request.authenticationSource,
        RequestAuthenticationSource.environment,
      );
      expect(request.authentication.type, RequestAuthenticationType.none);
    case ProtocolCredentialKind.none:
      expect(request.authenticationSource, RequestAuthenticationSource.request);
      expect(request.authentication.type, RequestAuthenticationType.none);
    case ProtocolCredentialKind.basic:
      expect(request.authenticationSource, RequestAuthenticationSource.request);
      expect(request.authentication.type, RequestAuthenticationType.basic);
      expect(
        request.authentication.username,
        ProtocolServerContract.basicUsername,
      );
      expect(
        request.authentication.password,
        ProtocolServerContract.basicPassword,
      );
    case ProtocolCredentialKind.apiKey:
      expect(request.authenticationSource, RequestAuthenticationSource.request);
      expect(request.authentication.type, RequestAuthenticationType.apiKey);
      expect(
        request.authentication.apiKeyName,
        ProtocolServerContract.apiKeyHeader,
      );
      expect(
        request.authentication.apiKeyValue,
        ProtocolServerContract.apiKeyValue,
      );
      expect(request.authentication.apiKeyLocation, ApiKeyLocation.header);
  }
}
