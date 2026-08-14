import 'package:sendreq/domain/environments/environment_models.dart';

/// Resolves a template from an already-scoped variable projection.
class EnvironmentTemplateResolver {
  const EnvironmentTemplateResolver();

  TemplateResolutionResult resolve(
    String template,
    Map<String, String> values,
  ) {
    final missing = <String>[];
    final resolved = template.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (
      match,
    ) {
      final key = match.group(1)!;
      final value = values[key];
      if (value == null || value.trim().isEmpty) {
        missing.add(key);
        return match.group(0)!;
      }
      return value;
    });
    return TemplateResolutionResult(
      status: missing.isEmpty
          ? TemplateResolutionStatus.success
          : TemplateResolutionStatus.missingVariable,
      executionValue: resolved,
      displayValue: template,
      missingKeys: missing,
    );
  }
}
