import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/document_model.dart';
import '../services/document_service.dart';
import '../services/document_generation_tracker.dart';

class DocumentProvider extends ChangeNotifier {
  final DocumentService _documentService;
  
  AIGeneratedDocument? _currentDocument;
  List<AIGeneratedDocument> _documents = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedSectionId;
  String? _selectedPaperId;
  bool _showProcessView = false;
  String _activeTab = 'document'; // 'document', 'sources', 'process'
  bool _viewingSectionSources = false;
  
  // Generation tracking
  bool _isGenerating = false;
  String? _generationStatusMessage;
  DocumentGenerationTracker? _generationTracker;
  List<ProcessLog>? _generationLogs;
  int? _totalGenerationSteps;
  int? _currentGenerationStep;
  String? _generatingDocumentId;

  // Getters
  AIGeneratedDocument? get currentDocument => _currentDocument;
  List<AIGeneratedDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  String? get generationStatusMessage => _generationStatusMessage;
  String? get selectedSectionId => _selectedSectionId;
  String? get selectedPaperId => _selectedPaperId;
  bool get showProcessView => _showProcessView;
  String get activeTab => _activeTab;
  bool get viewingSectionSources => _viewingSectionSources;
  List<ProcessLog>? get generationLogs => _generationLogs;
  int? get totalGenerationSteps => _totalGenerationSteps;
  int? get currentGenerationStep => _currentGenerationStep;
  String? get generatingDocumentId => _generatingDocumentId;

  // Constructor - inject the document service
  DocumentProvider({DocumentService? documentService}) 
      : _documentService = documentService ?? DocumentService() {
    loadAllDocuments();
  }

