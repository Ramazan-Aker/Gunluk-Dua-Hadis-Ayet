import 'dart:convert';
import 'package:daily_dua_hadith/models/app_update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

String policy(
        {bool enabled = true,
        bool published = true,
        String latest = '2.0.3',
        String minimum = '2.0.2'}) =>
    jsonEncode({
      'enabled': enabled,
      'published': published,
      'latest_version': latest,
      'minimum_version': minimum,
    });

void main() {
  test('Numeric versions compare correctly and ignore build numbers', () {
    expect(compareAppVersions('2.10.0', '2.9.9'), greaterThan(0));
    expect(compareAppVersions('2.0.2+34', '2.0.2+35'), 0);
    expect(compareAppVersions('2.0.2', '3.0.0'), lessThan(0));
    expect(compareAppVersions('2.beta', '2.0.0'), isNull);
    expect(compareAppVersions('${'9' * 100}.0.0', '2.0.0'), isNull);
  });

  test('Minimum supported version gets an optional update', () {
    final result = evaluateAppUpdate(policy(), '2.0.2')!;
    expect(result.latestVersion, '2.0.3');
    expect(result.required, isFalse);
  });

  test('Older versions require an update', () {
    expect(evaluateAppUpdate(policy(), '2.0.1')!.required, isTrue);
    expect(
        evaluateAppUpdate(policy(minimum: '2.0.3'), '2.0.2')!.required, isTrue);
  });

  test('Current and newer versions are allowed', () {
    expect(evaluateAppUpdate(policy(), '2.0.3'), isNull);
    expect(evaluateAppUpdate(policy(), '2.1.0'), isNull);
  });

  test('Disabled, unpublished or malformed policies never block', () {
    for (final raw in [
      policy(enabled: false),
      policy(published: false),
      policy(minimum: '3.0.0'),
      policy(latest: 'invalid'),
      '{}',
      '[]',
      'null',
      'bad JSON',
      '{"enabled":true,"published":true,"latest_version":3}',
    ]) {
      expect(evaluateAppUpdate(raw, '2.0.1'), isNull, reason: raw);
    }
    expect(evaluateAppUpdate(policy(), 'unknown'), isNull);
  });
}
