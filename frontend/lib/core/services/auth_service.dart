import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:litreview_app/core/config/app_config.dart';
import 'package:litreview_app/core/models/user_model.dart';
import 'package:litreview_app/core/services/api_service.dart';

/// Authentication service for handling user login/registration and token management
class AuthService extends ChangeNotifier {
  /// API base URL for authentication endpoints
  static String get _baseUrl => '${AppConfig.current.apiBaseUrl}/auth';
  
  /// Current authentication token
  String? _token;
  
  /// Current user ID
  int? _userId;
  
  /// Current username
  String? _username;
  
  /// Current user email
  String? _email;

  /// Current user model when authenticated
  UserModel? _currentUser;
  
  /// Whether the current session is the shared demo/guest account
  bool _isGuest = false;
  
  /// Whether the authentication status is being checked
  bool _isLoading = false;
  
  /// Error message if any
  String? _error;
  
  /// Token expiration timer
  Timer? _tokenExpiryTimer;
  
  /// Token expiration duration - set to 30 days for long session
  final Duration _tokenExpiration = const Duration(days: 30);
  
  /// Add a minimum interval between token validations
  static const Duration _minimumValidationInterval = Duration(minutes: 5);
  DateTime? _lastValidationTime;
  
  /// Whether user is authenticated
  bool get isAuthenticated => _token != null;

  /// Whether the current session uses the shared demo account
  bool get isGuest => _isGuest;
  
  /// Get the current token
  String? get token => _token;
  
  /// Get the current user ID
  int? get userId => _userId;
  
  /// Get the current username
  String? get username => _username;
  
  /// Get the current user email
  String? get email => _email;

  /// Get the current user model
  UserModel? get currentUser => _currentUser;
  
  /// Whether the authentication status is being checked
  bool get isLoading => _isLoading;
  
  /// Get any error message
  String? get error => _error;
  
  /// Singleton instance
  static final AuthService _instance = AuthService._internal();
  
  /// Factory constructor to return the singleton instance
  factory AuthService() {
    return _instance;
  }
  
  /// Internal constructor
  AuthService._internal();
  
  /// Try to login automatically using stored token
  Future<bool> tryAutoLogin() async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final authData = prefs.getString('authData');
      
      if (authData == null) {
        _setLoading(false);
        return false;
      }
      
      final data = jsonDecode(authData);
      final token = data['token'];
      final expiryTimeString = data['expiryTime'];
      final expiryTime = DateTime.parse(expiryTimeString);
      
      if (expiryTime.isBefore(DateTime.now())) {
        // Token has expired, try to validate it with the server
        final isValid = await _validateToken(token);
        
        if (!isValid) {
          await logout();
          _setLoading(false);
          return false;
        }
      }
      
      _token = token;
      _userId = data['userId'];
      _username = data['username'];
      _email = data['email'];
      _isGuest = data['isGuest'] == true;
      
      
      // Set token in API service
      ApiService().setAuthToken(_token!);
      
      // Create user model instance
      if (data.containsKey('userData')) {
        _currentUser = UserModel.fromJson(jsonDecode(data['userData']));
      } else {
        // Create minimal user model with available info
        _currentUser = UserModel(
          id: _userId!,
          username: _username!,
          email: _email!,
        );
      }
      