  // Method to load all documents
  Future<void> loadAllDocuments() async {
    _setLoading(true);
    try {
      final allDocuments = await _documentService.getAllDocuments();
      _documents = allDocuments;
      _error = null;
    } catch (e) {
      _error = 'Failed to load documents: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Method to load a document
  Future<void> loadDocument(String documentId) async {
    _setLoading(true);
    try {
      final document = await _documentService.getDocument(documentId);
      _currentDocument = document;
      _error = null;
      
      // Auto-select the first section if available
      if (document.sections.isNotEmpty && _selectedSectionId == null) {
        _selectedSectionId = document.sections.first.id;
      }
    } catch (e) {
      _error = 'Failed to load document: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Set generation state
  void _setGenerating(bool generating, [String? statusMessage]) {
    _isGenerating = generating;
    _generationStatusMessage = statusMessage;
    notifyListeners();
  }

  // Set selected section
  void selectSection(String? sectionId) {
    _selectedSectionId = sectionId;
    // When selecting a section, we clear the paper selection
    _selectedPaperId = null;
    notifyListeners();
  }

  // Set selected paper
  void selectPaper(String? paperId) {
    _selectedPaperId = paperId;
    notifyListeners();
  }

  // Toggle process view
  void toggleProcessView() {
    _showProcessView = !_showProcessView;
    notifyListeners();
  }

  // Set active tab
  void setActiveTab(String tab) {
    _activeTab = tab;
    // Reset section sources view when changing tabs
    if (tab != 'sources') {
      _viewingSectionSources = false;
    }
    notifyListeners();
  }

  // Set viewing section sources
  void setViewingSectionSources(bool viewing) {
    _viewingSectionSources = viewing;
    notifyListeners();
  }

  // Get section by ID
  DocumentSection? getSectionById(String sectionId) {
    if (_currentDocument == null) return null;
    try {
      return _currentDocument!.sections.firstWhere((section) => section.id == sectionId);
    } catch (e) {
      return null;
    }
  }

  // Get references for a section
  List<DocumentReference> getReferencesForSection(String sectionId) {
    if (_currentDocument == null) return [];
    return _currentDocument!.references
        .where((ref) => ref.citedInSectionIds.contains(sectionId))
        .toList();
  }

  // Get paper summaries for a section
  List<PaperInstanse> getPaperSummariesForSection(String sectionId) {
    final section = getSectionById(sectionId);
    if (section == null) return [];
    return section.selectedPapers;
  }

  // Get citations for a section
  List<DocumentCitation> getCitationsForSection(String sectionId) {
    final section = getSectionById(sectionId);
    if (section == null) return [];
    return section.citations;
  }

  // Get all process logs
  List<ProcessLogEntry> getProcessLogs() {
    if (_currentDocument == null) return [];
    return _currentDocument!.processLogs;
  }

  // Get logs for a specific source
  List<ProcessLogEntry> getLogsForSource(String source) {
    if (_currentDocument == null) return [];
    return _currentDocument!.processLogs
        .where((log) => log.source == source)
        .toList();
  }

  // Get logs by level
  List<ProcessLogEntry> getLogsByLevel(String level) {
    if (_currentDocument == null) return [];
    return _currentDocument!.processLogs
        .where((log) => log.level == level)
        .toList();
  }

  // Refresh documents - call this to check for new documents
  Future<void> refreshDocuments() async {
    // Keep existing documents while loading, to avoid flickering
    final oldDocuments = _documents;
    
    try {
      final allDocuments = await _documentService.getAllDocuments();
      _documents = allDocuments;
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh documents: ${e.toString()}';
      debugPrint(_error);
      // Restore old documents on error
      _documents = oldDocuments;
    } finally {
      notifyListeners();
    }
  }

  // Generate a new document
  Future<void> generateDocument({
    required String subject,
    required String description,
    required int wordCount,
  }) async {
    _setLoading(true);
    _setGenerating(true, 'Starting document generation...');
    
    try {
      debugPrint('Generating document: $subject, $description, $wordCount words');
      
      final response = await _documentService.generateDocument(
        subject: subject,
        description: description,
        wordCount: wordCount,
      );
      
      // Store the document ID for tracking
      final String documentId = response['document_id'] ?? response['id'].toString();
      _generatingDocumentId = documentId;
      
      // Add a small delay before starting to track progress
      // This gives the backend time to create the initial document
      await Future.delayed(const Duration(seconds: 2));
      
      // Start tracking the generation progress
      _trackGenerationProgress(documentId);
      
      _error = null;
      _setLoading(false);
    } catch (e) {
      debugPrint('Error generating document: $e');
      _error = e.toString();
      _setGenerating(false);
      _setLoading(false);
      rethrow;
    }
  }
  
  // Track document generation progress
  void _trackGenerationProgress(String documentId) {
    // Stop existing tracker if any
    _generationTracker?.dispose();
    
    // Create a new tracker
    _generationTracker = DocumentGenerationTracker(
      documentId: documentId,
      onStatusUpdate: _handleGenerationStatusUpdate,
    );
    
    // Start tracking
    _generationTracker!.startTracking();
  }
  
  // Handle generation status updates
  void _handleGenerationStatusUpdate(GenerationStatusUpdate update) {
    _generationLogs = update.logs;
    _totalGenerationSteps = update.totalSteps;
    _currentGenerationStep = update.currentStep;
    
    _setGenerating(
      update.isInProgress, 
      update.message ?? 'Processing document...',
    );

    if (update.documentId != null) {
        loadDocument(update.documentId!);
      }
    
    if (update.isComplete) {
      // Refresh documents to include the new one
      refreshDocuments();
      
      // If document ID is provided, load it
      
    }
    
    if (update.isFailed) {
      _error = update.errorMessage ?? 'Document generation failed';
    }
  }
  
  // Cancel document generation tracking
  void cancelGenerationTracking() {
    _generationTracker?.stopTracking();
    _generationTracker?.dispose();
    _generationTracker = null;
    _generatingDocumentId = null;
    _generationLogs = null;
    _totalGenerationSteps = null;
    _currentGenerationStep = null;
    _setGenerating(false);
  }
  
  // Clear document cache
  Future<void> clearCache() async {
    await _documentService.clearCache();
    await loadAllDocuments();
  }
  
  // Get selected papers for a section
  List<DocumentCitation> getSelectedPapersForSection(String sectionId) {
    final section = getSectionById(sectionId);
    if (section == null) return [];
    return section.citations;
  }
  
  @override
  void dispose() {
    _generationTracker?.dispose();
    super.dispose();
  }
} 