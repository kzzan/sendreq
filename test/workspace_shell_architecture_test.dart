import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Workspace Shell consumes ports and keeps concrete adapters in composition',
    () {
      for (final path in const [
        'lib/ui/shell/views/workspace_view.dart',
        'lib/ui/shell/view_models/workspace_view_model.dart',
      ]) {
        final source = File(path).readAsStringSync();

        expect(source, isNot(contains('data/services/')), reason: path);
        expect(source, isNot(contains('data/repositories/')), reason: path);
        expect(source, isNot(contains("import 'dart:io'")), reason: path);
        expect(
          source,
          isNot(
            contains(
              'domain/contract_publishing/session_contract_publishing_service.dart',
            ),
          ),
          reason: path,
        );
        expect(
          source,
          isNot(contains('domain/grpc/grpc_call_registry.dart')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('domain/websocket/websocket_session_registry.dart')),
          reason: path,
        );
        expect(
          source,
          isNot(contains("part 'workspace_view_model_")),
          reason: path,
        );
        expect(source, contains('domain/module_boundaries/'), reason: path);
      }

      final compositionRoot = File(
        'lib/app/sendreq_app.dart',
      ).readAsStringSync();
      expect(
        compositionRoot,
        contains('data/services/http_request_execution_runtime.dart'),
      );
      expect(
        compositionRoot,
        contains('data/services/openapi_request_importer.dart'),
      );
      expect(
        compositionRoot,
        contains('data/services/openapi_markdown_documentation_renderer.dart'),
      );
      expect(
        compositionRoot,
        contains('data/services/markdown_documentation_file_exporter.dart'),
      );
      expect(compositionRoot, isNot(contains('history')));
      expect(compositionRoot, isNot(contains('ui/features/documentation/')));
    },
  );

  test('domain modules do not choose Flutter notification presentation', () {
    final domain = Directory('lib/domain');
    for (final entry in domain.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final source = entry.readAsStringSync();

      expect(source, isNot(contains('ScaffoldMessenger')), reason: entry.path);
      expect(source, isNot(contains('SnackBar(')), reason: entry.path);
      expect(source, isNot(contains('showSnackBar')), reason: entry.path);
      expect(
        source,
        isNot(contains('package:flutter/material.dart')),
        reason: entry.path,
      );
    }
  });

  test('feature and shared UI use only the Shell message pipeline', () {
    final roots = [Directory('lib/ui/features'), Directory('lib/ui/core')];
    const prohibited = [
      'ScaffoldMessenger',
      'SnackBar(',
      'showSnackBar',
      'MaterialBanner',
    ];

    for (final root in roots) {
      for (final entry in root.listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        final source = entry.readAsStringSync();
        for (final token in prohibited) {
          expect(source, isNot(contains(token)), reason: entry.path);
        }
      }
    }
  });

  test('Shell and protocol UI consume ports and safe session projections', () {
    final shellPaths = <String>[
      'lib/ui/shell/views/workspace_view.dart',
      'lib/ui/shell/widgets/top_bar.dart',
      'lib/ui/shell/widgets/notification_center.dart',
    ];
    final protocolPaths = <String>[
      for (final directoryPath in const [
        'lib/ui/features/requests/websocket/widgets',
        'lib/ui/features/requests/output/widgets',
      ])
        for (final entry in Directory(directoryPath).listSync())
          if (entry is File && entry.path.endsWith('.dart')) entry.path,
    ];

    for (final path in [...shellPaths, ...protocolPaths]) {
      final source = File(path).readAsStringSync();

      expect(source, isNot(contains('data/services/')), reason: path);
      expect(
        source,
        isNot(contains('DesktopWebSocketTransport')),
        reason: path,
      );
      expect(source, isNot(contains('DesktopGrpcTransport')), reason: path);
      expect(
        source,
        isNot(contains('domain/websocket/websocket_session_registry.dart')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('domain/grpc/grpc_call_registry.dart')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('domain/websocket/websocket_transport.dart')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('domain/grpc/grpc_transport.dart')),
        reason: path,
      );
    }

    final webSocketPanel = protocolPaths
        .where((path) => path.contains('/websocket/'))
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    expect(
      webSocketPanel,
      contains('domain/request_runtime/websocket_session_projection.dart'),
    );

    final responsePanel = protocolPaths
        .where((path) => path.contains('/output/'))
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    expect(
      responsePanel,
      contains('domain/request_runtime/grpc_session_projection.dart'),
    );

    for (final path in shellPaths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('Bearer ')), reason: path);
      expect(source, isNot(contains('Authorization')), reason: path);
      expect(source, isNot(contains('x-api-key')), reason: path);
    }
  });

  test('Workspace Shell has no command navigation or global save surface', () {
    for (final path in const [
      'lib/ui/shell/views/workspace_view.dart',
      'lib/ui/shell/widgets/top_bar.dart',
      'lib/ui/shell/view_models/workspace_view_model.dart',
      'lib/ui/shell/models/workspace_shell_models.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, isNot(contains('CommandPalette')), reason: path);
      expect(source, isNot(contains('openCommand')), reason: path);
      expect(source, isNot(contains('WorkspaceResourceRef')), reason: path);
      expect(source, isNot(contains('WorkspaceActionType.save')), reason: path);
      expect(source, isNot(contains('matchesSendShortcut')), reason: path);
      expect(source, isNot(contains('ShortcutBinding')), reason: path);
      expect(
        source,
        isNot(contains('WorkspaceActionSource.shortcut')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('WorkspaceActionType.openCommand')),
        reason: path,
      );
    }
  });

  test('feature widgets do not construct infrastructure or credentials', () {
    final prohibited = <String>[
      'data/services/',
      'data/repositories/',
      "import 'dart:io'",
      'DesktopWebSocketTransport',
      'DesktopGrpcTransport',
      'WebSocketSessionRegistry(',
      'GrpcCallRegistry(',
      'LocalMockServerRuntime(',
      'RequestAuthentication.bearer(',
      'RequestAuthentication.basic(',
      'RequestAuthentication.apiKey(',
    ];
    final widgetFiles = Directory('lib/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains('/widgets/') || file.path.contains('/views/'),
        )
        .where((file) => file.path.endsWith('.dart'));

    for (final file in widgetFiles) {
      final source = file.readAsStringSync();
      for (final token in prohibited) {
        expect(
          source,
          isNot(contains(token)),
          reason: '${file.path} must delegate $token to an application port.',
        );
      }
    }
  });

  test('leaf feature presentation does not depend on the Shell', () {
    for (final root in const [
      'lib/ui/features/mock',
      'lib/ui/features/settings',
    ]) {
      for (final entry in Directory(root).listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        final source = entry.readAsStringSync();
        expect(
          source,
          isNot(contains('package:sendreq/ui/shell/')),
          reason: '${entry.path} must consume a feature-local projection.',
        );
      }
    }
  });

  test('Flutter layers follow the standard one-way dependency graph', () {
    expect(Directory('lib/core').existsSync(), isFalse);
    expect(Directory('lib/features').existsSync(), isFalse);
    expect(
      Directory('lib/domain/models').existsSync(),
      isFalse,
      reason: 'Domain types must be owned by a named capability.',
    );

    final topLevelDirectories = Directory('lib')
        .listSync()
        .whereType<Directory>()
        .map((directory) => directory.path.split('/').last)
        .toSet();
    expect(
      topLevelDirectories,
      equals({'app', 'data', 'domain', 'ui', 'l10n'}),
    );

    void rejectImports(String root, List<String> prohibited) {
      for (final entry in Directory(root).listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        if (entry.path.endsWith('.g.dart')) continue;
        final source = entry.readAsStringSync();
        for (final token in prohibited) {
          expect(source, isNot(contains(token)), reason: entry.path);
        }
      }
    }

    rejectImports('lib/domain', [
      'package:flutter/',
      'package:sendreq/app/',
      'package:sendreq/data/',
      'package:sendreq/ui/',
    ]);
    rejectImports('lib/data', ['package:sendreq/app/', 'package:sendreq/ui/']);
    rejectImports('lib/ui', ['package:sendreq/app/', 'package:sendreq/data/']);
  });
}