      // Set new expiration timer
      _setExpirationTimer();
      
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Auto login error: $e');
      _setLoading(false);
      return false;
    }
  }
  
  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        _error = errorData['error'] ?? 'Login failed';
        _setLoading(false);
        return false;
      }

      final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
      await _applyAuthSession(responseData, guest: false);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Login failed: $e';
      debugPrint(_error);
      _setLoading(false);
      return false;
    }
  }

  /// Start a shared demo session (open-source local default).
  Future<bool> loginAsGuest() async {
    if (!AppConfig.autoGuestLogin) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/demo/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        _error = 'Guest access is unavailable on this server.';
        _setLoading(false);
        return false;
      }

      final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
      await _applyAuthSession(responseData, guest: true);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Guest login failed: $e';
      debugPrint(_error);
      _setLoading(false);
      return false;
    }
  }

  /// Restore saved session, then fall back to guest access when enabled.
  Future<void> bootstrapAuth() async {
    if (!isAuthenticated) {
      await tryAutoLogin();
    }
    if (!isAuthenticated && AppConfig.autoGuestLogin) {
      await loginAsGuest();
    }
  }

  Future<void> _applyAuthSession(
    Map<String, dynamic> responseData, {
    required bool guest,
  }) async {
    _token = responseData['token'] as String?;
    _userId = responseData['user_id'] as int? ?? responseData['id'] as int?;
    _username = responseData['username'] as String?;
    _email = responseData['email'] as String?;
    _isGuest = guest;

    _currentUser = UserModel.fromAuthJson(responseData);
    await _saveAuthData();
    ApiService().setAuthToken(_token!);
    _setExpirationTimer();
    notifyListeners();
  }
  
  /// Register a new user
  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    _error = null;
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode != 201) {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        _error = errorData['error'] ?? 'Registration failed';
        _setLoading(false);
        return false;
      }
      
      // Parse response data
      final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
      _token = responseData['token'];
      final userData = responseData['user'];
      _userId = userData['id'];
      _username = userData['username'];
      _email = userData['email'];
      _isGuest = false;
      _currentUser = UserModel.fromAuthJson(userData);
      await _saveAuthData();
      
      // Set token in API service
      ApiService().setAuthToken(_token!);
      
      // Set expiration timer
      _setExpirationTimer();
      
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Registration failed: $e';
      debugPrint(_error);
      _setLoading(false);
      return false;
    }
  }
  
  /// Logout the current user
  Future<void> logout({bool revokeServerSession = true}) async {
    try {
      if (_token != null && revokeServerSession && !_isGuest) {
        await http.post(
          Uri.parse('$_baseUrl/logout/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $_token',
          },
        ).catchError((e) {
          debugPrint('Logout request error: $e');
        });
      }
    } finally {
      _token = null;
      _userId = null;
      _username = null;
      _email = null;
      _currentUser = null;
      _isGuest = false;
      
      // Cancel expiration timer
      _tokenExpiryTimer?.cancel();
      _tokenExpiryTimer = null;
      
      // Clear saved data
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('authData');
      
      notifyListeners();
    }
  }
  
  /// Validate a token with the server
  Future<bool> _validateToken(String token) async {
    // Add rate limiting to token validation
    if (_lastValidationTime != null) {
      final timeSinceLastValidation = DateTime.now().difference(_lastValidationTime!);
      if (timeSinceLastValidation < _minimumValidationInterval) {
        return true; // Skip validation if too recent
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/validate-token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      
      _lastValidationTime = DateTime.now();
      
      if (response.statusCode != 200) {
        return false;
      }
      
      final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
      return responseData['valid'] == true;
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }
  
  /// Save authentication data to persistent storage
  Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTime = DateTime.now().add(_tokenExpiration);
    
    final authData = jsonEncode({
      'token': _token,
      'userId': _userId,
      'username': _username,
      'email': _email,
      'isGuest': _isGuest,
      'expiryTime': expiryTime.toIso8601String(),
      'userData': _currentUser?.toJson(),
    });
    
    await prefs.setString('authData', authData);
  }
  
  /// Set the expiration timer for the token
  void _setExpirationTimer() {
    _tokenExpiryTimer?.cancel();
    _tokenExpiryTimer = Timer(_tokenExpiration, () {
      // Auto refresh token instead of logging out
      _refreshToken();
    });
  }
  
  /// Refresh the authentication token
  Future<bool> _refreshToken() async {
    try {
      if (_token == null) return false;
      
      // Check if we need to validate based on time interval
      if (_lastValidationTime != null) {
        final timeSinceLastValidation = DateTime.now().difference(_lastValidationTime!);
        if (timeSinceLastValidation < _minimumValidationInterval) {
          return true; // Skip validation if too recent
        }
      }

      final isValid = await _validateToken(_token!);
      
      if (isValid) {
        _setExpirationTimer();
        return true;
      } else {
        await logout();
        return false;
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
  
  /// Set loading state and notify listeners
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Get authorization headers for API requests
  Map<String, String> getAuthHeaders() {
    if (_token == null) {
      return {'Content-Type': 'application/json'};
    } else {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      };
    }
  }
  
  /// Fetch the current user's full profile from the server
  Future<bool> fetchUserProfile() async {
    if (_token == null || _userId == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile/'),
        headers: getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(response.bodyBytes));
        _currentUser = UserModel.fromJson(userData);
        await _saveAuthData();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return false;
    }
  }
  
  @override
  void dispose() {
    _tokenExpiryTimer?.cancel();
    super.dispose();
  }
} 