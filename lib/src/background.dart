import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android only: a foreground service (see SyncService.kt) keeps the app's
/// Dart engine, and with it the sync server, alive when the app is closed.
class BackgroundSync {
  static const _channel = MethodChannel('babylog/background');

  static bool get supported => Platform.isAndroid;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('Background call $method failed: $e');
      return null;
    }
  }

  static Future<void> start() => _call('start');

  static Future<void> stop() => _call('stop');

  /// Whether Android lets the app keep its network connection while the phone sleeps.
  static Future<bool> isBatteryExempt() async => await _call<bool>('isBatteryExempt') ?? true;

  static Future<void> requestBatteryExempt() => _call('requestBatteryExempt');

  /// After an alarm: stop showing the app over the lock screen.
  static Future<void> leaveLockScreen() => _call('leaveLockScreen');

  static int _awake = 0;

  /// Runs [work] with the CPU kept awake, so a sync can finish while the
  /// screen is off. The wake lock is released as soon as nothing needs it
  /// (with a 30 second safety timeout on the Android side).
  static Future<T> whileAwake<T>(Future<T> Function() work) async {
    if (_awake++ == 0) await _call('keepAwake', 30000);
    try {
      return await work();
    } finally {
      if (--_awake == 0) await _call('releaseAwake');
    }
  }
}

/// The name the device itself goes by, used as the default device name.
class DeviceIdentity {
  /// The phone's name from its settings (e.g. "Chris's Galaxy S23"), or its
  /// maker and model; the computer name on desktop. Null if unknown.
  static Future<String?> name() async {
    if (BackgroundSync.supported) {
      final name = await BackgroundSync._call<String>('deviceName');
      return name == null || name.trim().isEmpty ? null : name.trim();
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Platform.localHostname;
    }
    return null;
  }
}
