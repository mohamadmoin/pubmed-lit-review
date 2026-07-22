import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// HTTP methods supported by the API service
enum HttpMethod { get, post, put, delete, patch }

/// Configuration for API requests
class RequestConfig {
  /// The endpoint to call (without the base URL)
  final String endpoint;
  
  /// The HTTP method to use
  final HttpMethod method;
  
  /// Optional request body for POST, PUT, and PATCH requests
  final Map<String, dynamic>? body;
  
  /// Optional query parameters for the URL
  final Map<String, String>? queryParams;
  
  /// Optional custom headers for the request
  final Map<String, String>? headers;

  /// Create a new request configuration
  RequestConfig({
    required this.endpoint,
    this.method = HttpMethod.get,
    this.body,
    this.queryParams,
    this.headers,
  });
}

/// Exception thrown when API requests fail
class ApiException implements Exception {
  /// HTTP status code of the error
  final int statusCode;
  
  /// Error message
  final String message;
  
  /// Optional additional error data
  final Map<String, dynamic>? data;
  
  /// Original exception if any
  final Object? originalException;

  /// Create a new API exception
  ApiException({
    required this.statusCode,
    required this.message,
    this.data,
    this.originalException,
  });
  
  @override
  String toString() {
    final detail = data != null && data!.containsKey('detail') 
        ? ' - ${data!['detail']}' 
        : '';
    return 'ApiException: $message (Status code: $statusCode)$detail';
  }
}

/// Service to communicate with the backend API
class ApiService {
  /// HTTP client
  final http.Client _client;
  
  /// Base URL for all API requests
  final String _baseUrl;
  
  /// Optional auth token for authenticated requests
  String? _authToken;
  
  /// Whether to log API requests and responses
  final bool _enableLogging;
  
  /// Request timeout duration
  final Duration _timeout;

  /// Singleton instance
  static final ApiService _instance = ApiService._internal();
  
  /// Factory constructor that returns the singleton instance
  factory ApiService({
    http.Client? client,
    String? baseUrl,
    bool? enableLogging,
    int? timeoutSeconds,
  }) {
    return _instance;
  }
  
