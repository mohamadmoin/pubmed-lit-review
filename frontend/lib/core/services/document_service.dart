import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/document_model.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'document_cache_service.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'document_service_exception.dart';

export 'document_service_exception.dart';

/// Service for managing document operations
class DocumentService extends ChangeNotifier {
  /// API service for making requests
  final ApiService _apiService;
  
  /// Connectivity service for checking network status
  final ConnectivityService _connectivityService;
  
  /// Cache service for storing documents locally
  final DocumentCacheService _cacheService;
  
  /// Auth service for authentication
  final AuthService _authService;
  
  /// Whether the service is connected to the backend
  bool _isConnected = false;
  
  /// Singleton instance
  static final DocumentService _instance = DocumentService._internal();
  
  /// Base API URL from application configuration.
  String get _baseUrl => AppConfig.current.apiBaseUrl;
  
  /// Factory constructor that returns the singleton instance
  factory DocumentService({
    ApiService? apiService, 
    ConnectivityService? connectivityService,
    DocumentCacheService? cacheService,
    AuthService? authService,
  }) {
    return _instance;
  }
  
  /// Internal constructor
  DocumentService._internal({
    ApiService? apiService, 
    ConnectivityService? connectivityService,
    DocumentCacheService? cacheService,
    AuthService? authService,
  }) : _apiService = apiService ?? ApiService(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _cacheService = cacheService ?? DocumentCacheService(),
       _authService = authService ?? AuthService();

  /// Ensure a session exists (saved login or guest demo).
  Future<bool> _ensureAuthenticated() async {
    if (_authService.isAuthenticated) {
      return true;
    }
    if (await _authService.tryAutoLogin()) {
      return true;
    }
    if (AppConfig.autoGuestLogin) {
      return _authService.loginAsGuest();
    }
    return false;
  }

  Future<Map<String, String>> _requestHeaders() async {
    await _ensureAuthenticated();
    return _authService.getAuthHeaders();
  }

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  Future<bool> _recoverFromUnauthorized() async {
    await _authService.logout(revokeServerSession: false);
    return _ensureAuthenticated();
  }

  Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
    bool retryOn401 = true,
  }) async {
    final response =
        await http.get(url, headers: headers).timeout(_requestTimeout);
    if (retryOn401 && response.statusCode == 401) {
      if (await _recoverFromUnauthorized()) {
        return _get(
          url,
          headers: await _requestHeaders(),
          retryOn401: false,
        );
      }
    }
    return response;
  }

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool retryOn401 = true,
  }) async {
    final response = await http
        .post(url, headers: headers, body: body)
        .timeout(_requestTimeout);
    if (retryOn401 && response.statusCode == 401) {
      if (await _recoverFromUnauthorized()) {
        return _post(
          url,
          headers: await _requestHeaders(),
          body: body,
          retryOn401: false,
        );
      }
    }
    return response;
  }
  
  /// Test API connection
  Future<bool> connect() async {
    if (_isConnected) return true;

    try {
      // Health check without auth — backend demo mode accepts anonymous requests.
      final response = await http
          .get(
            Uri.parse('$_baseUrl/documents/status/'),
            headers: _jsonHeaders,
          )
          .timeout(_requestTimeout);

      // Any HTTP response means the API is reachable.
      _isConnected = response.statusCode != 401 || await _recoverFromUnauthorized();
      if (_isConnected) {
        notifyListeners();
      }
      return _isConnected;
    } catch (e) {
      debugPrint('API connection error: $e');
      _isConnected = false;
      return false;
    }
  }
  
  /// Get all documents from the API
  Future<List<AIGeneratedDocument>> getAllDocuments() async {
    // Try to connect to the backend
    final isOnline = await connect();
    
    // If online, try to get documents from API
    if (isOnline) {
      try {
        final response = await _get(
          Uri.parse('$_baseUrl/documents/'),
          headers: await _requestHeaders(),
        );
        
        if (response.statusCode != 200) {
          throw Exception('Failed to load documents, status code: ${response.statusCode}');
        }
        
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> jsonData = jsonResponse['results'];
        final documents = jsonData
            .map((json) => AIGeneratedDocument.fromJson(json))
            .toList();
        
        // Cache documents for offline use
        await _cacheService.cacheDocuments(documents);
        
        return documents;
      } catch (e) {
        debugPrint('Error fetching documents: $e');
        return [];
      }
    } else {
      // If offline, get documents from cache
      debugPrint('Using cached documents (offline mode)');
      return _getCachedDocuments();
    }
  }
  
  /// Get documents from cache
  Future<List<AIGeneratedDocument>> _getCachedDocuments() async {
    try {
      final cachedDocuments = await _cacheService.getAllDocuments();
      if (cachedDocuments.isNotEmpty) {
        return cachedDocuments;
      }
    } catch (e) {
      debugPrint('Error retrieving cached documents: $e');
    }
    
    return [];
  }
  
  /// Get a document by ID
  Future<AIGeneratedDocument> getDocument(String documentId) async {
    await connect();
    
    if (!_isConnected) {
      return _generateMockDocument();
    }
    
    try {
      final response = await _get(
        Uri.parse('$_baseUrl/documents/$documentId/content/'),
        headers: await _requestHeaders(),
      );
      
      if (response.statusCode == 401) {
        if (await _ensureAuthenticated()) {
          return getDocument(documentId);
        }
        throw DocumentServiceException(
          'Authentication required to access document',
        );
      }
      
      if (response.statusCode != 200) {
        final fallbackResponse = await _get(
          Uri.parse('$_baseUrl/documents/$documentId/'),
          headers: await _requestHeaders(),
        );
        
        if (fallbackResponse.statusCode != 200) {
          throw DocumentServiceException(
            'Failed to load document $documentId',
            originalException: Exception('Status code: ${fallbackResponse.statusCode}'),
          );
        }
        
        final Map<String, dynamic> jsonData = jsonDecode(utf8.decode(fallbackResponse.bodyBytes));
        return _processDocumentResponse(jsonData);
      }
      
      final Map<String, dynamic> jsonData = jsonDecode(utf8.decode(response.bodyBytes));
      return _processDocumentResponse(jsonData);
    } catch (e) {
      debugPrint('Error fetching document: $e');
      if (e is DocumentServiceException) {
        rethrow;
      }
      throw DocumentServiceException('Error fetching document', originalException: e as Exception?);
    }
  }
  
  /// Get document from cache
  Future<AIGeneratedDocument?> _getCachedDocument(String documentId) async {
    try {
      return await _cacheService.getDocument(documentId);
    } catch (e) {
      debugPrint('Error retrieving cached document: $e');
      return null;
    }
  }
  
  /// Request document generation
  Future<Map<String, dynamic>> generateDocument({
    required String subject,
    required String description,
    required int wordCount,
  }) async {
    // Try to connect to the backend
    final isOnline = await connect();
    if (!isOnline) {
      throw Exception('Cannot generate document: Backend is not available');
    }
    
    if (!await _ensureAuthenticated()) {
      throw Exception('Authentication required to generate document');
    }
    
    try {
      final response = await _post(
        Uri.parse('$_baseUrl/documents/generatedocument/'),
        headers: await _requestHeaders(),
        body: jsonEncode({
          'subject': subject,
          'description': description,
          'word_count': wordCount,
        }),
      );
      
      if (response.statusCode == 401) {
        if (await _ensureAuthenticated()) {
          return generateDocument(
            subject: subject,
            description: description,
            wordCount: wordCount,
          );
        }
        throw Exception('Authentication required to generate document');
      }
      
      if (response.statusCode != 201) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? 'Failed to generate document');
      }
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('Error generating document: $e');
      throw Exception('Failed to generate document: ${e.toString()}');
    }
  }
  
  /// Get status of document generation request
  Future<Map<String, dynamic>> getGenerationStatus(int requestId) async {
    // Try to connect to the backend
    final isOnline = await connect();
    if (!isOnline) {
      throw Exception('Cannot check generation status: Backend is not available');
    }
    
    try {
      final response = await _get(
        Uri.parse('$_baseUrl/documents/generate/$requestId/status/'),
        headers: await _requestHeaders(),
      );
      
      if (response.statusCode == 401) {
        if (await _ensureAuthenticated()) {
          return getGenerationStatus(requestId);
        }
        throw Exception('Authentication required to check generation status');
      }
      
      if (response.statusCode != 200) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? 'Failed to check generation status');
      }
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('Error checking generation status: $e');
      throw Exception('Failed to check generation status: ${e.toString()}');
    }
  }
  
  /// Get process logs for a document
  Future<Map<String, dynamic>> getDocumentProcessLogs(String documentId) async {
    // Try to connect to the backend
    final isOnline = await connect();
    if (!isOnline) {
      throw Exception('Cannot fetch process logs: Backend is not available');
    }
    
    try {
      final response = await _get(
        Uri.parse('$_baseUrl/documents/$documentId/process_logs/'),
        headers: await _requestHeaders(),
      );
      
      if (response.statusCode == 401) {
        if (await _ensureAuthenticated()) {
          return getDocumentProcessLogs(documentId);
        }
        throw Exception('Authentication required to access process logs');
      }
      
      if (response.statusCode != 200) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? 'Failed to fetch process logs');
      }
      
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      
      // Check if the response contains the expected data
      if (responseData == null || !responseData.containsKey('logs')) {
        throw Exception('Document not found or invalid response format');
      }
      
      // Return the response data directly since Django is sending the correct format
      return responseData;
    } catch (e) {
      debugPrint('Error fetching process logs: $e');
      throw Exception('Failed to fetch process logs: $e');
    }
  }
  
  /// Clear document cache
  Future<bool> clearCache() async {
    return await _cacheService.clearCache();
  }
  
  /// Create a mock document for when the API fails
  AIGeneratedDocument _generateMockDocument() {
    final sections = <DocumentSection>[
      // DocumentSection(
      //   id: 'sec1',
      //   title: 'Introduction',
      //   content: 'This is a mock document created when the API connection failed. '
      //           'Please check your backend connection and try again.',
      //   selectedPapers: [],
      //   citations: [],
      // ),
      // DocumentSection(
      //   id: 'sec2',
      //   title: 'Connection Issues',
      //   content: 'If you are seeing this document, it means the Flutter app '
      //           'could not connect to the Django backend. Please ensure the '
      //           'Django server is running and accessible.',
      //   selectedPapers: [],
      //   citations: [],
      // ),
      // DocumentSection(
      //   id: 'sec3',
      //   title: 'Troubleshooting',
      //   content: '1. Verify the Django server is running (python manage.py runserver)\n'
      //           '2. Check that Neo4j database is running\n'
      //           '3. Ensure Celery worker is active for document generation\n'
      //           '4. Check network connectivity between Flutter and Django',
      //   selectedPapers: [],
      //   citations: [],
      // ),
    ];

    final references = <DocumentReference>[
      DocumentReference(
        id: 'ref1',
        pmid: 'mock1',
        formattedReference: 'Django Documentation. Django REST Framework.',
        citedInSectionIds: ['sec1'],
      ),
      DocumentReference(
        id: 'ref2',
        pmid: 'mock2',
        formattedReference: 'Flutter Documentation. Connecting to Backend Services.',
        citedInSectionIds: ['sec2'],
      ),
    ];

    final logs = <ProcessLogEntry>[
      ProcessLogEntry(
        id: 'log1',
        timestamp: DateTime.now(),
        message: 'Failed to connect to Django backend',
        level: 'ERROR',
        source: 'Connection',
      ),
    ];

    return AIGeneratedDocument(
      id: 'mock-doc-1',
      title: 'Connection Issue - Mock Document',
      description: 'This document was generated because the backend connection failed.',
      createdAt: DateTime.now(),
      filePath: '/mock/document.md',
      subject: 'Backend Connection',
      wordCount: 500,
      sections: sections,
      references: references,
      processLogs: logs,
      isCompleted: true,
    );
  }

  AIGeneratedDocument _processDocumentResponse(Map<String, dynamic> jsonData) {
    try {
      // Process sections and ensure authors are properly parsed
      if (jsonData['sections'] != null) {
        for (var section in jsonData['sections']) {
          if (section['selected_papers'] != null) {
            for (var paper in section['selected_papers']) {
              // Handle authors field - now a simple string format
              if (paper['authors'] != null && paper['authors'] is String) {
                // Keep authors as a string for selected papers
                paper['authors'] = paper['authors'].toString();
              }
            }
          }
          
          if (section['cited_papers'] != null) {
            for (var citation in section['cited_papers']) {
              if (citation['authors'] != null && citation['authors'] is String) {
                // Keep authors as a string for citations
                citation['authors'] = citation['authors'].toString();
              }
            }
          }
        }
      }

      // Handle references parsing - new format with newlines
      if (jsonData['references'] != null && jsonData['references'] is String) {
        try {
          // Split the references string by double newlines
          final refStrings = jsonData['references'].toString().split('\n\n');

          // Build PMID -> section IDs map from cited papers in sections
          final pmidToSectionIds = <String, Set<String>>{};
          if (jsonData['sections'] != null) {
            for (final section in jsonData['sections']) {
              final sectionId = section['id']?.toString() ?? '';
              final citedPapers = section['cited_papers'] as List? ?? [];
              for (final citation in citedPapers) {
                if (citation is Map<String, dynamic>) {
                  final pmid = citation['pmid']?.toString() ?? '';
                  if (pmid.isNotEmpty && sectionId.isNotEmpty) {
                    pmidToSectionIds.putIfAbsent(pmid, () => {}).add(sectionId);
                  }
                }
              }
            }
          }
          
          final references = refStrings.where((ref) => ref.trim().isNotEmpty).map((ref) {
            // Extract PMID if available (you might need to adjust this based on your actual format)
            String pmid = '';
            final pmidMatch = RegExp(r'PMID:\s*(\d+)').firstMatch(ref);
            if (pmidMatch != null) {
              pmid = pmidMatch.group(1) ?? '';
            }
            
            return {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'pmid': pmid,
              'formatted_reference': ref.trim(),
              'cited_in_section_ids': pmidToSectionIds[pmid]?.toList() ?? [],
            };
          }).toList();
          
          jsonData['references'] = references;
        } catch (e) {
          debugPrint('Error parsing references: $e');
          jsonData['references'] = [];
        }
      } else {
        jsonData['references'] = [];
      }
      
      return AIGeneratedDocument.fromJson(jsonData);
    } catch (e) {
      debugPrint('Error processing document response: $e');
      throw DocumentServiceException(
        'Error processing document data: ${e.toString()}',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Download the generated Word document for a document ID.
  Future<List<int>> downloadDocument(String documentId) async {
    final isOnline = await connect();
    if (!isOnline) {
      throw const DocumentServiceException('Cannot download document: Backend is not available');
    }

    final response = await _get(
      Uri.parse('$_baseUrl/documents/$documentId/download/'),
      headers: await _requestHeaders(),
    );

    if (response.statusCode == 401) {
      if (await _ensureAuthenticated()) {
        return downloadDocument(documentId);
      }
      throw const DocumentServiceException('Authentication required to download document');
    }

    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw DocumentServiceException(
          errorData['error']?.toString() ?? 'Failed to download document',
        );
      } on DocumentServiceException {
        rethrow;
      } catch (_) {
        throw DocumentServiceException(
          'Failed to download document (${response.statusCode})',
        );
      }
    }

    final bytes = response.bodyBytes;
    if (!_looksLikeDocx(bytes)) {
      try {
        final errorData = jsonDecode(utf8.decode(bytes));
        throw DocumentServiceException(
          errorData['error']?.toString() ?? 'Server returned an invalid document file',
        );
      } on DocumentServiceException {
        rethrow;
      } catch (_) {
        throw const DocumentServiceException(
          'Download returned an invalid file (expected Word .docx)',
        );
      }
    }

    return bytes;
  }

  bool _looksLikeDocx(List<int> bytes) {
    // .docx files are ZIP archives starting with PK\x03\x04
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
        (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
  }

  /// Fetch full text for a paper within a document (lazy load for reader UI).
  Future<String> getPaperFullText(String documentId, String pmid) async {
    final isOnline = await connect();
    if (!isOnline) {
      throw const DocumentServiceException('Cannot fetch full text: Backend is not available');
    }

    final response = await _get(
      Uri.parse('$_baseUrl/documents/$documentId/papers/$pmid/full_text/'),
      headers: await _requestHeaders(),
    );

    if (response.statusCode == 404) {
      throw const DocumentServiceException('Full text not available for this paper');
    }
    if (response.statusCode != 200) {
      throw DocumentServiceException('Failed to fetch full text (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['full_text']?.toString() ?? '';
  }

} 