import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_model.dart';

/// Cache service for storing and retrieving document data locally
class DocumentCacheService {
  /// Prefix for document keys in SharedPreferences
  static const String _documentKeyPrefix = 'document_';
  
  /// Key for stored document IDs list
  static const String _documentIdsKey = 'cached_document_ids';
  
  /// Key for timestamp of last cache update
  static const String _lastCacheUpdateKey = 'last_document_cache_update';
  
  /// Maximum age of cache in hours before considered stale
  static const int _maxCacheAgeHours = 24;
  
  /// Singleton instance
  static final DocumentCacheService _instance = DocumentCacheService._internal();
  
  /// Factory constructor that returns the singleton instance
  factory DocumentCacheService() {
    return _instance;
  }
  
  /// Internal constructor
  DocumentCacheService._internal();
  
  /// Cache a document
  Future<bool> cacheDocument(AIGeneratedDocument document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert document to JSON string
      final String documentJson = jsonEncode(_documentToJson(document));
      
      // Store document
      await prefs.setString('$_documentKeyPrefix${document.id}', documentJson);
      
      // Update document IDs list
      final List<String> documentIds = await _getCachedDocumentIds();
      if (!documentIds.contains(document.id)) {
        documentIds.add(document.id);
        await prefs.setStringList(_documentIdsKey, documentIds);
      }
      
      // Update timestamp
      await prefs.setString(_lastCacheUpdateKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error caching document: $e');
      }
      return false;
    }
  }
  
  /// Cache a list of documents
  Future<bool> cacheDocuments(List<AIGeneratedDocument> documents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store each document
      for (final document in documents) {
        final String documentJson = jsonEncode(_documentToJson(document));
        await prefs.setString('$_documentKeyPrefix${document.id}', documentJson);
      }
      
      // Update document IDs list
      final List<String> documentIds = documents.map((doc) => doc.id).toList();
      await prefs.setStringList(_documentIdsKey, documentIds);
      
      // Update timestamp
      await prefs.setString(_lastCacheUpdateKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error caching documents: $e');
      }
      return false;
    }
  }
  
  /// Get a document from cache by ID
  Future<AIGeneratedDocument?> getDocument(String documentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? documentJson = prefs.getString('$_documentKeyPrefix$documentId');
      
      if (documentJson == null) {
        return null;
      }
      
      final Map<String, dynamic> documentMap = jsonDecode(documentJson);
      return AIGeneratedDocument.fromJson(documentMap);
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving cached document: $e');
      }
      return null;
    }
  }
  
  /// Get all cached documents
  Future<List<AIGeneratedDocument>> getAllDocuments() async {
    try {
      final List<String> documentIds = await _getCachedDocumentIds();
      final List<AIGeneratedDocument> documents = [];
      
      for (final documentId in documentIds) {
        final document = await getDocument(documentId);
        if (document != null) {
          documents.add(document);
        }
      }
      
      return documents;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving all cached documents: $e');
      }
      return [];
    }
  }
  
  /// Clear all document cache
  Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> documentIds = await _getCachedDocumentIds();
      
      // Remove each document
      for (final documentId in documentIds) {
        await prefs.remove('$_documentKeyPrefix$documentId');
      }
      
      // Clear document IDs list
      await prefs.remove(_documentIdsKey);
      
      // Clear timestamp
      await prefs.remove(_lastCacheUpdateKey);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing document cache: $e');
      }
      return false;
    }
  }
  
  /// Check if cache is stale
  Future<bool> isCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastUpdateStr = prefs.getString(_lastCacheUpdateKey);
      
      if (lastUpdateStr == null) {
        return true;
      }
      
      final DateTime lastUpdate = DateTime.parse(lastUpdateStr);
      final Duration age = DateTime.now().difference(lastUpdate);
      
      return age.inHours > _maxCacheAgeHours;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking cache age: $e');
      }
      return true;
    }
  }
  
  /// Get list of cached document IDs
  Future<List<String>> _getCachedDocumentIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_documentIdsKey) ?? [];
  }
  
  /// Convert AIGeneratedDocument to JSON-compatible Map
  Map<String, dynamic> _documentToJson(AIGeneratedDocument document) {
    // We need to convert DateTime to ISO string for JSON serialization
    return document.toJson();
  }
} 