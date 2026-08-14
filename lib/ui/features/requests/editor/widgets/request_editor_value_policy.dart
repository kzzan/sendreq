/// Whether a field delegates its value to the active Environment.
bool isEnvironmentReference(String value) => RegExp(
  r'^\s*(?:Bearer\s+)?\{\{[^{}]+\}\}\s*$',
  caseSensitive: false,
).hasMatch(value);
