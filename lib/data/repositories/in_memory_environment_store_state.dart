import 'dart:convert';

import 'package:sendreq/data/repositories/environment_store_snapshot_codec.dart';
import 'package:sendreq/data/repositories/environment_template_resolver.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/domain/environments/environment_authentication_policy.dart';

/// Mutable implementation state kept behind [InMemoryEnvironmentStore].
class EnvironmentStoreState {
  EnvironmentStoreState._(EnvironmentStoreSeed seed)
    : _profiles = seed.profiles.toList(),
      _activeId = seed.activeEnvironmentId,
      _global = seed.globalVariables.toList(),
      _byEnvironment = {
        for (final entry in seed.variablesByEnvironment.entries)
          entry.key: entry.value.toList(),
      },
      _nextVariableId = _codec.nextVariableId(seed),
      _nextEnvironmentId = _codec.nextEnvironmentId(seed) {
    _ensureAuthenticationVariables(_activeId, activeEnvironment.authentication);
    _markSavedBaseline();
  }

  factory EnvironmentStoreState.sample() =>
      EnvironmentStoreState._(_codec.sample());

  factory EnvironmentStoreState.fromJson(Map<String, dynamic> source) =>
      EnvironmentStoreState._(_codec.decode(source));

  static const _codec = EnvironmentStoreSnapshotCodec();
  static const _templateResolver = EnvironmentTemplateResolver();

  final List<EnvironmentProfile> _profiles;
  String _activeId;
  final List<StoredEnvironmentVariable> _global;
  final Map<String, List<StoredEnvironmentVariable>> _byEnvironment;
  final Set<String> _revealedSecretIds = {};
  bool _hasUnsavedChanges = false;
  late Map<String, Object> _savedSnapshot;
  int _nextVariableId;
  int _nextEnvironmentId;

  bool get hasUnsavedChanges => _hasUnsavedChanges;
  EnvironmentProfile get activeEnvironment =>
      _profiles.firstWhere((item) => item.id == _activeId);

  Map<String, Object> toJson() => _codec.encode(
    profiles: _profiles,
    activeEnvironmentId: _activeId,
    globalVariables: _global,
    variablesByEnvironment: _byEnvironment,
  );

  Map<String, Object> savedJsonWithActiveEnvironment() {
    final snapshot = _codec.copy(_savedSnapshot);
    final savedProfiles = (snapshot['profiles'] as List).cast<Map>();
    if (savedProfiles.any((profile) => profile['id'] == _activeId)) {
      snapshot['activeEnvironmentId'] = _activeId;
    }
    return snapshot;
  }

  void _markSavedBaseline() => _savedSnapshot = _codec.copy(toJson());

  void commitSavedSnapshot(Map<String, Object> snapshot) {
    _savedSnapshot = _codec.copy(snapshot);
    final currentConfiguration = _codec.copy(toJson())
      ..remove('activeEnvironmentId');
    final savedConfiguration = _codec.copy(snapshot)
      ..remove('activeEnvironmentId');
    _hasUnsavedChanges =
        jsonEncode(currentConfiguration) != jsonEncode(savedConfiguration);
  }

  StoredEnvironmentVariable _requiredBaseUrl(EnvironmentProfile profile) =>
      _codec.requiredBaseUrl(profile);
}

class _VariableLocation {
  const _VariableLocation(this.variables, this.index);

  final List<StoredEnvironmentVariable> variables;
  final int index;
}

extension EnvironmentStoreStateCommands on EnvironmentStoreState {
  void updateActiveAuthentication(RequestAuthentication authentication) {
    updateEnvironmentAuthentication(
      environmentId: _activeId,
      authentication: authentication,
    );
  }

