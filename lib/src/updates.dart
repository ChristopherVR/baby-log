import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'distribution.dart';

const releaseRepository = 'https://github.com/ChristopherVR/baby-log';

/// The repository is being renamed to "nestling"; GitHub then hands out
/// download links under the new name, so both are trusted.
const _releasePaths = ['/ChristopherVR/baby-log/', '/ChristopherVR/nestling/'];

/// Only stable, versioned APKs published by our release workflow are eligible.
class AppRelease {
  const AppRelease(this.version, this.url, this.size);
  final String version;
  final Uri url;
  final int size;

  static AppRelease? parse(Map<String, dynamic> json, String installed) {
    if (json['draft'] != false || json['prerelease'] != false) return null;
    final tag = json['tag_name'];
    if (tag is! String || !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag)) {
      return null;
    }
    final version = tag.substring(1);
    if (!isNewer(version, installed)) return null;
    for (final asset in json['assets'] as List? ?? []) {
      if (asset['name'] != 'BabyLog-$version.apk') continue;
      final url = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
      final size = asset['size'];
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'github.com' ||
          url.userInfo.isNotEmpty ||
          !_releasePaths.any(
            (repo) =>
                url.path ==
                '${repo}releases/download/$tag/BabyLog-$version.apk',
          ) ||
          size is! int ||
          size <= 0 ||
          size > 250 * 1024 * 1024) {
        continue;
      }
      return AppRelease(version, url, size);
    }
    return null;
  }

  static bool isNewer(String candidate, String installed) {
    final pattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!pattern.hasMatch(candidate) || !pattern.hasMatch(installed)) {
      return false;
    }
    final a = candidate.split('.').map(int.parse).toList();
    final b = installed.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}

class AppUpdates extends ChangeNotifier {
  static final instance = AppUpdates();
  static const _channel = MethodChannel('babylog/updates');
  bool get usesPlayStore => Distribution.play;
  AppRelease? available;
  bool checking = false;
  bool downloading = false;
  double progress = 0;
  String? message;
  DateTime? _lastCheck;
  File? _downloaded;
  String? _downloadedVersion;

  Future<void> check({bool manual = false}) async {
    if (usesPlayStore || !Platform.isAndroid || checking || downloading) return;
    if (!manual &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(hours: 6)) {
      return;
    }
    _lastCheck = DateTime.now();
    checking = true;
    message = null;
    notifyListeners();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final installed = await PackageInfo.fromPlatform();
      final request = await client
          .getUrl(
            Uri.parse(
              'https://api.github.com/repos/ChristopherVR/baby-log/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 20));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'BabyLog/${installed.version}');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 404) {
        available = null;
        message = 'No releases available yet.';
      } else {
        if (response.statusCode != 200) {
          throw const HttpException('Release check failed');
        }
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 20));
        available = AppRelease.parse(
          jsonDecode(body) as Map<String, dynamic>,
          installed.version,
        );
        message = available == null ? 'No compatible update available.' : null;
      }
    } catch (_) {
      message = 'Could not check for updates. Try again when you are online.';
    } finally {
      client.close(force: true);
      checking = false;
      notifyListeners();
    }
  }

  /// Opens Android's installer or its per-app installation permission page.
  Future<void> install() async {
    final release = available;
    if (usesPlayStore ||
        release == null ||
        downloading ||
        !Platform.isAndroid) {
      return;
    }
    downloading = true;
    message = null;
    notifyListeners();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    File? partial;
    try {
      if (_downloadedVersion != release.version ||
          !(_downloaded?.existsSync() ?? false)) {
        final directory = Directory(
          '${(await getTemporaryDirectory()).path}/updates',
        );
        await directory.create(recursive: true);
        final file = File('${directory.path}/update.apk');
        partial = File('${file.path}.part');
        final request = await client
            .getUrl(release.url)
            .timeout(const Duration(seconds: 30));
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200) {
          throw const HttpException('Download failed');
        }
        var received = 0;
        final sink = partial.openWrite();
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            received += chunk.length;
            if (received > release.size) {
              throw const FormatException('Invalid APK size');
            }
            sink.add(chunk);
            await sink.flush();
            progress = received / release.size;
            notifyListeners();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (received != release.size) {
          throw const FormatException('Incomplete APK');
        }
        _downloaded = await partial.rename(file.path);
        _downloadedVersion = release.version;
      }
      final opened = await _channel.invokeMethod<bool>(
        'install',
        _downloaded!.path,
      );
      message = opened == true
          ? 'Confirm the update in Android. If cancelled, tap Update to try again.'
          : 'Allow updates from Nestling, then return and tap Update again.';
    } catch (_) {
      _downloadedVersion = null;
      message = 'Could not install the update. Please try again.';
    } finally {
      client.close(force: true);
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } on FileSystemException {
        // The next attempt overwrites this partial file.
      }
      downloading = false;
      progress = 0;
      notifyListeners();
    }
  }

  Future<void> openStore() async {
    if (!usesPlayStore || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openStore');
    } catch (_) {
      message =
          'Could not open Google Play. Open the Play Store to update Nestling.';
      notifyListeners();
    }
  }
}
