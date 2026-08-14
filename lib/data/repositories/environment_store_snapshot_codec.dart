import 'dart:convert';

import 'package:sendreq/data/repositories/in_memory_environment_store_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';

/// Immutable hand-off between persistence decoding and the mutable store state.
class EnvironmentStoreSeed {
  EnvironmentStoreSeed({
    required Iterable<EnvironmentProfile> profiles,
    required this.activeEnvironmentId,
    required Iterable<StoredEnvironmentVariable> globalVariables,
    required Map<String, Iterable<StoredEnvironmentVariable>>
    variablesByEnvironment,
  }) : profiles = List<EnvironmentProfile>.unmodifiable(profiles),
       globalVariables = List<StoredEnvironmentVariable>.unmodifiable(
         globalVariables,
       ),
       variablesByEnvironment =
           Map<String, List<StoredEnvironmentVariable>>.unmodifiable({
             for (final entry in variablesByEnvironment.entries)
               entry.key: List<StoredEnvironmentVariable>.unmodifiable(
                 entry.value,
               ),
           });

  final List<EnvironmentProfile> profiles;
  final String activeEnvironmentId;
  final List<StoredEnvironmentVariable> globalVariables;
  final Map<String, List<StoredEnvironmentVariable>> variablesByEnvironment;
}

/// Owns the persisted environment document shape and its validation.
class EnvironmentStoreSnapshotCodec {
  const EnvironmentStoreSnapshotCodec();

  EnvironmentStoreSeed sample() => EnvironmentStoreSeed(
    profiles: [
      EnvironmentProfile(
        id: 'staging',
        workspaceId: 'workspace-main',
        name: 'Staging',
        authentication: const RequestAuthentication.bearer('{{token}}'),
      ),
      EnvironmentProfile(
        id: 'production',
        workspaceId: 'workspace-main',
        name: 'Production',
        authentication: const RequestAuthentication.bearer('{{token}}'),
      ),
      const EnvironmentProfile(
        id: 'geoip-lookup',
        workspaceId: 'workspace-main',
        name: 'GeoIP Lookup',
      ),
      EnvironmentProfile(
        id: 'reurl-production',
        workspaceId: 'workspace-main',
        name: 'Reurl Production',
        authentication: const RequestAuthentication.bearer('{{token}}'),
      ),
    ],
    activeEnvironmentId: 'staging',
    globalVariables: const [
      StoredEnvironmentVariable(
        'global-timeout',
        'Global',
        'timeout',
        '8000',
        EnvironmentVariableType.number,
      ),
    ],
    variablesByEnvironment: {
      'staging': const [
        StoredEnvironmentVariable(
          'staging-base-url',
          'Staging',
          'baseUrl',
          'https://staging.sendreq.io',
          EnvironmentVariableType.string,
          isRequired: true,
        ),
        StoredEnvironmentVariable(
          'staging-token',
          'Staging',
          'token',
          'staging-token-value',
          EnvironmentVariableType.secret,
          isProtected: true,
        ),
      ],
      'production': const [
        StoredEnvironmentVariable(
          'production-base-url',
          'Production',
          'baseUrl',
          'https://api.sendreq.io',
          EnvironmentVariableType.string,
          isRequired: true,
        ),
        StoredEnvironmentVariable(
          'production-token',
          'Production',
          'token',
          'production-token-value',
          EnvironmentVariableType.secret,
          isProtected: true,
        ),
      ],
      'geoip-lookup': const [
        StoredEnvironmentVariable(
          'geoip-base-url',
          'GeoIP Lookup',
          'baseUrl',
          'https://www.reurl.to',
          EnvironmentVariableType.string,
          isRequired: true,
        ),
        StoredEnvironmentVariable(
          'geoip-domain',
          'GeoIP Lookup',
          'domain',
          'qq.com',
          EnvironmentVariableType.string,
        ),
        StoredEnvironmentVariable(
          'geoip-token',
          'GeoIP Lookup',
          'token',
          '',
          EnvironmentVariableType.secret,
          isProtected: true,
        ),
      ],
      'reurl-production': const [
        StoredEnvironmentVariable(
          'reurl-base-url',
          'Reurl Production',
          'baseUrl',
          'https://api.reurl.to',
          EnvironmentVariableType.string,
          isRequired: true,
        ),
        StoredEnvironmentVariable(
          'reurl-token',
          'Reurl Production',
          'token',
          '',
          EnvironmentVariableType.secret,
          isProtected: true,
        ),
        StoredEnvironmentVariable(
          'reurl-ip',
          'Reurl Production',
          'ip',
          '1.1.1.1',
          EnvironmentVariableType.string,
        ),
        StoredEnvironmentVariable(
          'reurl-lang',
          'Reurl Production',
          'lang',
          'en',
          EnvironmentVariableType.string,
        ),
      ],
    },
  );

