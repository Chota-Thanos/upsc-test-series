import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  ApiException(this.message, {this.code});
  @override
  String toString() => message;
}

class ApiClient extends ChangeNotifier {
  final http.Client _client = http.Client();
  String? _token;
  Map<String, dynamic>? _user;
  bool _isInitialized = false;
  Map<String, int?> _entitlements = {};
  bool _isEntitlementsLoaded = false;
  bool _isGuestMode = false;
  String? _guestToken;
  int? _pendingClaimAttemptId;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null;
  bool get isGuestMode => _isGuestMode && _token == null;
  bool get hasPendingGuestClaim => _pendingClaimAttemptId != null;
  Map<String, int?> get entitlements => _entitlements;
  bool get hasEntitlementsLoaded => _isEntitlementsLoaded;

  Future<void> setGuestMode(bool value) async {
    _isGuestMode = value;
    if (value) {
      // Make sure a guest identity exists before any guest-mode screen can
      // fire its first API call (see ensureGuestToken/_headers).
      await ensureGuestToken();
    }
    notifyListeners();
  }

  // One-shot signals set by WelcomeScreen before state change causes rebuild.
  bool _wantsDiagnosticLaunch = false;
  int? _pendingDiagnosticTestId;
  bool _wantsCustomTestLaunch = false;

  Future<void> startGuestDiagnosticFlow({int? testId}) async {
    _isGuestMode = true;
    _wantsDiagnosticLaunch = true;
    _pendingDiagnosticTestId = testId;
    await ensureGuestToken();
    notifyListeners();
  }

  Future<void> startGuestCustomTestFlow() async {
    _isGuestMode = true;
    _wantsCustomTestLaunch = true;
    await ensureGuestToken();
    notifyListeners();
  }

  bool consumeDiagnosticLaunchIntent() {
    final value = _wantsDiagnosticLaunch;
    _wantsDiagnosticLaunch = false;
    return value;
  }

  int? consumePendingDiagnosticTestId() {
    final id = _pendingDiagnosticTestId;
    _pendingDiagnosticTestId = null;
    return id;
  }

  bool consumeCustomTestLaunchIntent() {
    final value = _wantsCustomTestLaunch;
    _wantsCustomTestLaunch = false;
    return value;
  }

  /// Opaque per-device identity for a guest taking a test before they have an
  /// account. Persisted so it survives app restarts during the same attempt.
  Future<String> ensureGuestToken() async {
    if (_guestToken != null) return _guestToken!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('guest_token');
    if (existing != null) {
      _guestToken = existing;
      return existing;
    }
    final random = Random.secure();
    final token = List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await prefs.setString('guest_token', token);
    _guestToken = token;
    return token;
  }

  /// Recorded right after a guest submits a test, so it can be claimed into
  /// their account once they register/log in (see claimPendingGuestAttempt).
  Future<void> setPendingGuestClaim(int attemptId) async {
    _pendingClaimAttemptId = attemptId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pending_claim_attempt_id', attemptId);
  }

  Future<void> _clearPendingGuestClaim() async {
    _pendingClaimAttemptId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_claim_attempt_id');
    await prefs.remove('guest_token');
    _guestToken = null;
  }

  Future<void> _claimPendingGuestAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final attemptId = _pendingClaimAttemptId ?? prefs.getInt('pending_claim_attempt_id');
    final guestToken = _guestToken ?? prefs.getString('guest_token');
    if (attemptId == null || guestToken == null) return;

