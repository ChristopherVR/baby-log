import 'package:flutter/services.dart';

/// Which Android build this is. Tests can override [play].
abstract final class Distribution {
  /// The Google Play build: no APK updater, no alarm-style reminders.
  static bool play = appFlavor == 'play';
}
