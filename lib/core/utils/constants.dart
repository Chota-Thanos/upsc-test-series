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

  /// The **Web** OAuth 2.0 client ID from Google Cloud, passed to the native
  /// Google Sign-In SDK as `serverClientId`. This is what makes the SDK return
  /// an ID token whose audience matches the backend's `GOOGLE_CLIENT_ID_WEB`
  /// (the backend validates the token audience). Without it, Android often
  /// returns a null ID token or one the server rejects.
  ///
  /// Defaults to the project's Web OAuth client ID (client IDs are public, not
  /// secret). Override at build/run time if needed with:
  ///   `--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com`
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '783135018669-i7qlooqlbaf7rjth2kb66c834eivl4s5.apps.googleusercontent.com',
  );
}
