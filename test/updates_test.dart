import 'package:baby_app/src/updates.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> release({String version = '1.4.10'}) => {
  'tag_name': 'v$version',
  'draft': false,
  'prerelease': false,
  'assets': [
    {
      'name': 'BabyLog-$version.apk',
      'size': 1234,
      'browser_download_url':
          '$releaseRepository/releases/download/v$version/BabyLog-$version.apk',
    },
  ],
};

void main() {
  test(
    'compares numeric versions across patch, minor and major boundaries',
    () {
      expect(AppRelease.isNewer('1.4.10', '1.4.9'), isTrue);
      expect(AppRelease.isNewer('1.10.0', '1.9.99'), isTrue);
      expect(AppRelease.isNewer('2.0.0', '1.99.99'), isTrue);
      expect(AppRelease.isNewer('1.4.0', '1.4.0'), isFalse);
      expect(AppRelease.isNewer('1.3.99', '1.4.0'), isFalse);
      expect(AppRelease.isNewer('1.4.1-beta', '1.4.0'), isFalse);
      expect(AppRelease.isNewer('1.4.1', ''), isFalse);
    },
  );

  test('selects the exact workflow APK and ignores unrelated assets', () {
    final json = release();
    (json['assets'] as List).insert(0, {'name': 'source.zip'});
    final update = AppRelease.parse(json, '1.4.9');
    expect(update?.version, '1.4.10');
    expect(update?.size, 1234);
    expect(update?.url.host, 'github.com');
  });

  test('accepts downloads after the repository is renamed', () {
    final json = release();
    json['assets'][0]['browser_download_url'] = 'https://github.com/ChristopherVR/nestling/releases/download/v1.4.10/BabyLog-1.4.10.apk';
    expect(AppRelease.parse(json, '1.4.9')?.version, '1.4.10');
  });

  test('rejects old, equal, draft and prerelease releases', () {
    expect(AppRelease.parse(release(), '1.4.10'), isNull);
    expect(AppRelease.parse(release(), '2.0.0'), isNull);
    expect(AppRelease.parse(release()..['draft'] = true, '1.0.0'), isNull);
    expect(AppRelease.parse(release()..['prerelease'] = true, '1.0.0'), isNull);
    expect(
      AppRelease.parse(release()..['tag_name'] = 'latest', '1.0.0'),
      isNull,
    );
    expect(AppRelease.parse(release()..['assets'] = [], '1.0.0'), isNull);
  });

  test('rejects unsafe URLs, mismatched assets and invalid sizes', () {
    for (final url in [
      'http://github.com/ChristopherVR/baby-log/releases/download/v1.4.10/BabyLog-1.4.10.apk',
      'https://evil.example/BabyLog-1.4.10.apk',
      'https://github.com/other/repo/releases/download/v1.4.10/BabyLog-1.4.10.apk',
      '$releaseRepository/releases/download/v1.4.9/BabyLog-1.4.10.apk',
    ]) {
      final json = release();
      json['assets'][0]['browser_download_url'] = url;
      expect(AppRelease.parse(json, '1.4.9'), isNull, reason: url);
    }
    for (final size in [0, -1, 300 * 1024 * 1024, '1234']) {
      final json = release();
      json['assets'][0]['size'] = size;
      expect(AppRelease.parse(json, '1.4.9'), isNull);
    }
    final json = release();
    json['assets'][0]['name'] = 'BabyLog-1.4.9.apk';
    expect(AppRelease.parse(json, '1.4.9'), isNull);
  });
}
