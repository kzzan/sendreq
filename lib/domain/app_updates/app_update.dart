/// Latest stable release published by the configured update source.
class AppRelease {
  const AppRelease({required this.version, required this.releasePage});

  final String version;
  final Uri releasePage;
}

/// Fetches the latest stable application release on every invocation.
abstract interface class AppReleaseRepository {
  Future<AppRelease> fetchLatest();
}

/// Reads the version of the currently running application package.
abstract interface class InstalledAppVersionProvider {
  Future<String> readVersion();
}

/// Opens an external release page using the operating system.
abstract interface class ExternalReleaseLauncher {
  Future<void> open(Uri uri);
}

/// Comparable semantic version used for update decisions.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.major, this.minor, this.patch, this.preRelease);

  factory AppVersion.parse(String source) {
    final normalized = source.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final withoutBuild = normalized.split('+').first;
    final pieces = withoutBuild.split('-');
    final core = pieces.first.split('.');
    if (core.isEmpty ||
        core.length > 3 ||
        core.any((part) => int.tryParse(part) == null)) {
      throw FormatException('Invalid semantic version: $source');
    }
    final numbers = core.map(int.parse).toList(growable: true);
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return AppVersion._(
      numbers[0],
      numbers[1],
      numbers[2],
      pieces.length > 1 ? pieces.skip(1).join('-').split('.') : const [],
    );
  }

  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  @override
  int compareTo(AppVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final compared = pair.$1.compareTo(pair.$2);
      if (compared != 0) return compared;
    }
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;
    for (
      var index = 0;
      index < preRelease.length || index < other.preRelease.length;
      index++
    ) {
      if (index >= preRelease.length) return -1;
      if (index >= other.preRelease.length) return 1;
      final leftNumber = int.tryParse(preRelease[index]);
      final rightNumber = int.tryParse(other.preRelease[index]);
      final compared = switch ((leftNumber, rightNumber)) {
        (final int left, final int right) => left.compareTo(right),
        (final int _, null) => -1,
        (null, final int _) => 1,
        _ => preRelease[index].compareTo(other.preRelease[index]),
      };
      if (compared != 0) return compared;
    }
    return 0;
  }
}