  /// Initialize the API service
  ApiService._internal({
    http.Client? client,
    String? baseUrl,
    bool? enableLogging,
    int? timeoutSeconds,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.current.apiBaseUrl,
       _enableLogging = enableLogging ?? AppConfig.current.enableLogging,
       _timeout = Duration(seconds: timeoutSeconds ?? AppConfig.current.connectionTimeoutSeconds);
  
  /// Set the authentication token for future requests
  void setAuthToken(String token) {
    _authToken = token;
    if (_enableLogging) {
      debugPrint('Auth token set');
    }
  }
  
  /// Clear the authentication token
  void clearAuthToken() {
    _authToken = null;
    if (_enableLogging) {
      debugPrint('Auth token cleared');
    }
  }
  
  /// Get request headers including authentication if available
  Map<String, String> _getHeaders({Map<String, String>? additionalHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Token $_authToken';
    }
    
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    return headers;
  }
  
  /// Send a request to the API
  Future<Map<String, dynamic>> sendRequest(RequestConfig config) async {
    final url = Uri.parse('$_baseUrl${config.endpoint}')
        .replace(queryParameters: config.queryParams);
    
    if (_enableLogging) {
      debugPrint('API Request: ${config.method} $url');
      if (config.body != null) {
        debugPrint('Request Body: ${jsonEncode(config.body)}');
      }
    }
    
    final headers = _getHeaders(additionalHeaders: config.headers);
    
    try {
      final http.Response response = await _executeRequest(
        config.method,
        url,
        headers,
        config.body,
      );
      
      return _handleResponse(response);
    } on SocketException catch (e) {
      if (_enableLogging) {
        debugPrint('Network Error: ${e.toString()}');
      }
      throw ApiException(
        statusCode: 0,
        message: 'Network error - Please check your internet connection',
        originalException: e,
      );
    } on TimeoutException catch (e) {
      if (_enableLogging) {
        debugPrint('Request Timeout: ${e.toString()}');
      }
      throw ApiException(
        statusCode: 0,
        message: 'Request timed out - Server may be unavailable',
        originalException: e,
      );
    } catch (e) {
      if (_enableLogging) {
        debugPrint('Unexpected Error: ${e.toString()}');
      }
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        statusCode: 0,
        message: 'Unexpected error occurred',
        originalException: e,
      );
    }
  }
  
  /// Execute the HTTP request based on the HTTP method
  Future<http.Response> _executeRequest(
    HttpMethod method,
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) async {
    switch (method) {
      case HttpMethod.get:
        return await _client.get(url, headers: headers)
            .timeout(_timeout);
      case HttpMethod.post:
        return await _client.post(
          url, 
          headers: headers, 
          body: body != null ? jsonEncode(body) : null,
        ).timeout(_timeout);
      case HttpMethod.put:
        return await _client.put(
          url, 
          headers: headers, 
          body: body != null ? jsonEncode(body) : null,
        ).timeout(_timeout);
      case HttpMethod.delete:
        return await _client.delete(url, headers: headers)
            .timeout(_timeout);
      case HttpMethod.patch:
        return await _client.patch(
          url, 
          headers: headers, 
          body: body != null ? jsonEncode(body) : null,
        ).timeout(_timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }
  
  /// Handle the API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (_enableLogging) {
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
    }
    
    // Handle successful responses (2xx status codes)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      
      try {
        final Map<String, dynamic> responseData = 
            jsonDecode(utf8.decode(response.bodyBytes));
        return responseData;
      } catch (e) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to parse response body',
          originalException: e,
        );
      }
    }
    
    // Handle error responses
    Map<String, dynamic> errorData = {'detail': 'Unknown error'};
    if (response.body.isNotEmpty) {
      try {
        errorData = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        errorData = {'detail': response.body};
      }
    }
    
    String errorMessage;
    switch (response.statusCode) {
      case 400:
        errorMessage = 'Bad request';
        break;
      case 401:
        errorMessage = 'Unauthorized';
        break;
      case 403:
        errorMessage = 'Forbidden';
        break;
      case 404:
        errorMessage = 'Not found';
        break;
      case 500:
        errorMessage = 'Internal server error';
        break;
      default:
        errorMessage = 'API error';
    }
    
    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      data: errorData,
    );
  }
  
  /// GET request for the AI provider
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint')
        .replace(queryParameters: queryParameters?.map((key, value) => 
            MapEntry(key, value?.toString() ?? "")));
    
    try {
      final response = await _client.get(
        url,
        headers: _getHeaders(additionalHeaders: headers),
      ).timeout(_timeout);
      
      if (_enableLogging) {
        debugPrint('GET Request: $url');
        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }
      
      return response;
    } catch (e) {
      if (_enableLogging) {
        debugPrint('GET request failed: $e');
      }
      rethrow;
    }
  }
  
  /// POST request for the AI provider
  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    
    try {
      if (_enableLogging) {
        debugPrint('POST Request: $url');
        if (body != null) {
          debugPrint('Request Body: $body');
        }
      }
      
      final response = await _client.post(
        url,
        headers: _getHeaders(additionalHeaders: headers),
        body: body,
        encoding: encoding,
      ).timeout(_timeout);
      
      if (_enableLogging) {
        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }
      
      return response;
    } catch (e) {
      if (_enableLogging) {
        debugPrint('POST request failed: $e');
      }
      rethrow;
    }
  }
  
  /// PUT request for the AI provider
  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    
    try {
      if (_enableLogging) {
        debugPrint('PUT Request: $url');
        if (body != null) {
          debugPrint('Request Body: $body');
        }
      }
      
      final response = await _client.put(
        url,
        headers: _getHeaders(additionalHeaders: headers),
        body: body,
        encoding: encoding,
      ).timeout(_timeout);
      
      if (_enableLogging) {
        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }
      
      return response;
    } catch (e) {
      if (_enableLogging) {
        debugPrint('PUT request failed: $e');
      }
      rethrow;
    }
  }
  
  /// Performs a PATCH request to the API
  Future<http.Response> patch(String endpoint, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final url = Uri.parse('${AppConfig.current.apiBaseUrl}$endpoint');
    final requestHeaders = await _prepareHeaders(headers);
    
    try {
      final response = await _client.patch(
        url,
        headers: requestHeaders,
        body: body,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to make PATCH request: $e');
    }
  }
  
  /// Get headers including authentication information
  Future<Map<String, String>> getHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    // Use the real authentication token if available
    if (_authToken != null) {
      headers['Authorization'] = 'Token $_authToken';
    }
    
    return headers;
  }
  
  /// Prepare headers for API requests
  Future<Map<String, String>> _prepareHeaders(Map<String, String>? headers) async {
    final defaultHeaders = await getHeaders();
    
    if (headers != null) {
      defaultHeaders.addAll(headers);
    }
    
    return defaultHeaders;
  }
  
  /// Close the HTTP client
  void dispose() {
    _client.close();
  }

  String get baseUrl => _baseUrl;
}
