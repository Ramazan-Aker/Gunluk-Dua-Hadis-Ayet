import 'dart:convert';

class AppUpdateDecision {
  const AppUpdateDecision(
      {required this.latestVersion, required this.required});
  final String latestVersion;
  final bool required;
}

/// Compare numeric versions, not strings (2.10.0 is newer than 2.9.0).
int? compareAppVersions(String first, String second) {
  List<int>? parse(String value) {
    final match =
        RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(value.trim());
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 3; i++) int.tryParse(match.group(i)!)];
    if (parts.any((part) => part == null)) return null;
    return parts.cast<int>();
  }

  final a = parse(first);
  final b = parse(second);
  if (a == null || b == null) return null;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

AppUpdateDecision? evaluateAppUpdate(String raw, String installedVersion) {
  try {
    final policy = jsonDecode(raw);
    if (policy is! Map ||
        policy['enabled'] != true ||
        policy['published'] != true) {
      return null;
    }
    final latest = policy['latest_version'];
    final minimum = policy['minimum_version'];
    if (latest is! String || minimum is! String) return null;
    final range = compareAppVersions(minimum, latest);
    final againstLatest = compareAppVersions(installedVersion, latest);
    final againstMinimum = compareAppVersions(installedVersion, minimum);
    // Invalid policy or an equal/newer installation must never block the app.
    if (range == null ||
        range > 0 ||
        againstLatest == null ||
        againstMinimum == null ||
        againstLatest >= 0) {
      return null;
    }
    return AppUpdateDecision(
        latestVersion: latest, required: againstMinimum < 0);
  } catch (_) {
    return null;
  }
}