    try {
      await post('/api/v1/assessment/attempts/$attemptId/claim', {
        'guest_token': guestToken,
      });
    } catch (e) {
      debugPrint("Failed to claim guest test attempt: $e");
    } finally {
      await _clearPendingGuestClaim();
    }
  }


  bool hasEntitlement(String key) {
    return _entitlements.containsKey(key);
  }

  int? getEntitlementLimit(String key) {
    return _entitlements[key];
  }

  ApiClient() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('coaching_hub_token');
    final userJson = prefs.getString('coaching_hub_user');
    if (userJson != null) {
      try {
        _user = jsonDecode(userJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("Error parsing cached user: $e");
      }
    }
    final entitlementsJson = prefs.getString('coaching_hub_entitlements');
    if (entitlementsJson != null) {
      try {
        final decoded = jsonDecode(entitlementsJson) as Map<String, dynamic>;
        _entitlements = decoded.map((k, v) => MapEntry(k, v as int?));
        _isEntitlementsLoaded = true;
      } catch (e) {
        debugPrint("Error parsing cached entitlements: $e");
      }
    }
    _guestToken = prefs.getString('guest_token');
    _pendingClaimAttemptId = prefs.getInt('pending_claim_attempt_id');

    _isInitialized = true;
    notifyListeners();

    // Sync profile details if token exists
    if (_token != null) {
      await syncProfile();
      await syncEntitlements();
    }
  }

  // Base request headers
  Map<String, String> _headers([bool withToken = true]) {
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (withToken && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    } else if (_isGuestMode && _guestToken != null) {
      headers['X-Guest-Token'] = _guestToken!;
    }
    return headers;
  }

  // Handle 401 unauthorized errors
  void _handleUnauthorized() {
    logout();
  }

  // Get request
  Future<dynamic> get(String path, {bool withToken = true}) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$path");
    try {
      final response = await _client.get(url, headers: _headers(withToken));
      return _processResponse(response, path);
    } catch (e) {
      debugPrint("GET request failed for $path: $e");
      rethrow;
    }
  }

  // Post request
  Future<dynamic> post(String path, dynamic body, {bool withToken = true}) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$path");
    try {
      final response = await _client.post(
        url,
        headers: _headers(withToken),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response, path);
    } catch (e) {
      debugPrint("POST request failed for $path: $e");
      rethrow;
    }
  }

  // Put request
  Future<dynamic> put(String path, dynamic body, {bool withToken = true}) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$path");
    try {
      final response = await _client.put(
        url,
        headers: _headers(withToken),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response, path);
    } catch (e) {
      debugPrint("PUT request failed for $path: $e");
      rethrow;
    }
  }

  // Patch request
  Future<dynamic> patch(String path, dynamic body, {bool withToken = true}) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$path");
    try {
      final response = await _client.patch(
        url,
        headers: _headers(withToken),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response, path);
    } catch (e) {
      debugPrint("PATCH request failed for $path: $e");
      rethrow;
    }
  }


  // Delete request
  Future<dynamic> delete(String path, {bool withToken = true}) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$path");
    try {
      final response = await _client.delete(url, headers: _headers(withToken));
      return _processResponse(response, path);
    } catch (e) {
      debugPrint("DELETE request failed for $path: $e");
      rethrow;
    }
  }

  // Process HTTP response
  dynamic _processResponse(http.Response response, String path) {
    if (response.statusCode == 401) {
      _handleUnauthorized();
      throw Exception("Unauthorized request. Please login again.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (e) {
        return response.body;
      }
    }

    // Attempt to extract error message
    String message = "Request failed with status ${response.statusCode}";
    String? errorCode;
    try {
      final body = jsonDecode(response.body);
      if (body != null) {
        if (body['message'] is String) {
          message = body['message'];
        } else if (body['error'] == 'validation_error' && body['issues'] is List) {
          message = (body['issues'] as List).map((i) => i['message']).join(" ");
        }
        if (body['error'] is String && body['error'] != 'validation_error') {
          errorCode = body['error'];
        }
      }
    } catch (_) {}
    throw ApiException(message, code: errorCode);
  }

  // Sync user profile with database
  Future<void> syncProfile() async {
    if (_token == null) return;
    try {
      final freshUser = await get('/api/v1/auth/me');
      if (freshUser != null) {
        _user = freshUser as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('coaching_hub_user', jsonEncode(_user));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to sync fresh user profile: $e");
    }
  }

  // Sync user entitlements with database
  Future<void> syncEntitlements() async {
    if (_token == null) {
      _entitlements = {};
      _isEntitlementsLoaded = false;
      notifyListeners();
      return;
    }
    try {
      final data = await get('/api/v1/billing/me/entitlements');
      if (data is List) {
        final Map<String, int?> newEntitlements = {};
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            final key = item['entitlement_key'] as String?;
            final limit = item['limit_value'] != null ? int.tryParse(item['limit_value'].toString()) : null;
            if (key != null) {
              newEntitlements[key] = limit;
            }
          }
        }
        _entitlements = newEntitlements;
        _isEntitlementsLoaded = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('coaching_hub_entitlements', jsonEncode(_entitlements));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to sync entitlements: $e");
    }
  }

  // Authentication: Login
  Future<void> login(String email, String password) async {
    final result = await post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    }, withToken: false);

    if (result != null && result['access_token'] != null && result['user'] != null) {
      // Check if user is a student/user.
      final userRole = result['user']['role'] ?? '';
      if (userRole == 'admin' || userRole == 'mentor') {
        throw Exception("Admins and Mentors must use the web dashboard.");
      }

      _token = result['access_token'];
      _user = result['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('coaching_hub_token', _token!);
      await prefs.setString('coaching_hub_user', jsonEncode(_user));

      _isGuestMode = false;
      notifyListeners();
      await syncEntitlements();
      await _claimPendingGuestAttempt();
    } else {
      throw Exception("Login failed. Invalid response from server.");
    }
  }

  // Authentication: Login with Google
  Future<void> loginWithGoogle(String idToken) async {
    final result = await post('/api/v1/auth/google', {
      'id_token': idToken,
    }, withToken: false);

    if (result != null && result['access_token'] != null && result['user'] != null) {
      final userRole = result['user']['role'] ?? '';
      if (userRole == 'admin' || userRole == 'mentor') {
        throw Exception("Admins and Mentors must use the web dashboard.");
      }

      _token = result['access_token'];
      _user = result['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('coaching_hub_token', _token!);
      await prefs.setString('coaching_hub_user', jsonEncode(_user));

      _isGuestMode = false;
      notifyListeners();
      await syncEntitlements();
      await _claimPendingGuestAttempt();
    } else {
      throw Exception("Google login failed. Invalid response from server.");
    }
  }

  // Authentication: Register
  Future<void> register(String email, String username, String password) async {
    final result = await post('/api/v1/auth/register', {
      'email': email,
      'username': username,
      'password': password,
    }, withToken: false);

    if (result != null && result['access_token'] != null && result['user'] != null) {
      _token = result['access_token'];
      _user = result['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('coaching_hub_token', _token!);
      await prefs.setString('coaching_hub_user', jsonEncode(_user));

      _isGuestMode = false;
      notifyListeners();
      await syncEntitlements();
      await _claimPendingGuestAttempt();
    } else {
      throw Exception("Registration failed. Invalid response from server.");
    }
  }

  // Authentication: Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    _entitlements = {};
    _isEntitlementsLoaded = false;
    _isGuestMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('coaching_hub_token');
    await prefs.remove('coaching_hub_user');
    await prefs.remove('coaching_hub_entitlements');
    notifyListeners();
  }
}
