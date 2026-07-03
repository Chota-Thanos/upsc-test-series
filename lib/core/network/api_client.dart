import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiClient extends ChangeNotifier {
  final http.Client _client = http.Client();
  String? _token;
  Map<String, dynamic>? _user;
  bool _isInitialized = false;
  Map<String, int?> _entitlements = {};
  bool _isEntitlementsLoaded = false;
  bool _isGuestMode = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null;
  bool get isGuestMode => _isGuestMode && _token == null;
  Map<String, int?> get entitlements => _entitlements;
  bool get hasEntitlementsLoaded => _isEntitlementsLoaded;

  void setGuestMode(bool value) {
    _isGuestMode = value;
    notifyListeners();
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
    try {
      final body = jsonDecode(response.body);
      if (body != null) {
        if (body['message'] is String) {
          message = body['message'];
        } else if (body['error'] == 'validation_error' && body['issues'] is List) {
          message = (body['issues'] as List).map((i) => i['message']).join(" ");
        }
      }
    } catch (_) {}
    throw Exception(message);
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
