import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Configured default API base URL depending on the run platform.
  // For android emulators, 10.0.2.2 is mapped to 127.0.0.1 on the host machine.
  // Otherwise we use localhost (127.0.0.1) for web / iOS / desktop.
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:4000";
    }
    try {
      if (Platform.isAndroid) {
        return "http://10.0.2.2:4000";
      }
    } catch (_) {
      // Fail-safe if Platform is accessed on unsupported platforms.
    }
    return "http://127.0.0.1:4000";
  }

  static String get webAppUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    try {
      if (Platform.isAndroid) {
        return "http://10.0.2.2:3000";
      }
    } catch (_) {
      // Fail-safe if Platform is accessed on unsupported platforms.
    }
    return "http://127.0.0.1:3000";
  }
}