  void updateEnvironmentAuthentication({
    required String environmentId,
    required RequestAuthentication authentication,
  }) {
    final index = _profiles.indexWhere((item) => item.id == environmentId);
    if (index < 0) throw StateError('Unknown environment: $environmentId');
    final normalized = EnvironmentAuthenticationPolicy.normalize(
      authentication,
    );
    _removeInactiveAuthenticationVariables(environmentId, normalized);
    _profiles[index] = _profiles[index].copyWith(authentication: normalized);
    _ensureAuthenticationVariables(environmentId, normalized);
    _hasUnsavedChanges = true;
  }

  List<EnvironmentProfile> listEnvironments() => List.unmodifiable(_profiles);

  List<EnvironmentVariableView> listVariables({String? environmentId}) {
    final targetId = environmentId ?? _activeId;
    final environment = _profiles.firstWhere((item) => item.id == targetId);
    final authenticationKeys =
        EnvironmentAuthenticationPolicy.referencedVariableKeys(
          environment.authentication,
        );
    return [
      for (final variable in _byEnvironment[targetId]!)
        if (!_isHiddenInactiveAuthenticationVariable(
          variable,
          authenticationKeys,
        ))
          variable.toView(
            revealSecret: _revealedSecretIds.contains(variable.id),
            isAuthenticationBinding: authenticationKeys.contains(variable.key),
          ),
      for (final variable in _global)
        variable.toView(revealSecret: _revealedSecretIds.contains(variable.id)),
    ];
  }

  List<String> listUnusedAuthenticationVariableNames({String? environmentId}) {
    final targetId = environmentId ?? _activeId;
    final environment = _profiles.firstWhere((item) => item.id == targetId);
    final activeKeys = EnvironmentAuthenticationPolicy.referencedVariableKeys(
      environment.authentication,
    );
    return [
      for (final variable in _byEnvironment[targetId]!)
        if (EnvironmentAuthenticationPolicy.removableVariableKeys.contains(
              variable.key,
            ) &&
            !activeKeys.contains(variable.key))
          variable.key,
    ];
  }

  void removeUnusedAuthenticationVariables({String? environmentId}) {
    final targetId = environmentId ?? _activeId;
    final unused = listUnusedAuthenticationVariableNames(
      environmentId: targetId,
    ).toSet();
    if (unused.isEmpty) return;
    final variables = _byEnvironment[targetId]!;
    final removedIds = <String>[];
    variables.removeWhere((variable) {
      final shouldRemove = unused.contains(variable.key);
      if (shouldRemove) removedIds.add(variable.id);
      return shouldRemove;
    });
    _revealedSecretIds.removeAll(removedIds);
    _hasUnsavedChanges = true;
  }

  void setActiveEnvironment(String environmentId) {
    _profiles.firstWhere((item) => item.id == environmentId);
    if (_activeId == environmentId) return;
    _activeId = environmentId;
    _removeInactiveAuthenticationVariables(
      _activeId,
      activeEnvironment.authentication,
    );
    _ensureAuthenticationVariables(_activeId, activeEnvironment.authentication);
  }

  EnvironmentProfile createEnvironment(String name, {bool activate = true}) {
    final profile = EnvironmentProfile(
      id: 'environment-${_nextEnvironmentId++}',
      workspaceId: 'workspace-main',
      name: _validateEnvironmentName(name),
    );
    _profiles.add(profile);
    _byEnvironment[profile.id] = [_requiredBaseUrl(profile)];
    if (activate) _activeId = profile.id;
    _hasUnsavedChanges = true;
    return profile;
  }

  void renameEnvironment(String environmentId, String name) {
    final normalized = _validateEnvironmentName(
      name,
      excludingId: environmentId,
    );
    final index = _profiles.indexWhere(
      (profile) => profile.id == environmentId,
    );
    if (index < 0) throw StateError('Unknown environment: $environmentId');
    _profiles[index] = _profiles[index].copyWith(name: normalized);
    _byEnvironment[environmentId] = [
      for (final variable in _byEnvironment[environmentId]!)
        variable.copyWith(scope: normalized),
    ];
    _hasUnsavedChanges = true;
  }