  EnvironmentStoreSeed decode(Map<String, dynamic> source) {
    final profilesSource = source['profiles'];
    final globalSource = source['globalVariables'];
    final variablesSource = source['variablesByEnvironment'];
    final activeId = source['activeEnvironmentId'];
    if (profilesSource is! List ||
        globalSource is! List ||
        variablesSource is! Map ||
        activeId is! String) {
      throw const FormatException('Invalid environment store data.');
    }
    final profiles = profilesSource.map(_decodeProfile).toList(growable: false);
    if (profiles.isEmpty || !profiles.any((item) => item.id == activeId)) {
      throw const FormatException('Missing active environment.');
    }
    final variables = <String, List<StoredEnvironmentVariable>>{};
    for (final entry in variablesSource.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const FormatException('Invalid environment variables.');
      }
      variables[entry.key as String] = (entry.value as List)
          .map(StoredEnvironmentVariable.fromJson)
          .toList();
    }
    _ensureRequiredBaseUrls(profiles, variables);
    return EnvironmentStoreSeed(
      profiles: profiles,
      activeEnvironmentId: activeId,
      globalVariables: globalSource.map(StoredEnvironmentVariable.fromJson),
      variablesByEnvironment: variables,
    );
  }

  Map<String, Object> encode({
    required Iterable<EnvironmentProfile> profiles,
    required String activeEnvironmentId,
    required Iterable<StoredEnvironmentVariable> globalVariables,
    required Map<String, List<StoredEnvironmentVariable>>
    variablesByEnvironment,
  }) => {
    'profiles': [
      for (final profile in profiles)
        {
          'id': profile.id,
          'workspaceId': profile.workspaceId,
          'name': profile.name,
          'authentication': profile.authentication.toJson(),
        },
    ],
    'activeEnvironmentId': activeEnvironmentId,
    'globalVariables': [
      for (final variable in globalVariables) variable.toJson(),
    ],
    'variablesByEnvironment': {
      for (final entry in variablesByEnvironment.entries)
        entry.key: [for (final variable in entry.value) variable.toJson()],
    },
  };

  Map<String, Object> copy(Map<String, Object> source) =>
      Map<String, Object>.from(
        jsonDecode(jsonEncode(source)) as Map<String, dynamic>,
      );

  int nextVariableId(EnvironmentStoreSeed seed) => _nextId([
    ...seed.globalVariables,
    ...seed.variablesByEnvironment.values.expand((e) => e),
  ], 'variable-');

  int nextEnvironmentId(EnvironmentStoreSeed seed) =>
      _nextStringId(seed.profiles.map((profile) => profile.id), 'environment-');

  EnvironmentProfile _decodeProfile(Object? value) {
    if (value is! Map) throw const FormatException('Invalid profile.');
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final workspaceId = json['workspaceId'];
    final name = json['name'];
    if (id is! String || workspaceId is! String || name is! String) {
      throw const FormatException('Invalid profile fields.');
    }
    final authentication = json['authentication'];
    return EnvironmentProfile(
      id: id,
      workspaceId: workspaceId,
      name: name,
      authentication: authentication is Map
          ? RequestAuthentication.fromJson(
              Map<String, dynamic>.from(authentication),
            )
          : const RequestAuthentication.none(),
    );
  }

  void _ensureRequiredBaseUrls(
    Iterable<EnvironmentProfile> profiles,
    Map<String, List<StoredEnvironmentVariable>> variablesByEnvironment,
  ) {
    for (final profile in profiles) {
      final variables = variablesByEnvironment.putIfAbsent(
        profile.id,
        () => [],
      );
      final index = variables.indexWhere(
        (variable) => variable.key == 'baseUrl',
      );
      if (index < 0) {
        variables.add(requiredBaseUrl(profile));
      } else {
        variables[index] = variables[index].copyWith(
          key: 'baseUrl',
          type: EnvironmentVariableType.string,
          isRequired: true,
        );
      }
    }
  }

  StoredEnvironmentVariable requiredBaseUrl(EnvironmentProfile profile) =>
      StoredEnvironmentVariable(
        '${profile.id}-base-url',
        profile.name,
        'baseUrl',
        '',
        EnvironmentVariableType.string,
        isRequired: true,
      );

  int _nextId(Iterable<StoredEnvironmentVariable> values, String prefix) =>
      _nextStringId(values.map((value) => value.id), prefix);

  int _nextStringId(Iterable<String> values, String prefix) {
    final highest = values.fold<int>(0, (value, item) {
      final suffix = item.startsWith(prefix)
          ? int.tryParse(item.substring(prefix.length))
          : null;
      return suffix != null && suffix >= value ? suffix : value;
    });
    return highest + 1;
  }
}
