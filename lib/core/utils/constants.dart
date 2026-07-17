import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _prodBaseUrl = "https://waytoias.com";

  // Release/profile builds always hit production. In debug builds only, pass
  // `--dart-define=API_BASE_URL=http://<host>:4000` to `flutter run` to point
  // at a local dev API instead — no code change needed, and this can never
  // accidentally ship in a real build.
  static const String baseUrl = kDebugMode
      ? String.fromEnvironment('API_BASE_URL', defaultValue: _prodBaseUrl)
      : _prodBaseUrl;
  static const String webAppUrl = "https://waytoias.com";
}