  bool deleteEnvironment(String environmentId) {
    if (_profiles.length <= 1) return false;
    final index = _profiles.indexWhere(
      (profile) => profile.id == environmentId,
    );
    if (index < 0) throw StateError('Unknown environment: $environmentId');
    final removed = _profiles.removeAt(index);
    final variables = _byEnvironment.remove(removed.id)!;
    _revealedSecretIds.removeAll(variables.map((variable) => variable.id));
    if (_activeId == removed.id) _activeId = _profiles.first.id;
    _hasUnsavedChanges = true;
    return true;
  }

  void updateVariable({
    required String id,
    String? environmentId,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) {
    final targetId = environmentId ?? _activeId;
    final location = _findVariable(id);
    final current = location.variables[location.index];
    final managed =
        identical(location.variables, _byEnvironment[targetId]) &&
        EnvironmentAuthenticationPolicy.allVariableKeys.contains(current.key);
    if (current.isProtected || current.isRequired || managed) {
      final normalized = value == null
          ? null
          : _normalizeValueForType(value, current.type);
      if (normalized == null || normalized == current.value) return;
      location.variables[location.index] = current.copyWith(value: normalized);
      _hasUnsavedChanges = true;
      return;
    }
    final nextType = type ?? current.type;
    final nextValue = value == null && type == null
        ? null
        : _normalizeValueForType(value ?? current.value, nextType);
    location.variables[location.index] = current.copyWith(
      key: key?.trim(),
      value: nextValue,
      type: type,
    );
    _hasUnsavedChanges = true;
  }

  void addVariable({String? environmentId}) {
    final targetId = environmentId ?? _activeId;
    final environment = _profiles.firstWhere((item) => item.id == targetId);
    _byEnvironment[targetId]!.add(
      StoredEnvironmentVariable(
        'variable-${_nextVariableId++}',
        environment.name,
        '',
        '',
        EnvironmentVariableType.string,
      ),
    );
    _hasUnsavedChanges = true;
  }

  void addGlobalVariable() {
    _global.add(
      StoredEnvironmentVariable(
        'variable-${_nextVariableId++}',
        'Global',
        '',
        '',
        EnvironmentVariableType.string,
      ),
    );
    _hasUnsavedChanges = true;
  }

  bool removeVariable(String id) {
    final location = _findVariable(id);
    final variable = location.variables[location.index];
    final managed =
        identical(location.variables, _byEnvironment[_activeId]) &&
        EnvironmentAuthenticationPolicy.allVariableKeys.contains(variable.key);
    if (variable.isProtected || variable.isRequired || managed) return false;
    location.variables.removeAt(location.index);
    _revealedSecretIds.remove(id);
    _hasUnsavedChanges = true;
    return true;
  }

  void toggleSecretVisibility(String id) {
    if (!_revealedSecretIds.add(id)) _revealedSecretIds.remove(id);
  }

  Future<void> saveChanges() async {
    commitSavedSnapshot(toJson());
  }

  void discardChanges() {
    if (!_hasUnsavedChanges) return;
    final selectedId = _activeId;
    final restored = EnvironmentStoreState.fromJson(
      EnvironmentStoreState._codec.copy(_savedSnapshot),
    );
    _profiles
      ..clear()
      ..addAll(restored._profiles);
    _global
      ..clear()
      ..addAll(restored._global);
    _byEnvironment
      ..clear()
      ..addAll(restored._byEnvironment);
    _activeId = _profiles.any((profile) => profile.id == selectedId)
        ? selectedId
        : restored._activeId;
    _nextVariableId = restored._nextVariableId;
    _nextEnvironmentId = restored._nextEnvironmentId;
    _revealedSecretIds.clear();
    _hasUnsavedChanges = false;
    _savedSnapshot = EnvironmentStoreState._codec.copy(restored._savedSnapshot);
  }

  TemplateResolutionResult resolveTemplate(String template) {
    final values = {
      for (final value in _global) value.key: value.value,
      for (final value in _byEnvironment[_activeId]!) value.key: value.value,
    };
    return EnvironmentStoreState._templateResolver.resolve(template, values);
  }

  void _removeInactiveAuthenticationVariables(
    String environmentId,
    RequestAuthentication auth,
  ) {
    final activeKeys = EnvironmentAuthenticationPolicy.referencedVariableKeys(
      auth,
    );
    final variables = _byEnvironment[environmentId]!;
    final removedIds = <String>[];
    variables.removeWhere((variable) {
      final remove =
          EnvironmentAuthenticationPolicy.allVariableKeys.contains(
            variable.key,
          ) &&
          !activeKeys.contains(variable.key);
      if (remove) removedIds.add(variable.id);
      return remove;
    });
    _revealedSecretIds.removeAll(removedIds);
  }

  _VariableLocation _findVariable(String id) {
    final globalIndex = _global.indexWhere((variable) => variable.id == id);
    if (globalIndex >= 0) return _VariableLocation(_global, globalIndex);
    for (final variables in _byEnvironment.values) {
      final index = variables.indexWhere((variable) => variable.id == id);
      if (index >= 0) return _VariableLocation(variables, index);
    }
    throw StateError('Unknown environment variable: $id');
  }

  void _ensureAuthenticationVariables(
    String environmentId,
    RequestAuthentication authentication,
  ) {
    final variables = _byEnvironment[environmentId]!;
    final environment = _profiles.firstWhere(
      (item) => item.id == environmentId,
    );
    switch (authentication.type) {
      case RequestAuthenticationType.none:
        return;
      case RequestAuthenticationType.bearer:
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.bearerToken,
          type: EnvironmentVariableType.secret,
          isProtected: true,
        );
        return;
      case RequestAuthenticationType.basic:
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.basicUsername,
          type: EnvironmentVariableType.string,
        );
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.basicPassword,
          type: EnvironmentVariableType.secret,
        );
      case RequestAuthenticationType.apiKey:
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.apiKey,
          type: EnvironmentVariableType.secret,
        );
    }
  }

  void _ensureEnvironmentVariable({
    required List<StoredEnvironmentVariable> variables,
    required EnvironmentProfile environment,
    required String key,
    required EnvironmentVariableType type,
    bool isProtected = false,
  }) {
    final index = variables.indexWhere((variable) => variable.key == key);
    if (index < 0) {
      variables.add(
        StoredEnvironmentVariable(
          'authentication-${environment.id}-$key',
          environment.name,
          key,
          '',
          type,
          isProtected: isProtected,
        ),
      );
      return;
    }
    variables[index] = variables[index].copyWith(
      type: type,
      isProtected: isProtected,
    );
  }

  bool _isHiddenInactiveAuthenticationVariable(
    StoredEnvironmentVariable variable,
    Set<String> activeKeys,
  ) =>
      EnvironmentAuthenticationPolicy.removableVariableKeys.contains(
        variable.key,
      ) &&
      !activeKeys.contains(variable.key);

  String _validateEnvironmentName(String name, {String? excludingId}) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Environment name is required.');
    }
    final duplicate = _profiles.any(
      (profile) =>
          profile.id != excludingId &&
          profile.name.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError.value(
        name,
        'name',
        'Environment name already exists.',
      );
    }
    return normalized;
  }

  String _normalizeValueForType(String value, EnvironmentVariableType type) {
    final normalized = value.trim();
    return switch (type) {
      EnvironmentVariableType.string ||
      EnvironmentVariableType.secret => normalized,
      EnvironmentVariableType.number =>
        num.tryParse(normalized) == null ? '0' : normalized,
      EnvironmentVariableType.boolean => switch (normalized.toLowerCase()) {
        'true' || '1' || 'yes' || 'on' => 'true',
        _ => 'false',
      },
    };
  }
}
